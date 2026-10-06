#!/usr/bin/env bash
# Patch README Devnet tx section from /tmp/ci_devnet_summary.txt + signed outs
set -euo pipefail
SUMMARY=${1:-/tmp/ci_devnet_summary.txt}
README=README.md

init_sig=$(grep -oE 'initialize_oracle signature: [1-9A-HJ-NP-Za-km-z]{64,88}' /tmp/devnet-init.out 2>/dev/null | awk '{print $NF}' || true)
# if already initialized, look for any sig line
c1=$(grep -oE 'create_token_with_fee signature: [1-9A-HJ-NP-Za-km-z]{64,88}' /tmp/devnet-c1.out | awk '{print $NF}')
c2=$(grep -oE 'create_token_with_fee signature: [1-9A-HJ-NP-Za-km-z]{64,88}' /tmp/devnet-c2.out | awk '{print $NF}')
c3=$(grep -oE 'create_token_with_fee signature: [1-9A-HJ-NP-Za-km-z]{64,88}' /tmp/devnet-c3.out | awk '{print $NF}')

link() {
  echo "https://explorer.solana.com/tx/$1?cluster=devnet"
}

tmp=$(mktemp)
python3 - "$README" "$tmp" "$init_sig" "$c1" "$c2" "$c3" <<'PY'
import sys,re
path, out, init_sig, c1, c2, c3 = sys.argv[1:7]
text=open(path,encoding='utf-8').read()
lines=[]
if init_sig:
    lines.append(f"1. [initialize_oracle](https://explorer.solana.com/tx/{init_sig}?cluster=devnet) — `{init_sig}`")
else:
    lines.append("1. _(oracle already initialized on this PDA)_")
lines.append(f"2. [create_token_with_fee #1](https://explorer.solana.com/tx/{c1}?cluster=devnet) — `{c1}`")
lines.append(f"3. [create_token_with_fee #2](https://explorer.solana.com/tx/{c2}?cluster=devnet) — `{c2}`")
if c3:
    lines.append(f"4. [create_token_with_fee #3](https://explorer.solana.com/tx/{c3}?cluster=devnet) — `{c3}`")
block="\n".join(lines)
# replace section between heading and Localnet verification
pat=r"(### Successful token-creation transactions \(Devnet\)\n)([\s\S]*?)(\n### Localnet verification)"
repl=r"\1\n"+block+r"\n\3"
new, n = re.subn(pat, repl, text, count=1)
if n!=1:
    raise SystemExit('README section not found')
open(out,'w',encoding='utf-8').write(new)
print('patched', out)
PY
mv "$tmp" "$README"
