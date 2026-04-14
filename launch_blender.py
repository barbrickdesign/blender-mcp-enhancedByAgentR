#!/usr/bin/env python3
"""
BlenderMCP Launcher
===================
Launches Blender 5.0 with the BlenderMCP addon already installed and the
MCP socket server started, so your AI tool (Claude Desktop, GitHub Copilot,
Cursor, etc.) can connect right away.

Usage
-----
    python launch_blender.py [--blender-path /path/to/blender]

If --blender-path is not provided the script tries common installation
locations for Windows, macOS, and Linux.
"""

import argparse
import os
import platform
import subprocess
import sys


# ---------------------------------------------------------------------------
# Default search paths for each platform
# ---------------------------------------------------------------------------

_DEFAULT_PATHS = {
    "Windows": [
        r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
        r"C:\Program Files (x86)\Blender Foundation\Blender 5.0\blender.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Blender Foundation\Blender 5.0\blender.exe"),
    ],
    "Darwin": [
        "/Applications/Blender.app/Contents/MacOS/Blender",
        os.path.expanduser("~/Applications/Blender.app/Contents/MacOS/Blender"),
    ],
    "Linux": [
        "/usr/bin/blender",
        "/usr/local/bin/blender",
        os.path.expanduser("~/blender-5.0-linux-x64/blender"),
        os.path.expanduser("~/blender/blender"),
        "/snap/bin/blender",
    ],
}


def find_blender() -> str:
    """Return the path to the Blender executable, or raise if not found."""
    system = platform.system()
    candidates = _DEFAULT_PATHS.get(system, [])

    for path in candidates:
        if path and os.path.isfile(path):
            return path

    # Last resort: look on PATH
    import shutil as _shutil
    blender_on_path = _shutil.which("blender")
    if blender_on_path:
        return blender_on_path

    raise FileNotFoundError(
        "Blender executable not found in the default locations.\n"
        "Please provide its path with:  python launch_blender.py --blender-path /path/to/blender"
    )


def launch(blender_exe: str, extra_args: list[str]) -> None:
    """Launch Blender with the BlenderMCP startup script."""
    repo_dir = os.path.dirname(os.path.abspath(__file__))
    startup_script = os.path.join(repo_dir, "blender_startup.py")

    if not os.path.isfile(startup_script):
        print(f"[BlenderMCP] ERROR: startup script not found at {startup_script}")
        sys.exit(1)

    cmd = [blender_exe, "--python", startup_script] + extra_args

    print("[BlenderMCP] Launching Blender …")
    print(f"[BlenderMCP]   Executable : {blender_exe}")
    print(f"[BlenderMCP]   Startup    : {startup_script}")
    print("[BlenderMCP]   The MCP socket server will start on localhost:9876")
    print()

    # Replace the current process so Blender inherits the terminal.
    if platform.system() == "Windows":
        subprocess.run(cmd, check=False)
    else:
        os.execv(blender_exe, cmd)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Launch Blender 5.0 with the BlenderMCP addon pre-loaded."
    )
    parser.add_argument(
        "--blender-path",
        metavar="PATH",
        help="Path to the Blender executable (auto-detected if omitted).",
    )
    # Collect any remaining arguments and pass them straight to Blender.
    args, extra = parser.parse_known_args()

    blender_exe = args.blender_path
    if blender_exe:
        if not os.path.isfile(blender_exe):
            print(f"[BlenderMCP] ERROR: Blender executable not found at: {blender_exe}")
            sys.exit(1)
    else:
        try:
            blender_exe = find_blender()
            print(f"[BlenderMCP] Auto-detected Blender at: {blender_exe}")
        except FileNotFoundError as exc:
            print(f"[BlenderMCP] {exc}")
            sys.exit(1)

    launch(blender_exe, extra)


if __name__ == "__main__":
    main()
