# Mini-Launchpad justfile (mirrors Makefile targets)

install:
    yarn install
    cd backend && npm install
    cd frontend && npm install

validator:
    solana-test-validator --reset

build:
    ./scripts/wsl_build.sh

deploy:
    solana program deploy target/deploy/mini_launchpad.so --program-id target/deploy/mini_launchpad-keypair.json

init:
    yarn ts-node scripts/init.ts

backend:
    cd backend && npm run start

frontend:
    cd frontend && npm run dev

test:
    cargo test -p mini_launchpad --manifest-path programs/mini_launchpad/Cargo.toml --lib -- --nocapture
    cargo test --manifest-path tests/litesvm/Cargo.toml -- --nocapture
