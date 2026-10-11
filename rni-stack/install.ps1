# rni-stack installer for Windows (PowerShell)
#
# Usage:
#   $env:RNI_LICENSE_KEY = '<key>'; irm https://www.alant.health/rni-stack/install.ps1 | iex
#
# Your Alant license key is the only credential you need: the installer reads
# the package-index token from the license, installs rni-stack, and writes the
# key to ~\.alant.license so every Alant application on this machine is
# licensed.  Stdin is occupied by the script itself when piped via iex, so
# interactive prompts are not possible.
$ErrorActionPreference = 'Stop'

$FuryHost = 'rni.fury.site'
$FindLinks = 'https://github.com/SimpleITK/SimpleITK/releases/tag/latest'
# Alant Health's license account (a public identifier, not a secret).
$KeygenAccount = '319ec55f-0bda-4593-8ddc-3b1ad2b0068d'
$LicenseFile = Join-Path $env:USERPROFILE '.alant.license'

# --------------------------------------------------------------------------- #
# Credentials: the license key yields the package-index token
# --------------------------------------------------------------------------- #

$LicenseKey = $env:RNI_LICENSE_KEY
if (-not $LicenseKey) {
    Write-Error ('error: RNI_LICENSE_KEY is not set.' + "`n" +
        "usage: `$env:RNI_LICENSE_KEY = '<key>'; irm https://www.alant.health/rni-stack/install.ps1 | iex")
    exit 1
}

Write-Host '==> Reading the package-index token from your license...'
try {
    $resp = Invoke-RestMethod -Method Get `
        -Uri "https://api.keygen.sh/v1/accounts/$KeygenAccount/licenses/$LicenseKey" `
        -Headers @{
            Accept        = 'application/vnd.api+json'
            Authorization = "License $LicenseKey"
        }
} catch {
    Write-Error 'error: the license server rejected this key.'
    exit 1
}
# The rni index token, else the family one.
$meta = $resp.data.attributes.metadata
$DeployToken = if ($meta.rniDeployToken) { $meta.rniDeployToken } else { $meta.deployToken }
if (-not $DeployToken) {
    Write-Error 'error: this license carries no package-index token (rniDeployToken). Contact your administrator.'
    exit 1
}

$FuryIndex = "https://$DeployToken@$FuryHost/pypi/"

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

Write-Host '==> Installing / upgrading rni-stack...'
uv tool install --upgrade rni-stack `
    --exclude-newer P3D `
    --exclude-newer-package rni-stack=false `
    --exclude-newer-package itxpy=false `
    --exclude-newer-package alant-auth=false `
    --index $FuryIndex `
    --prerelease=allow `
    "--find-links=$FindLinks"

# --------------------------------------------------------------------------- #
# License
# --------------------------------------------------------------------------- #

Write-Host "==> Saving your license key to $LicenseFile..."
[IO.File]::WriteAllText($LicenseFile, "KEY=$LicenseKey`n")

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

Write-Host ''
Write-Host 'rni-stack installed. Next steps:'
Write-Host ''
Write-Host '  1. Check your license:'
Write-Host '       rni license verify'
Write-Host ''
Write-Host '  2. Add shell completion to your PowerShell profile:'
Write-Host '       rni generate-shell-completion powershell | Out-String | Invoke-Expression'
Write-Host ''
