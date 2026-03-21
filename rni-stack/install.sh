#!/usr/bin/env bash
# rni-stack installer
#
# Usage:
#   curl -sSL https://www.alant.health/rni-stack/install.sh | bash
#
# RNI_DEPLOY_TOKEN must be set before running — set it once as a persistent
# environment variable (see installation docs). Stdin is occupied by the
# script itself when piped, so interactive prompts are not possible.
set -euo pipefail

FURY_INDEX="https://${RNI_DEPLOY_TOKEN:-}@rni.fury.site/pypi/"
FIND_LINKS="https://github.com/SimpleITK/SimpleITK/releases/tag/latest"

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

if [ -z "${RNI_DEPLOY_TOKEN:-}" ]; then
    echo "error: RNI_DEPLOY_TOKEN is not set." >&2
    echo "usage: RNI_DEPLOY_TOKEN=<token> curl -sSL https://rni.fury.site/install.sh | bash" >&2
    exit 1
fi

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

if command -v rni >/dev/null 2>&1; then
    echo "==> Upgrading rni-stack..."
    uv tool upgrade rni-stack \
        --index "$FURY_INDEX" \
        --prerelease=allow \
        --find-links "$FIND_LINKS"
else
    echo "==> Installing rni-stack..."
    uv tool install rni-stack \
        --index "$FURY_INDEX" \
        --prerelease=allow \
        --find-links "$FIND_LINKS"
fi

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

echo ""
echo "rni-stack installed. Next steps:"
echo ""
echo "  1. Activate your license:"
echo "       rni license setup"
echo ""
echo "  2. Add shell completion to ~/.bashrc or ~/.zshrc:"
echo '       eval "$(rni generate-shell-completion bash)"'
echo ""
