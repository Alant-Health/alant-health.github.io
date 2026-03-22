#!/usr/bin/env bash
# exeed installer
#
# Usage:
#   curl -sSL https://www.alant.health/exeed/install.sh | bash
#
# ALANT_DEPLOY_TOKEN must be set before running — set it once as a persistent
# environment variable (see installation docs). Stdin is occupied by the
# script itself when piped, so interactive prompts are not possible.
set -euo pipefail

ALANT_INDEX="https://${ALANT_DEPLOY_TOKEN:-}@www.alant.software/pypi/"

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

if [ -z "${ALANT_DEPLOY_TOKEN:-}" ]; then
    echo "error: ALANT_DEPLOY_TOKEN is not set." >&2
    echo "usage: curl -sSL https://www.alant.health/exeed/install.sh | bash" >&2
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
# Python 3.13
# --------------------------------------------------------------------------- #

if ! uv python find 3.13 >/dev/null 2>&1; then
    echo "==> Installing Python 3.13..."
    uv python install 3.13
fi

# --------------------------------------------------------------------------- #
# exeed
# --------------------------------------------------------------------------- #

if command -v iexeed >/dev/null 2>&1; then
    echo "==> Upgrading exeed..."
    uv tool upgrade exeed \
        --index "$ALANT_INDEX"
else
    echo "==> Installing exeed..."
    uv tool install exeed \
        --index "$ALANT_INDEX"
fi

# --------------------------------------------------------------------------- #
# Post-install
# --------------------------------------------------------------------------- #

echo ""
echo "exeed installed. Run the application:"
echo ""
echo "  exeed       # launch GUI"
echo "  iexeed      # launch CLI"
echo ""
