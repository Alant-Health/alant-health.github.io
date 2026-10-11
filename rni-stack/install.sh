#!/usr/bin/env bash
# rni-stack installer
#
# Usage:
#   curl -sSL https://www.alant.health/rni-stack/install.sh | RNI_LICENSE_KEY=<key> bash
#
# Your Alant license key is the only credential you need: the installer reads
# the package-index token from the license, installs rni-stack, and writes the
# key to ~/.alant.license so every Alant application on this machine is
# licensed.  Stdin is occupied by the script itself when piped, so interactive
# prompts are not possible.
set -euo pipefail

FURY_HOST="rni.fury.site"
FIND_LINKS="https://github.com/SimpleITK/SimpleITK/releases/tag/latest"
# Alant Health's license account (a public identifier, not a secret).
KEYGEN_ACCOUNT="319ec55f-0bda-4593-8ddc-3b1ad2b0068d"
LICENSE_FILE="$HOME/.alant.license"

# --------------------------------------------------------------------------- #
# Guards
# --------------------------------------------------------------------------- #

OS="$(uname -s 2>/dev/null || echo unknown)"
case "$OS" in
    Linux | Darwin) ;;
    *)
        echo "error: unsupported OS '$OS' — install manually." >&2
        exit 1
        ;;
esac

# --------------------------------------------------------------------------- #
# Credentials: the license key yields the package-index token
# --------------------------------------------------------------------------- #

LICENSE_KEY="${RNI_LICENSE_KEY:-}"
if [ -z "$LICENSE_KEY" ]; then
    echo "error: RNI_LICENSE_KEY is not set." >&2
    echo "usage: curl -sSL https://www.alant.health/rni-stack/install.sh | RNI_LICENSE_KEY=<key> bash" >&2
    exit 1
fi

echo "==> Reading the package-index token from your license..."
if ! response="$(curl -sS --fail \
    -H "Accept: application/vnd.api+json" \
    -H "Authorization: License ${LICENSE_KEY}" \
    "https://api.keygen.sh/v1/accounts/${KEYGEN_ACCOUNT}/licenses/${LICENSE_KEY}")"; then
    echo "error: the license server rejected this key." >&2
    exit 1
fi
# The metadata is compact JSON: the rni index token, else the family one.
DEPLOY_TOKEN="$(printf '%s' "$response" | sed -nE 's/.*"rniDeployToken":"([^"]+)".*/\1/p')"
if [ -z "$DEPLOY_TOKEN" ]; then
    DEPLOY_TOKEN="$(printf '%s' "$response" | sed -nE 's/.*"deployToken":"([^"]+)".*/\1/p')"
fi
if [ -z "$DEPLOY_TOKEN" ]; then
    echo "error: this license carries no package-index token (rniDeployToken). Contact your administrator." >&2
    exit 1
fi

FURY_INDEX="https://${DEPLOY_TOKEN}@${FURY_HOST}/pypi/"

# --------------------------------------------------------------------------- #
# uv
# --------------------------------------------------------------------------- #

if ! command -v uv >/dev/null 2>&1; then
    echo "==> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for the remainder of this script
    export PATH="${UV_INSTALL_DIR:-$HOME/.local/bin}:$PATH"
fi

# --------------------------------------------------------------------------- #
# Python 3.14
# --------------------------------------------------------------------------- #

if ! uv python find 3.14 >/dev/null 2>&1; then
    echo "==> Installing Python 3.14..."
    uv python install 3.14
fi

# --------------------------------------------------------------------------- #
# rni-stack
# --------------------------------------------------------------------------- #

echo "==> Installing / upgrading rni-stack..."
# A 3-day "soak" guards against a just-published *public* dependency that turns
# out broken — but the private packages (rni-stack, itxpy, alant-auth) are ours
# and don't need it, so they are exempted (`PACKAGE=false`) to install/upgrade
# to the latest immediately.
uv tool install --upgrade rni-stack \
    --exclude-newer P3D \
    --exclude-newer-package rni-stack=false \
    --exclude-newer-package itxpy=false \
    --exclude-newer-package alant-auth=false \
    --index "$FURY_INDEX" \
    --prerelease=allow \
    --find-links "$FIND_LINKS"

# --------------------------------------------------------------------------- #
# License
# --------------------------------------------------------------------------- #

echo "==> Saving your license key to ${LICENSE_FILE}..."
(umask 077 && printf 'KEY=%s\n' "$LICENSE_KEY" > "$LICENSE_FILE")
chmod 600 "$LICENSE_FILE"

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

echo ""
echo "rni-stack installed. Next steps:"
echo ""
echo "  1. Check your license:"
echo "       rni license verify"
echo ""
echo "  2. Add shell completion to ~/.bashrc or ~/.zshrc:"
# shellcheck disable=SC2016  # intentional: print literal, not expand
echo '       eval "$(rni generate-shell-completion bash)"'
echo ""
