"""
Blender startup script for BlenderMCP.

This script is passed to Blender via --python on launch.
It installs the addon (if not already present), enables it,
and automatically starts the MCP socket server so that AI
tools can connect immediately without any manual steps.
"""

import bpy
import os
import shutil
import sys


ADDON_MODULE = "addon"
ADDON_FILENAME = "addon.py"


def _find_addon_source() -> str:
    """Return the absolute path to addon.py next to this script."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    candidate = os.path.join(script_dir, ADDON_FILENAME)
    if os.path.isfile(candidate):
        return candidate
    raise FileNotFoundError(
        f"Could not find {ADDON_FILENAME}. "
        f"Make sure it lives in the same directory as this script: {script_dir}"
    )


def _user_addons_dir() -> str:
    """Return Blender's user scripts/addons directory, creating it if needed."""
    scripts_dir = bpy.utils.user_resource("SCRIPTS")
    addons_dir = os.path.join(scripts_dir, "addons")
    os.makedirs(addons_dir, exist_ok=True)
    return addons_dir


def install_and_enable_addon():
    """Copy addon.py into Blender's addons folder and enable it."""
    source = _find_addon_source()
    dest_dir = _user_addons_dir()
    dest = os.path.join(dest_dir, ADDON_FILENAME)

    shutil.copy2(source, dest)
    print(f"[BlenderMCP] Installed addon: {dest}")

    # Refresh addon list so Blender sees the freshly copied file.
    bpy.ops.preferences.addon_refresh()

    # Enable the addon.
    bpy.ops.preferences.addon_enable(module=ADDON_MODULE)
    print("[BlenderMCP] Addon enabled.")

    # Persist the preference so the addon stays enabled on future launches.
    bpy.ops.wm.save_userpref()


def start_mcp_server():
    """Start the BlenderMCP socket server (equivalent to clicking the panel button)."""
    # The operator is registered by the addon on enable.
    if hasattr(bpy.ops, "blendermcp") and hasattr(bpy.ops.blendermcp, "start_server"):
        bpy.ops.blendermcp.start_server()
        print("[BlenderMCP] MCP server started.")
    else:
        # Fallback: call the server directly through the addon module.
        try:
            import addon as blender_mcp_addon  # noqa: PLC0415
            if hasattr(blender_mcp_addon, "server") and blender_mcp_addon.server is not None:
                blender_mcp_addon.server.start()
                print("[BlenderMCP] MCP server started (direct call).")
            else:
                print(
                    "[BlenderMCP] Warning: could not auto-start the server. "
                    "Please click 'Connect to MCP AI' in the BlenderMCP panel (N > BlenderMCP)."
                )
        except Exception as exc:  # noqa: BLE001
            print(f"[BlenderMCP] Warning: could not auto-start the server: {exc}")


def main():
    print("[BlenderMCP] Running startup script …")
    try:
        install_and_enable_addon()
        start_mcp_server()
        print("[BlenderMCP] Ready. Connect your AI tool to localhost:9876.")
    except Exception as exc:  # noqa: BLE001
        print(f"[BlenderMCP] Startup error: {exc}")
        import traceback
        traceback.print_exc()


main()
