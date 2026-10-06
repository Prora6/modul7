#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

pkill -f solana-test-validator || true
sleep 1
rm -rf test-ledger
solana-test-validator --reset --quiet >/tmp/validator.log 2>&1 &
echo "validator $!"
for i in $(seq 1 40); do
  if solana -u localhost cluster-version >/dev/null 2>&1; then break; fi
  sleep 1
done
solana -u localhost airdrop 10 || true

solana program deploy target/deploy/mini_launchpad.so \
  --program-id target/deploy/mini_launchpad-keypair.json \
  --url localhost

export ANCHOR_PROVIDER_URL=http://127.0.0.1:8899
export ANCHOR_WALLET=/root/.config/solana/id.json
yarn ts-node scripts/init.ts
yarn ts-node scripts/create_token.ts
yarn ts-node scripts/create_token.ts
echo LOCALNET_OK
