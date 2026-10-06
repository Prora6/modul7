#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

export ANCHOR_PROVIDER_URL=http://127.0.0.1:8899
export ANCHOR_WALLET=/root/.config/solana/id.json

# Ensure validator is up
if ! solana cluster-version >/dev/null 2>&1; then
  echo "validator not running"
  exit 1
fi

yarn ts-node scripts/create_token.ts | tee /tmp/create2.out
yarn ts-node scripts/create_token.ts | tee /tmp/create3.out
echo CREATE_OK
