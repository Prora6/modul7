#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

solana config set --url https://api.devnet.solana.com
# Fund wallet
solana airdrop 2 || solana airdrop 1 || true
solana balance

# Deploy
solana program deploy target/deploy/mini_launchpad.so \
  --program-id target/deploy/mini_launchpad-keypair.json \
  --url https://api.devnet.solana.com

export ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
export ANCHOR_WALLET=/root/.config/solana/id.json

yarn ts-node scripts/init.ts | tee /tmp/devnet-init.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c1.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c2.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c3.out

echo DEVNET_OK
cat /tmp/devnet-init.out
echo '---'
grep -E 'signature:|ORACLE|PROGRAM|explorer:' /tmp/devnet-*.out
