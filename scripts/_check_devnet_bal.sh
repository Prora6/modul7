#!/usr/bin/env bash
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
ADDR=6TY5EoeTAbJ5ayHCrVyKjCNMs48uuYXybwJX9iqrW5ty
python3 <<PY
import json,urllib.request
addr="$ADDR"
def rpc(method, params):
    req=urllib.request.Request(
        "https://api.devnet.solana.com",
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
        headers={"Content-Type":"application/json"},
    )
    return json.load(urllib.request.urlopen(req, timeout=30))
bal=rpc("getBalance",[addr])
print("lamports", bal["result"]["value"], "SOL", bal["result"]["value"]/1e9)
sigs=rpc("getSignaturesForAddress",[addr,{"limit":10}])
for s in sigs.get("result") or []:
    print(s.get("signature"), s.get("err"), s.get("blockTime"))
PY
# rent estimate for program
python3 - <<'PY'
# rough: 281208 bytes program data
size=281208
# BPF loader upgradeable: programdata account rent ~ size * 6960 + overhead?
print("so_bytes", size)
PY
solana rent 281208 -u https://api.devnet.solana.com 2>&1 || true
