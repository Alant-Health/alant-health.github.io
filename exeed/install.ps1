# exeed installer for Windows (PowerShell)
#
# Usage:
#   irm https://www.alant.health/exeed/install.ps1 | iex
#
# ALANT_DEPLOY_TOKEN must be set before running — set it once as a persistent
# user environment variable (see installation docs). Stdin is occupied by the
# script itself when piped via iex, so interactive prompts are not possible.
$ErrorActionPreference = 'Stop'

$AlantIndex = "https://$($env:ALANT_DEPLOY_TOKEN)@www.alant.software/pypi/"

# --------------------------------------------------------------------------- #
# Guards
# --------------------------------------------------------------------------- #

if (-not $env:ALANT_DEPLOY_TOKEN) {
    Write-Error ('error: ALANT_DEPLOY_TOKEN is not set.' + "`n" +
        'usage: irm https://www.alant.health/exeed/install.ps1 | iex')
    exit 1
}

# --------------------------------------------------------------------------- #
# uv
# --------------------------------------------------------------------------- #

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host '==> Installing uv...'
    irm https://astral.sh/uv/install.ps1 | iex
    # Refresh PATH so uv is available without reopening the shell
    $uvBin = if ($env:UV_INSTALL_DIR) {
        $env:UV_INSTALL_DIR
    } elseif (Test-Path "$env:LOCALAPPDATA\uv\bin") {
        "$env:LOCALAPPDATA\uv\bin"
    } else {
        "$env:USERPROFILE\.local\bin"
    }
    $env:PATH = "$uvBin;$env:PATH"
}

# --------------------------------------------------------------------------- #
# Python 3.13
# --------------------------------------------------------------------------- #

$uvPythonFind = uv python find 3.13 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host '==> Installing Python 3.13...'
    uv python install 3.13
}

# --------------------------------------------------------------------------- #
# exeed
# --------------------------------------------------------------------------- #

if (Get-Command iexeed -ErrorAction SilentlyContinue) {
    Write-Host '==> Upgrading exeed...'
    uv tool upgrade exeed `
        --index $AlantIndex
} else {
    Write-Host '==> Installing exeed...'
    uv tool install exeed `
        --index $AlantIndex
}

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

Write-Host ''
Write-Host 'exeed installed. Run the application:'
Write-Host ''
Write-Host '  exeed       # launch GUI'
Write-Host '  iexeed      # launch CLI'
Write-Host ''
