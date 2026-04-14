# ============================================================
# BlenderMCP — One-Click Deployment Script (PowerShell)
# ============================================================
# Run via deploy.bat or directly:
#   powershell -ExecutionPolicy Bypass -File deploy.ps1
# ============================================================

param(
    [string]$BlenderPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────

# ConvertFrom-Json -AsHashtable was added in PowerShell 6.0.
# This wrapper provides the same behaviour on PowerShell 5.1+.
function ConvertTo-Hashtable($obj) {
    if ($obj -is [System.Collections.Hashtable]) { return $obj }
    $ht = [ordered]@{}
    if ($obj -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $obj.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
        }
    } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    } else {
        return $obj
    }
    return $ht
}

function ConvertFrom-JsonToHashtable($json) {
    ConvertTo-Hashtable (ConvertFrom-Json $json)
}

function Write-Header($msg) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Step($msg)    { Write-Host "[*] $msg" -ForegroundColor Yellow }
function Write-Ok($msg)      { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "[!] $msg" -ForegroundColor Magenta }
function Write-Err($msg)     { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# ── Script root (repo directory) ─────────────────────────────
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Header "BlenderMCP — One-Click Deployment"

# ── 1. Check Python ──────────────────────────────────────────
Write-Step "Checking for Python 3.10+..."
$pythonCmd = $null
foreach ($cmd in @("python", "python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]; $minor = [int]$Matches[2]
            if ($major -ge 3 -and $minor -ge 10) {
                $pythonCmd = $cmd
                Write-Ok "Found $ver  ($cmd)"
                break
            }
        }
    } catch { }
}

if (-not $pythonCmd) {
    Write-Err "Python 3.10 or newer is required but was not found on PATH."
    Write-Host "    Download it from: https://www.python.org/downloads/"
    Read-Host "Press Enter to exit"
    exit 1
}

# ── 2. Check / Install uv ────────────────────────────────────
Write-Step "Checking for uv..."
$uvFound = $false
try {
    $uvVer = & uv --version 2>&1
    if ($LASTEXITCODE -eq 0) { $uvFound = $true; Write-Ok "Found $uvVer" }
} catch { }

if (-not $uvFound) {
    Write-Step "uv not found — installing via official installer..."
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    } catch {
        Write-Err "Failed to install uv: $_"
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Add uv's default install location to the current session's PATH
    $localBin = "$env:USERPROFILE\.local\bin"
    if (Test-Path $localBin) {
        $env:PATH = "$localBin;$env:PATH"
    }

    try {
        $uvVer = & uv --version 2>&1
        if ($LASTEXITCODE -ne 0) { throw "uv still not available after install" }
        Write-Ok "uv installed: $uvVer"
    } catch {
        Write-Err "uv was installed but cannot be found on PATH."
        Write-Warn "Please restart this script (or open a new terminal) and try again."
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ── 3. Configure AI clients ───────────────────────────────────
function Merge-McpConfig($configPath, $serverJson) {
    $dir = Split-Path $configPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $config = @{}
    if (Test-Path $configPath) {
        try { $config = ConvertFrom-JsonToHashtable (Get-Content $configPath -Raw) }
        catch { Write-Warn "Could not parse existing config at $configPath — will overwrite." }
    }

    if (-not $config.ContainsKey("mcpServers")) { $config["mcpServers"] = @{} }
    $config["mcpServers"]["blender"] = $serverJson

    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
}

$winServerEntry = [ordered]@{
    command = "cmd"
    args    = @("/c", "uvx", "blender-mcp")
}

# Claude Desktop
$claudeConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path (Split-Path $claudeConfig)) {
    Write-Step "Configuring Claude Desktop..."
    try {
        Merge-McpConfig $claudeConfig $winServerEntry
        Write-Ok "Claude Desktop configured: $claudeConfig"
    } catch { Write-Warn "Could not update Claude Desktop config: $_" }
} else {
    Write-Warn "Claude Desktop not detected (skipping)."
}

# VS Code / GitHub Copilot  (.vscode/mcp.json in the repo)
$vscodeMcpPath = Join-Path $RepoDir ".vscode\mcp.json"
Write-Step "Checking .vscode/mcp.json..."
$vscodeMcp = @{}
if (Test-Path $vscodeMcpPath) {
    try { $vscodeMcp = ConvertFrom-JsonToHashtable (Get-Content $vscodeMcpPath -Raw) }
    catch { }
}
if (-not $vscodeMcp.ContainsKey("servers")) { $vscodeMcp["servers"] = @{} }
$vscodeMcp["servers"]["blender-mcp"] = [ordered]@{
    type    = "stdio"
    command = "cmd"
    args    = @("/c", "uvx", "blender-mcp")
}
$vscodeMcp | ConvertTo-Json -Depth 10 | Set-Content $vscodeMcpPath -Encoding UTF8
Write-Ok "VS Code / GitHub Copilot configured: $vscodeMcpPath"

# Cursor  (%APPDATA%\Cursor\User\globalStorage\cursor.mcp\settings.json)
$cursorConfig = "$env:APPDATA\Cursor\User\globalStorage\cursor.mcp\settings.json"
if (Test-Path (Split-Path $cursorConfig)) {
    Write-Step "Configuring Cursor..."
    try {
        Merge-McpConfig $cursorConfig $winServerEntry
        Write-Ok "Cursor configured: $cursorConfig"
    } catch { Write-Warn "Could not update Cursor config: $_" }
} else {
    Write-Warn "Cursor not detected (skipping)."
}

# ── 4. Launch Blender ─────────────────────────────────────────
Write-Header "Launching Blender with BlenderMCP addon"

$launcherScript = Join-Path $RepoDir "launch_blender.py"
if (-not (Test-Path $launcherScript)) {
    Write-Err "launch_blender.py not found in $RepoDir"
    Read-Host "Press Enter to exit"
    exit 1
}

$launchArgs = @($launcherScript)
if ($BlenderPath -ne "") {
    Write-Step "Using user-supplied Blender path: $BlenderPath"
    $launchArgs += "--blender-path"
    $launchArgs += $BlenderPath
} else {
    Write-Step "Auto-detecting Blender installation..."
}

Write-Step "Running: $pythonCmd $launchArgs"
Write-Host ""

try {
    & $pythonCmd @launchArgs
    $exitCode = $LASTEXITCODE
} catch {
    Write-Err "Failed to launch Blender: $_"
    Read-Host "Press Enter to exit"
    exit 1
}

if ($exitCode -ne 0) {
    Write-Host ""
    Write-Warn "Blender exited with code $exitCode."
    Write-Warn "If Blender was not found, re-run with the path flag:"
    Write-Host "  deploy.bat --blender-path `"C:\Path\To\blender.exe`"" -ForegroundColor Gray
}

Write-Host ""
Write-Ok "Done."
