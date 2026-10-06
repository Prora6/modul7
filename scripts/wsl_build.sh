#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.cargo/bin:/root/.local/share/solana/install/active_release/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

TOOLS=v1.60
echo "Installing/using platform-tools $TOOLS"
cargo-build-sbf --tools-version "$TOOLS" --force-tools-install --version
/root/.cache/solana/${TOOLS#v}/platform-tools/rust/bin/cargo --version || \
  /root/.cache/solana/v1.60/platform-tools/rust/bin/cargo --version || \
  find /root/.cache/solana -path '*/rust/bin/cargo' -exec {} --version \;

# Prefer previously working pinned lock (rebuild it)
rm -f Cargo.lock
cargo generate-lockfile
cargo update -p borsh@1.8.1 --precise 1.5.7 || true
cargo update -p proc-macro-crate@3.5.0 --precise 3.2.0 || true
cargo update -p indexmap --precise 2.7.1 || true
cargo update -p zeroize --precise 1.7.0 || true
cargo update -p zeroize_derive --precise 1.4.2 || true
cargo update -p unicode-segmentation --precise 1.12.0 || true
# Keep anchor macros on 0.32.1
cargo update -p anchor-syn --precise 0.32.1 || true
cargo update -p anchor-attribute-account --precise 0.32.1 || true
cargo update -p anchor-derive-accounts --precise 0.32.1 || true
cargo update -p anchor-attribute-program --precise 0.32.1 || true
cargo update -p anchor-lang-idl --precise 0.1.2 || true

# Use full anchor-spl but without pulling mismatched syn via features
# Already set in Cargo.toml

cargo-build-sbf --tools-version "$TOOLS" --manifest-path programs/mini_launchpad/Cargo.toml
mkdir -p target/deploy
SO=$(find . -name 'mini_launchpad.so' | head -1)
cp -f "$SO" target/deploy/mini_launchpad.so
ls -la target/deploy/
echo BUILD_OK
