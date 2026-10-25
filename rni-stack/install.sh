#!/usr/bin/env bash
# rni-stack installer
#
# Usage:
#   curl -sSL https://www.alant.health/rni-stack/install.sh | RNI_LICENSE_KEY=<key> bash
#
# Your Alant license key is the only credential you need: the installer reads
# the package-index token from the license, installs rni-stack, and writes the
# key to ~/.alant.license so every Alant application on this machine is
# licensed.  On a machine that already holds the key (in ~/.alant.license, or
# ~/.rni-stack.license from RNI Stack 1.7), RNI_LICENSE_KEY may be left out.
# Stdin is occupied by the script itself when piped, so interactive prompts
# are not possible.
set -euo pipefail

FURY_HOST="rni.fury.site"
FIND_LINKS="https://github.com/SimpleITK/SimpleITK/releases/tag/latest"
# Alant Health's license account (a public identifier, not a secret).
KEYGEN_ACCOUNT="319ec55f-0bda-4593-8ddc-3b1ad2b0068d"
LICENSE_FILE="$HOME/.alant.license"
# Where RNI Stack 1.7 and earlier saved the same key.
LEGACY_LICENSE_FILE="$HOME/.rni-stack.license"

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

# A developer's editable install is updated with git; installing the release
# over it would silently replace the tool built from their working copy.  The
# tool receipt names the editable source path when there is one.
if command -v uv >/dev/null 2>&1; then
    receipt="$(uv tool dir 2>/dev/null || true)/rni-stack/uv-receipt.toml"
    editable=""
    if [ -f "$receipt" ]; then
        editable="$(sed -nE "s/.*name = \"rni-stack\"[^}]*editable = [\"']([^\"']+)[\"'].*/\1/p" "$receipt" | head -n 1)"
    fi
    if [ -n "$editable" ]; then
        echo "error: rni-stack is an editable install from ${editable}." >&2
        echo "       Update it with \`git pull\` there; this installer would replace it" >&2
        echo "       with the released package.  To switch to the release on purpose," >&2
        echo "       run \`uv tool uninstall rni-stack\` first." >&2
        exit 1
    fi
fi

# --------------------------------------------------------------------------- #
# Credentials: the license key yields the package-index token
# --------------------------------------------------------------------------- #

# Print the value of a license file's KEY= line; nothing when there is none.
saved_license_key() {
    [ -r "$1" ] || return 0
    awk '/^KEY=/ { sub(/^KEY=/, ""); print; exit }' "$1" | tr -d "\"' \t\r"
}

LICENSE_KEY="${RNI_LICENSE_KEY:-}"
# A licensed machine needs no key to upgrade: take the one it saved, or the
# one an earlier RNI Stack saved in its own file.
if [ -z "$LICENSE_KEY" ]; then
    for saved in "$LICENSE_FILE" "$LEGACY_LICENSE_FILE"; do
        LICENSE_KEY="$(saved_license_key "$saved")"
        if [ -n "$LICENSE_KEY" ]; then
            echo "==> Using the license key saved in ${saved}."
            break
        fi
    done
fi
if [ -z "$LICENSE_KEY" ]; then
    echo "error: RNI_LICENSE_KEY is not set and no saved license key was found." >&2
    echo "usage: curl -sSL https://www.alant.health/rni-stack/install.sh | RNI_LICENSE_KEY=<key> bash" >&2
    exit 1
fi

echo "==> Reading the package-index token from your license..."
status=0
response="$(curl -sS --fail \
    -H "Accept: application/vnd.api+json" \
    -H "Authorization: License ${LICENSE_KEY}" \
    "https://api.keygen.sh/v1/accounts/${KEYGEN_ACCOUNT}/licenses/${LICENSE_KEY}")" || status=$?
if [ "$status" -eq 22 ]; then
    # curl's exit code for an HTTP error: the server answered and refused.
    echo "error: the license server rejected this key." >&2
    echo "       The installer needs your Alant license key (the KEY= value in" >&2
    echo "       ~/.alant.license, or ~/.rni-stack.license from RNI Stack 1.7)," >&2
    echo "       not the package-index token." >&2
    exit 1
