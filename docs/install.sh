#!/usr/bin/env bash
# Installs (or updates) CleanMac Pro from the latest GitHub release.
#   curl -fsSL https://vantaflow.github.io/cleanmac-pro/install.sh | bash
# Downloaded with curl, the app carries no quarantine flag, so Gatekeeper
# does not block it on first launch.
#
# Options (environment variables):
#   CLEANMAC_VERSION=v2.3.0   install a specific release instead of the latest
#   CLEANMAC_DEST=/Applications   install folder
#   CLEANMAC_NO_OPEN=1        do not launch the app afterwards
set -euo pipefail

REPO="vantaflow/cleanmac-pro"
APP_NAME="CleanMac Pro.app"
DEST="${CLEANMAC_DEST:-/Applications}"

say()  { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mErreur :\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "CleanMac Pro ne fonctionne que sur macOS."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "macOS 14 (Sonoma) ou plus récent est requis."
[[ "$(uname -m)" == "arm64" ]] || fail "les releases sont compilées pour Apple Silicon (arm64) ; sur Intel, compile depuis les sources (voir le README)."

if [[ -n "${CLEANMAC_VERSION:-}" ]]; then
    api="https://api.github.com/repos/$REPO/releases/tags/$CLEANMAC_VERSION"
else
    api="https://api.github.com/repos/$REPO/releases/latest"
fi
say "Recherche de la release…"
# A token (optional) lifts the 60 requests/hour anonymous API limit.
if [[ -n "${GH_TOKEN:-}" ]]; then
    json="$(curl -fsSL -H "Authorization: Bearer $GH_TOKEN" "$api")"
else
    json="$(curl -fsSL "$api")"
fi
url="$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[[ -n "$url" ]] || fail "aucun .zip trouvé dans la release ($api)."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
say "Téléchargement de ${url##*/}…"
curl -fL --progress-bar -o "$tmp/app.zip" "$url"
ditto -x -k "$tmp/app.zip" "$tmp/x"
[[ -d "$tmp/x/$APP_NAME" ]] || fail "l'archive ne contient pas « $APP_NAME »."

# Quit a running copy so it can be replaced.
if pgrep -xq CleanMacPro; then
    say "Fermeture de CleanMac Pro…"
    osascript -e 'quit app "CleanMac Pro"' >/dev/null 2>&1 || true
    sleep 2
    pkill -x CleanMacPro 2>/dev/null || true
fi

sudo_if_needed() { if [[ -w "$DEST" ]]; then "$@"; else sudo "$@"; fi; }
mkdir -p "$DEST" 2>/dev/null || sudo mkdir -p "$DEST"
say "Installation dans ${DEST}…"
sudo_if_needed rm -rf "$DEST/$APP_NAME"
sudo_if_needed ditto "$tmp/x/$APP_NAME" "$DEST/$APP_NAME"
# Belt and braces: no quarantine flag on anything we installed.
sudo_if_needed xattr -dr com.apple.quarantine "$DEST/$APP_NAME" 2>/dev/null || true

version="$(defaults read "$DEST/$APP_NAME/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '?')"
say "CleanMac Pro $version installé ✓"
if [[ -z "${CLEANMAC_NO_OPEN:-}" ]]; then
    open "$DEST/$APP_NAME"
fi
