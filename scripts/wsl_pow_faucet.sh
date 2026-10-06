#!/usr/bin/env bash
set -uo pipefail
export PATH="/root/.cargo/bin:/root/.local/share/solana/install/active_release/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

if ! command -v devnet-pow >/dev/null 2>&1; then
  cargo install devnet-pow 2>&1 | tee /tmp/pow-install.log | tail -30
fi

PUB=$(solana-keygen pubkey /root/.config/solana/id.json)
echo "Mining for $PUB"

for round in $(seq 1 30); do
  bal=$(solana balance "$PUB" -u https://api.devnet.solana.com 2>/dev/null | awk '{print $1}')
  echo "round=$round balance=${bal:-0}"
  enough=$(python3 -c "print(1 if float('${bal:-0}') >= 1.5 else 0)")
  if [ "$enough" = "1" ]; then
    echo ENOUGH
    break
  fi
  timeout 90 devnet-pow mine -d 2 --reward 0.05 --no-infer -t 2000000000 || true
done

solana balance "$PUB" -u https://api.devnet.solana.com