elif [ "$status" -ne 0 ]; then
    echo "error: could not reach the license server (curl exit ${status})." >&2
    exit 1
fi
# The token is read from the response once Python is available (below): the
# server's JSON layout is its own choice, so it is parsed as JSON, never
# pattern-matched.

# --------------------------------------------------------------------------- #
# uv
# --------------------------------------------------------------------------- #

if ! command -v uv >/dev/null 2>&1; then
    echo "==> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for the remainder of this script
    export PATH="${UV_INSTALL_DIR:-$HOME/.local/bin}:$PATH"
else
    # An existing uv keeps every fix it predates, so refresh it before it
    # installs anything. Best-effort: a uv installed by a package manager
    # cannot update itself, and the install continues with it.
    echo "==> Updating uv..."
    if ! uv self update; then
        echo "warning: could not update uv; continuing with $(uv --version)." >&2
        echo "         If a package manager installed uv, update it there." >&2
    fi
fi

# --------------------------------------------------------------------------- #
# Python 3.14
# --------------------------------------------------------------------------- #

if ! uv python find 3.14 >/dev/null 2>&1; then
    echo "==> Installing Python 3.14..."
    uv python install 3.14
fi

# The package-index token: data.attributes.metadata's rni token, else the
# family one.  The response goes in on stdin, never on a command line.
DEPLOY_TOKEN="$(uv run --no-project --python 3.14 python -c '
import json, sys
try:
    doc = json.load(sys.stdin)
except ValueError:
    doc = {}
data = doc.get("data") if isinstance(doc, dict) else None
attributes = data.get("attributes") if isinstance(data, dict) else None
meta = attributes.get("metadata") if isinstance(attributes, dict) else None
meta = meta if isinstance(meta, dict) else {}
token = meta.get("rniDeployToken") or meta.get("deployToken") or ""
print(token if isinstance(token, str) else "")
' <<<"$response")"
if [ -z "$DEPLOY_TOKEN" ]; then
    echo "error: this license carries no package-index token (rniDeployToken). Contact your administrator." >&2
    exit 1
fi

FURY_INDEX="https://${DEPLOY_TOKEN}@${FURY_HOST}/pypi/"

# --------------------------------------------------------------------------- #
# rni-stack
# --------------------------------------------------------------------------- #

echo "==> Installing / upgrading rni-stack..."
# uv before 0.12 refuses SimpleITK's 3.0 beta, which itxpy asks for, under its
# default pre-release policy and quietly resolves an old rni-stack on
# SimpleITK 2.x instead.  Only such a uv gets --prerelease=allow, which also
# admits every other package's dev builds (httpx 1.0.dev6) and is saved with
# the tool.  A version that cannot be read counts as old: allow always resolves.
PRERELEASE_FLAG=""
uv_version="$(uv --version 2>/dev/null | awk '{ print $2 }' || true)"
uv_major="${uv_version%%.*}"
uv_minor="${uv_version#*.}"
uv_minor="${uv_minor%%.*}"
case "${uv_major}.${uv_minor}" in
    *[!0-9.]* | .* | *.) PRERELEASE_FLAG="--prerelease=allow" ;;
    *)
        if [ "$uv_major" -eq 0 ] && [ "$uv_minor" -lt 12 ]; then
            PRERELEASE_FLAG="--prerelease=allow"
        fi
        ;;
esac
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
    ${PRERELEASE_FLAG:+"$PRERELEASE_FLAG"} \
    --find-links "$FIND_LINKS"

# --------------------------------------------------------------------------- #
# License
# --------------------------------------------------------------------------- #

echo "==> Saving your license key to ${LICENSE_FILE}..."
# Written to a private temporary file (mktemp creates it 0600) and renamed into
# place, so a symlink at the license path is replaced, never written through,
# and no reader sees a half-written file -- as alant-auth's save_license does.
license_tmp="$(mktemp "${LICENSE_FILE}.XXXXXX")"
printf 'KEY=%s\n' "$LICENSE_KEY" > "$license_tmp"
mv -f "$license_tmp" "$LICENSE_FILE"

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
