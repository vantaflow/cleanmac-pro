#!/usr/bin/env bash
# Creates a STABLE self-signed code-signing identity in the login keychain.
#
# Why: an ad-hoc signature (`codesign -s -`) gets a fresh cdhash on every
# rebuild, so macOS/TCC treats each build as a brand-new app and re-asks for
# Files/Automation permission every time. A stable certificate gives the app a
# constant "designated requirement", so a permission granted once persists
# across rebuilds. Run this ONCE; build-app.sh then picks it up automatically.
set -euo pipefail

CERT_NAME="CleanMac Pro Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

# Note: no -v — a self-signed cert is untrusted, so the "valid only" filter
# would hide it even though codesign can sign with it fine.
if security find-identity -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "✓ Signing identity already present: $CERT_NAME"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -subj "/CN=$CERT_NAME/O=TurkeyCode" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

# -legacy is required: OpenSSL 3's default PKCS12 crypto can't be read by
# Apple's `security import` (MAC verification fails).
openssl pkcs12 -export -legacy -out "$TMP/identity.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$CERT_NAME" -passout pass:cmp >/dev/null 2>&1

# Import cert+key, and pre-authorise codesign to use the key without a GUI
# prompt (-T). The partition-list step is what actually silences the prompt.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P cmp \
    -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1

# Trust is optional: signing (and thus TCC persistence) works without it; it
# only affects the Gatekeeper "unidentified developer" gate. Use sudo -n so we
# never hang on a password prompt in a non-interactive shell.
echo "Attempting to trust the certificate (optional)…"
sudo -n security add-trusted-cert -d -r trustAsRoot \
    -p codeSign -k /Library/Keychains/System.keychain "$TMP/cert.pem" 2>/dev/null || \
    echo "  (trust skipped — run with sudo later if you want; not required)"

echo "✓ Installed identity: $CERT_NAME"
echo "  On the first codesign you may get one keychain prompt — click 'Always Allow'."
echo "  To silence it entirely, run (needs your login password):"
echo "    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k <login-pw> \"$KEYCHAIN\""
