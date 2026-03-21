# rni-stack installer for Windows (PowerShell)
#
# Usage:
#   irm https://www.alant.health/rni-stack/install.ps1 | iex
#
# RNI_DEPLOY_TOKEN must be set before running — set it once as a persistent
# user environment variable (see installation docs). Stdin is occupied by the
# script itself when piped via iex, so interactive prompts are not possible.
$ErrorActionPreference = 'Stop'

$FuryIndex = "https://$($env:RNI_DEPLOY_TOKEN)@rni.fury.site/pypi/"
$FindLinks = 'https://github.com/SimpleITK/SimpleITK/releases/tag/latest'

# --------------------------------------------------------------------------- #
# Guards
# --------------------------------------------------------------------------- #

if (-not $env:RNI_DEPLOY_TOKEN) {
    Write-Error ('error: RNI_DEPLOY_TOKEN is not set.' + "`n" +
        'usage: irm https://www.alant.health/rni-stack/install.ps1 | iex')
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
# Python 3.14
# --------------------------------------------------------------------------- #

$uvPythonFind = uv python find 3.14 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host '==> Installing Python 3.14...'
    uv python install 3.14
}

# --------------------------------------------------------------------------- #
# rni-stack
# --------------------------------------------------------------------------- #

if (Get-Command rni -ErrorAction SilentlyContinue) {
    Write-Host '==> Upgrading rni-stack...'
    uv tool upgrade rni-stack `
        --index $FuryIndex `
        --prerelease=allow `
        "--find-links=$FindLinks"
} else {
    Write-Host '==> Installing rni-stack...'
    uv tool install rni-stack `
        --index $FuryIndex `
        --prerelease=allow `
        "--find-links=$FindLinks"
}

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

Write-Host ''
Write-Host 'rni-stack installed. Next steps:'
Write-Host ''
Write-Host '  1. Activate your license:'
Write-Host '       rni license setup'
Write-Host ''
Write-Host '  2. Add shell completion to your PowerShell profile:'
Write-Host '       rni generate-shell-completion powershell | Out-String | Invoke-Expression'
Write-Host ''
