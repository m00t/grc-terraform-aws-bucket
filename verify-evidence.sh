#!/usr/bin/env bash
# verify-evidence.sh <bundle.tar.gz>
# Proves an evidence bundle is intact and authentic, without trusting whoever handed it to you.
# Each check exits non-zero on failure. Prints CHAIN INTACT only if every check passes.

# Expects, in the current folder (override with env vars):
#   evidence.tar.gz.sha256  - hash sidecar written when the bundle was created   (SIDECAR)
#   evidence.sig.bundle     - Cosign signature bundle written when it was signed (SIG_BUNDLE)
set -euo pipefail

BUNDLE="${1:?usage: verify-evidence.sh <bundle.tar.gz>}"
SIDECAR="${SIDECAR:-evidence.tar.gz.sha256}"
SIG_BUNDLE="${SIG_BUNDLE:-evidence.sig.bundle}"

# Only signatures made by this repo's grc-gate workflow, via GitHub Actions OIDC, are accepted.
OIDC_ISSUER="https://token.actions.githubusercontent.com"
IDENTITY_REGEXP='^https://github\.com/m00t/grc-terraform-aws-bucket/\.github/workflows/grc-gate\.yml@'

fail() { echo "FAIL: $1"; exit 1; }

for f in "$BUNDLE" "$SIDECAR" "$SIG_BUNDLE"; do
  [ -f "$f" ] || fail "missing file: $f"
done

# INTEGRITY: has the bundle changed since it was created?
# Recompute its SHA-256 and compare it to the sidecar.
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "$BUNDLE" | awk '{print $1}')
else
  actual=$(shasum -a 256 "$BUNDLE" | awk '{print $1}')   # macOS
fi
expected=$(awk '{print $1}' "$SIDECAR")
if [ "$actual" != "$expected" ]; then
  echo "  expected: $expected"
  echo "  actual:   $actual"
  fail "INTEGRITY - bundle hash does not match the sidecar (bundle was modified)"
fi
echo "PASS: INTEGRITY - SHA-256 matches the sidecar"

# AUTHENTICITY + TIMELINESS: who signed it & and when?
# Verifies the signature, the Sigstore certificate (pinned to GitHub Actions and this repo's workflow) and the signed timestamp in the public transparency log.
if ! cosign verify-blob "$BUNDLE" \
      --bundle "$SIG_BUNDLE" \
      --certificate-oidc-issuer "$OIDC_ISSUER" \
      --certificate-identity-regexp "$IDENTITY_REGEXP"; then
  fail "AUTHENTICITY - signature not valid for this bundle, issuer or workflow identity"
fi
echo "PASS: AUTHENTICITY + TIMELINESS - signed by grc-gate.yml in m00t/grc-terraform-aws-bucket, logged in Rekor"

# PRESERVATION (stretch): is the vaulted copy still under Object Lock?
# Not configured yet. Added with the immutable vault.
echo "SKIP: PRESERVATION - no vault configured"

echo "CHAIN INTACT"