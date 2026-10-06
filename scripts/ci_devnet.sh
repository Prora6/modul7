#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

solana config set --url https://api.devnet.solana.com
solana balance

mkdir -p target/deploy target/idl
cp -f deploy-artifacts/mini_launchpad.so target/deploy/mini_launchpad.so
cp -f deploy-artifacts/mini_launchpad.json target/idl/mini_launchpad.json
test -f target/deploy/mini_launchpad-keypair.json

solana program deploy target/deploy/mini_launchpad.so \
  --program-id target/deploy/mini_launchpad-keypair.json \
  --url https://api.devnet.solana.com \
  | tee /tmp/devnet-deploy.out

export ANCHOR_PROVIDER_URL=https://api.devnet.solana.com
export ANCHOR_WALLET="$HOME/.config/solana/id.json"

yarn ts-node scripts/init.ts | tee /tmp/devnet-init.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c1.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c2.out
yarn ts-node scripts/create_token.ts | tee /tmp/devnet-c3.out

{
  echo "PROGRAM_ID=HTFq7QrFVyHsWReXeh8mjE2Bv69d6UTUUtMG1ZZz9eC6"
  echo "ORACLE_PDA=EPCpqwkrTZ5KqwwBKjC1bNT9DM8xTRRqSkD7ng5vwtGD"
  echo "DEPLOYER=$(solana-keygen pubkey)"
  echo "---"
  grep -E 'signature:|ORACLE|PROGRAM|explorer:|Signature' /tmp/devnet-*.out || true
} | tee /tmp/ci_devnet_summary.txt

echo DEVNET_OK
