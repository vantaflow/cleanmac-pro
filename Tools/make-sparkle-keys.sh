#!/usr/bin/env bash
# One-time Sparkle key setup (run on a Mac, after `swift build`).
#  1. generate_keys creates the EdDSA pair in your login keychain
#  2. the PUBLIC key is written to Tools/Info.plist (SUPublicEDKey)
#  3. the PRIVATE key is piped to `gh secret set SPARKLE_ED_PRIVATE_KEY` (never written to disk)
# Then commit Tools/Info.plist.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$(find "$ROOT/.build" -type f -name generate_keys -perm -u+x -print -quit 2>/dev/null || true)"
if [[ -z "$GEN" ]]; then
    echo "generate_keys not found — run: swift build" >&2
    exit 1
fi
command -v gh >/dev/null || { echo "gh CLI required (brew install gh; gh auth login)" >&2; exit 1; }

# Creates the pair if missing; with -p, prints the public key (existing or new).
"$GEN" >/dev/null 2>&1 || true
PUB="$("$GEN" -p)"
[[ -n "$PUB" ]] || { echo "Could not read the public key" >&2; exit 1; }

plutil -replace SUPublicEDKey -string "$PUB" "$ROOT/Tools/Info.plist"
echo "Public key written to Tools/Info.plist: $PUB"

"$GEN" -x /dev/stdout | gh secret set SPARKLE_ED_PRIVATE_KEY --repo vantaflow/cleanmac-pro
echo "Secret SPARKLE_ED_PRIVATE_KEY set. Now commit Tools/Info.plist."
