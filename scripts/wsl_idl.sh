#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"
pwd
ls -la target/deploy/
anchor --version

# Hand-roll IDL if anchor idl is flaky; try once with timeout
mkdir -p target/idl target/types
set +e
timeout 90 anchor idl build -p mini_launchpad -o target/idl -t target/types
RC=$?
set -e
echo "idl_exit=$RC"
ls -la target/idl/ || true

# If no IDL, create from template using program address
if [ ! -f target/idl/mini_launchpad.json ]; then
  echo "Writing fallback IDL"
  python3 - <<'PY'
import json, pathlib
addr = "HTFq7QrFVyHsWReXeh8mjE2Bv69d6UTUUtMG1ZZz9eC6"
idl = {
  "address": addr,
  "metadata": {"name": "mini_launchpad", "version": "0.1.0", "spec": "0.1.0", "description": "Mini-Launchpad"},
  "instructions": [
    {
      "name": "initialize_oracle",
      "discriminator": [133, 110, 214, 175, 208, 148, 245, 159],
      "accounts": [
        {"name": "oracle", "writable": True},
        {"name": "admin", "writable": True, "signer": True},
        {"name": "system_program"}
      ],
      "args": [{"name": "initial_price", "type": "u64"}]
    },
    {
      "name": "update_price",
      "discriminator": [61, 34, 121, 199, 144, 16, 118, 138],
      "accounts": [
        {"name": "oracle", "writable": True},
        {"name": "admin", "signer": True}
      ],
      "args": [{"name": "new_price", "type": "u64"}]
    },
    {
      "name": "create_token",
      "discriminator": [84, 52, 204, 228, 24, 140, 234, 75],
      "accounts": [
        {"name": "mint", "writable": True, "signer": True},
        {"name": "creator_ata", "writable": True},
        {"name": "mint_authority"},
        {"name": "creator", "writable": True, "signer": True},
        {"name": "token_program"},
        {"name": "associated_token_program"},
        {"name": "system_program"},
        {"name": "rent"}
      ],
      "args": [{"name": "decimals", "type": "u8"}, {"name": "initial_supply", "type": "u64"}]
    },
    {
      "name": "create_token_with_fee",
      "discriminator": [219, 141, 187, 163, 254, 197, 188, 133],
      "accounts": [
        {"name": "mint", "writable": True, "signer": True},
        {"name": "payer_ata", "writable": True},
        {"name": "mint_authority"},
        {"name": "payer", "writable": True, "signer": True},
        {"name": "treasury", "writable": True},
        {"name": "oracle"},
        {"name": "system_program"},
        {"name": "token_program"},
        {"name": "associated_token_program"},
        {"name": "rent"}
      ],
      "args": [
        {"name": "decimals", "type": "u8"},
        {"name": "initial_supply", "type": "u64"},
        {"name": "fee_usd", "type": "u64"}
      ]
    }
  ],
  "accounts": [
    {"name": "OracleState", "discriminator": [142, 234, 146, 124, 199, 95, 84, 133]}
  ],
  "events": [
    {"name": "TokenCreated", "discriminator": [14, 131, 33, 220, 200, 87, 20, 165]}
  ],
  "errors": [
    {"code": 6000, "name": "InvalidPrice", "msg": "Invalid oracle price"},
    {"code": 6001, "name": "MathOverflow", "msg": "Math overflow"},
    {"code": 6002, "name": "BadOracleDecimals", "msg": "Bad oracle decimals"},
    {"code": 6003, "name": "BadTokenDecimals", "msg": "Bad token decimals"},
    {"code": 6004, "name": "StaleOracle", "msg": "Stale oracle data"}
  ],
  "types": [
    {
      "name": "OracleState",
      "type": {
        "kind": "struct",
        "fields": [
          {"name": "admin", "type": "pubkey"},
          {"name": "price", "type": "u64"},
          {"name": "decimals", "type": "u8"},
          {"name": "last_updated_slot", "type": "u64"},
          {"name": "bump", "type": "u8"}
        ]
      }
    },
    {
      "name": "TokenCreated",
      "type": {
        "kind": "struct",
        "fields": [
          {"name": "creator", "type": "pubkey"},
          {"name": "mint", "type": "pubkey"},
          {"name": "supply", "type": "u64"},
          {"name": "fee_lamports", "type": "u64"},
          {"name": "price", "type": "u64"},
          {"name": "slot", "type": "u64"}
        ]
      }
    }
  ]
}
path = pathlib.Path("target/idl/mini_launchpad.json")
path.write_text(json.dumps(idl, indent=2))
print("wrote", path)
PY
fi

# Compute real discriminators with python sha256
python3 - <<'PY'
import hashlib, json, pathlib
def disc(ns, name):
    h = hashlib.sha256(f"{ns}:{name}".encode()).digest()[:8]
    return list(h)
p = pathlib.Path("target/idl/mini_launchpad.json")
idl = json.loads(p.read_text())
for ix in idl["instructions"]:
    ix["discriminator"] = disc("global", ix["name"])
for acc in idl.get("accounts", []):
    acc["discriminator"] = disc("account", acc["name"])
for ev in idl.get("events", []):
    ev["discriminator"] = disc("event", ev["name"])
p.write_text(json.dumps(idl, indent=2))
print("updated discriminators")
print(json.dumps({ix['name']: ix['discriminator'] for ix in idl['instructions']}, indent=2))
PY

cp -f target/idl/mini_launchpad.json frontend/src/idl/mini_launchpad.json
echo DONE
