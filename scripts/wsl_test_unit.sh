#!/usr/bin/env bash
set -euo pipefail
export PATH="/root/.local/share/solana/install/active_release/bin:/root/.cargo/bin:$PATH"
cd "/mnt/d/Yandex Rust/modul7"

# Unit tests in program crate (math)
cargo test -p mini_launchpad --manifest-path programs/mini_launchpad/Cargo.toml --lib -- --nocapture 2>&1 | tee /tmp/unit.log | tail -40 || true

# Add unit tests module if missing - run via --tests on litesvm unit_* only
cd tests/litesvm
# Pin deps carefully; only run unit tests that don't need LiteSVM first by filtering
cargo test unit_ -- --nocapture 2>&1 | tee /tmp/litesvm-unit.log | tail -50
