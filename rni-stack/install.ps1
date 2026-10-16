# rni-stack installer for Windows (PowerShell)
#
# Usage:
#   $env:RNI_LICENSE_KEY = '<key>'; irm https://www.alant.health/rni-stack/install.ps1 | iex
#
# Your Alant license key is the only credential you need: the installer reads
# the package-index token from the license, installs rni-stack, and writes the
# key to ~\.alant.license so every Alant application on this machine is
# licensed.  On a machine that already holds the key (in ~\.alant.license, or
# ~\.rni-stack.license from RNI Stack 1.7), RNI_LICENSE_KEY may be left out.
# Stdin is occupied by the script itself when piped via iex, so interactive
# prompts are not possible.
$ErrorActionPreference = 'Stop'

$FuryHost = 'rni.fury.site'
$FindLinks = 'https://github.com/SimpleITK/SimpleITK/releases/tag/latest'
# Alant Health's license account (a public identifier, not a secret).
$KeygenAccount = '319ec55f-0bda-4593-8ddc-3b1ad2b0068d'
$LicenseFile = Join-Path $env:USERPROFILE '.alant.license'
# Where RNI Stack 1.7 and earlier saved the same key.
$LegacyLicenseFile = Join-Path $env:USERPROFILE '.rni-stack.license'

# --------------------------------------------------------------------------- #
# Guards
# --------------------------------------------------------------------------- #

# A developer's editable install is updated with git; installing the release
# over it would silently replace the tool built from their working copy.  The
# tool receipt names the editable source path when there is one.
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $toolDir = uv tool dir 2>$null | Select-Object -First 1
    $receipt = if ($toolDir) { Join-Path $toolDir 'rni-stack\uv-receipt.toml' }
    if ($receipt -and (Test-Path -LiteralPath $receipt -PathType Leaf)) {
        foreach ($line in Get-Content -LiteralPath $receipt) {
            if ($line -match 'name = "rni-stack"[^}]*editable = ["'']([^"'']+)["'']') {
                # A basic TOML string doubles each backslash of a Windows path.
                $editable = $Matches[1] -replace '\\\\', '\'
                Write-Error ("error: rni-stack is an editable install from $editable.`n" +
                    'Update it with `git pull` there; this installer would replace it with the ' +
                    'released package. To switch to the release on purpose, run ' +
                    '`uv tool uninstall rni-stack` first.')
                exit 1
            }
        }
    }
}

# --------------------------------------------------------------------------- #
# Credentials: the license key yields the package-index token
# --------------------------------------------------------------------------- #

# The value of a license file's KEY= line, or $null when there is none.
function Get-SavedLicenseKey([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^KEY=(.+)$') { return ($Matches[1] -replace '["''\s]', '') }
    }
    return $null
}

$LicenseKey = $env:RNI_LICENSE_KEY
# A licensed machine needs no key to upgrade: take the one it saved, or the
# one an earlier RNI Stack saved in its own file.
if (-not $LicenseKey) {
    foreach ($saved in @($LicenseFile, $LegacyLicenseFile)) {
        $LicenseKey = Get-SavedLicenseKey $saved
        if ($LicenseKey) {
            Write-Host "==> Using the license key saved in $saved."
            break
        }
    }
}
if (-not $LicenseKey) {
    Write-Error ('error: RNI_LICENSE_KEY is not set and no saved license key was found.' + "`n" +
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
    # A response means the server answered and refused; none means it was
    # never reached.
    if ($_.Exception.Response) {
        Write-Error ('error: the license server rejected this key.' + "`n" +
            'The installer needs your Alant license key (the KEY= value in ~\.alant.license, ' +
            'or ~\.rni-stack.license from RNI Stack 1.7), not the package-index token.')
    } else {
        Write-Error "error: could not reach the license server: $($_.Exception.Message)"
    }
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
} else {
    # An existing uv keeps every fix it predates, so refresh it before it
    # installs anything. Best-effort: a uv installed by a package manager
    # cannot update itself, and the install continues with it.
    Write-Host '==> Updating uv...'
    $uvUpdated = $false
    try {
        uv self update
        $uvUpdated = ($LASTEXITCODE -eq 0)
    } catch {
        $uvUpdated = $false
    }
    if (-not $uvUpdated) {
        Write-Warning ('could not update uv; continuing with the installed version. ' +
            'If a package manager installed uv, update it there.')
    }
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
# uv before 0.12 refuses SimpleITK's 3.0 beta, which itxpy asks for, under its
# default pre-release policy and quietly resolves an old rni-stack on
# SimpleITK 2.x instead.  Only such a uv gets --prerelease=allow, which also
# admits every other package's dev builds (httpx 1.0.dev6) and is saved with
# the tool.  A version that cannot be read counts as old: allow always resolves.
$PrereleaseArgs = @()
$uvVersionLine = uv --version 2>$null | Select-Object -First 1
if (-not ("$uvVersionLine" -match '^uv (\d+)\.(\d+)') -or
    ([int]$Matches[1] -eq 0 -and [int]$Matches[2] -lt 12)) {
    $PrereleaseArgs = @('--prerelease=allow')
}
uv tool install --upgrade rni-stack `
    --exclude-newer P3D `
    --exclude-newer-package rni-stack=false `
    --exclude-newer-package itxpy=false `
    --exclude-newer-package alant-auth=false `
    --index $FuryIndex `
    @PrereleaseArgs `
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
