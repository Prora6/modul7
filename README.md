# Mini-Launchpad

On-chain token launchpad with a price oracle: create SPL tokens and pay a dynamic SOL fee based on an on-chain oracle price.

Built from course modules **Oracle** + **Token Factory** (sources kept under [`_reference/`](_reference/)).

## Devnet

| Item | Value |
|------|-------|
| **Program ID** | `HTFq7QrFVyHsWReXeh8mjE2Bv69d6UTUUtMG1ZZz9eC6` |
| Deploy wallet | `6TY5EoeTAbJ5ayHCrVyKjCNMs48uuYXybwJX9iqrW5ty` |
| Oracle PDA seeds | `["oracle"]` |
| Oracle PDA | `EPCpqwkrTZ5KqwwBKjC1bNT9DM8xTRRqSkD7ng5vwtGD` |
| Explorer (program) | https://explorer.solana.com/address/HTFq7QrFVyHsWReXeh8mjE2Bv69d6UTUUtMG1ZZz9eC6?cluster=devnet |

### Successful token-creation transactions (Devnet)

> **Status:** public Devnet faucet is currently dry / rate-limited (local IP and GitHub Actions runners both get HTTP 429). Program ID + oracle PDA below are fixed for this keypair; CI workflow [Devnet deploy](https://github.com/Prora6/modul7/actions/workflows/devnet-deploy.yml) retries every 2h and will auto-fill explorer links when an airdrop succeeds.
>
> Manual path once the wallet has ≥2 SOL:
> `wsl -e bash scripts/wsl_devnet.sh`

1. _(initialize_oracle / deploy)_
2. _(create_token_with_fee #1)_
3. _(create_token_with_fee #2)_

### Localnet verification (already run)

Full cycle `validator → build → deploy → init → create_token×2` succeeded on local validator with the same Program ID / PDA:

| Tx | Signature | Explorer (custom RPC) |
|----|-----------|------------------------|
| create #1 | `4HezovzSrpiUTVXqtuYcPNzYzKBJrk9ZySGhwBLC6tsAUmQmKsR4S7drtsvrBQdh8UAvBynk5aTManc5Zd9WEWzk` | [link](https://explorer.solana.com/tx/4HezovzSrpiUTVXqtuYcPNzYzKBJrk9ZySGhwBLC6tsAUmQmKsR4S7drtsvrBQdh8UAvBynk5aTManc5Zd9WEWzk?cluster=custom&customUrl=http%3A%2F%2F127.0.0.1%3A8899) |
| create #2 | `CR9viKLfYKj4HNRgPgzAT9sgPRbfbmpoaMNQ83ywPdPwGwFSQdyx9RPsYFJftpvb2EeTkyKxLi1gFMgE9nZSHAp` | [link](https://explorer.solana.com/tx/CR9viKLfYKj4HNRgPgzAT9sgPRbfbmpoaMNQ83ywPdPwGwFSQdyx9RPsYFJftpvb2EeTkyKxLi1gFMgE9nZSHAp?cluster=custom&customUrl=http%3A%2F%2F127.0.0.1%3A8899) |

## Prerequisites

- WSL Ubuntu recommended on Windows (Solana CLI + Anchor 0.32.1)
- Node.js / Yarn / npm
- `make` or `just`

## Setup (once)

```bash
make install
```

## Localnet cycle

```bash
# terminal 1 (WSL)
solana-test-validator --reset

# terminal 2 (WSL)
./scripts/wsl_build.sh
make deploy
make init                       # prints ORACLE_STATE_PUBKEY
# copy PROGRAM_ID + ORACLE_STATE_PUBKEY into backend/.env

make backend
make frontend                   # Vite — RPC http://127.0.0.1:8899
```

Quick one-shot: `./scripts/wsl_localnet2.sh`

## Tests

```bash
make test
# 1) unit tests for fee/amount math
# 2) LiteSVM integration tests in tests/litesvm
```

## Backend env

See [`backend/.env.example`](backend/.env.example).

## On-chain instructions

- `initialize_oracle(initial_price)`
- `update_price(new_price)` — admin only
- `create_token(decimals, initial_supply)`
- `create_token_with_fee(decimals, initial_supply, fee_usd)` — freshness check + SOL fee via oracle

## Devnet deploy helper

```bash
# after wallet has ≥2 Devnet SOL:
./scripts/wsl_devnet.sh
```
