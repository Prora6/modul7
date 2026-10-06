#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

# Wallet + config
mkdir -p /root/.config/solana
test -f /root/.config/solana/id.json || solana-keygen new --no-bip39-passphrase -o /root/.config/solana/id.json -f
solana config set --url localhost

# Kill old validator if any
pkill -f solana-test-validator || true
sleep 1
rm -rf test-ledger
solana-test-validator --reset --quiet >/tmp/validator.log 2>&1 &
VPID=$!
echo "validator pid=$VPID"
for i in $(seq 1 30); do
  if solana cluster-version >/dev/null 2>&1; then break; fi
  sleep 1
done
solana airdrop 10 || true
solana balance

# Deploy
solana program deploy target/deploy/mini_launchpad.so --program-id target/deploy/mini_launchpad-keypair.json

# Yarn deps for scripts
if [ ! -d node_modules ]; then
  yarn install
fi

export ANCHOR_PROVIDER_URL=http://127.0.0.1:8899
export ANCHOR_WALLET=/root/.config/solana/id.json
yarn ts-node scripts/init.ts | tee /tmp/init.out
yarn ts-node scripts/create_token.ts | tee /tmp/create1.out
yarn ts-node scripts/create_token.ts | tee /tmp/create2.out

echo LOCALNET_OK
