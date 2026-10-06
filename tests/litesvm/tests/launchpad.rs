use litesvm::LiteSVM;
use sha2::{Digest, Sha256};
use solana_sdk::{
    instruction::{AccountMeta, Instruction},
    message::Message,
    pubkey::Pubkey,
    signature::{Keypair, Signer},
    system_program,
    transaction::Transaction,
};
use spl_associated_token_account::get_associated_token_address;
use std::path::PathBuf;

fn program_id() -> Pubkey {
    "HTFq7QrFVyHsWReXeh8mjE2Bv69d6UTUUtMG1ZZz9eC6"
        .parse()
        .unwrap()
}

fn disc(name: &str) -> [u8; 8] {
    let h = Sha256::digest(format!("global:{name}").as_bytes());
    let mut out = [0u8; 8];
    out.copy_from_slice(&h[..8]);
    out
}

fn ix_data(name: &str, args: &[u8]) -> Vec<u8> {
    let mut data = disc(name).to_vec();
    data.extend_from_slice(args);
    data
}

fn so_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../target/deploy/mini_launchpad.so")
}

fn load_svm() -> LiteSVM {
    let so = so_path();
    assert!(so.exists(), "missing {}. Run build first.", so.display());
    let mut svm = LiteSVM::new();
    svm.add_program(program_id(), &std::fs::read(&so).unwrap());
    svm
}

fn fund(svm: &mut LiteSVM, kp: &Keypair, lamports: u64) {
    svm.airdrop(&kp.pubkey(), lamports).unwrap();
}

fn send(svm: &mut LiteSVM, payer: &Keypair, ixs: &[Instruction], extra: &[&Keypair]) {
    let bh = svm.latest_blockhash();
    let mut signers: Vec<&Keypair> = vec![payer];
    for s in extra {
        if s.pubkey() != payer.pubkey() {
            signers.push(s);
        }
    }
    let tx = Transaction::new(&signers, Message::new(ixs, Some(&payer.pubkey())), bh);
    svm.send_transaction(tx).unwrap_or_else(|e| panic!("tx failed: {e:?}"));
}

fn send_err(svm: &mut LiteSVM, payer: &Keypair, ixs: &[Instruction], extra: &[&Keypair]) {
    let bh = svm.latest_blockhash();
    let mut signers: Vec<&Keypair> = vec![payer];
    for s in extra {
        if s.pubkey() != payer.pubkey() {
            signers.push(s);
        }
    }
    let tx = Transaction::new(&signers, Message::new(ixs, Some(&payer.pubkey())), bh);
    assert!(svm.send_transaction(tx).is_err(), "expected failure");
}

fn oracle_pda() -> Pubkey {
    Pubkey::find_program_address(&[b"oracle"], &program_id()).0
}

fn initialize_oracle(admin: Pubkey, oracle: Pubkey, price: u64) -> Instruction {
    let mut args = Vec::new();
    args.extend_from_slice(&price.to_le_bytes());
    Instruction {
        program_id: program_id(),
        accounts: vec![
            AccountMeta::new(oracle, false),
            AccountMeta::new(admin, true),
            AccountMeta::new_readonly(system_program::id(), false),
        ],
        data: ix_data("initialize_oracle", &args),
    }
}

fn update_price(admin: Pubkey, oracle: Pubkey, price: u64) -> Instruction {
    let mut args = Vec::new();
    args.extend_from_slice(&price.to_le_bytes());
    Instruction {
        program_id: program_id(),
        accounts: vec![
            AccountMeta::new(oracle, false),
            AccountMeta::new_readonly(admin, true),
        ],
        data: ix_data("update_price", &args),
    }
}

#[test]
fn unit_fee_math() {
    // fee_usd * LAMPORTS_PER_SOL / price
    let fee_usd: u128 = 25_000_000;
    let price: u128 = 25_000_000;
    let fee = fee_usd * 1_000_000_000u128 / price;
    assert_eq!(fee, 1_000_000_000);
}

#[test]
fn oracle_init_and_admin_update() {
    let mut svm = load_svm();
    let admin = Keypair::new();
    fund(&mut svm, &admin, 10_000_000_000);
    let oracle = oracle_pda();

    send(
        &mut svm,
        &admin,
        &[initialize_oracle(admin.pubkey(), oracle, 25_000_000)],
        &[],
    );
    let acc = svm.get_account(&oracle).expect("oracle");
    // skip 8-byte discriminator; admin(32)+price(8)
    let price = u64::from_le_bytes(acc.data[40..48].try_into().unwrap());
    assert_eq!(price, 25_000_000);

    send(
        &mut svm,
        &admin,
        &[update_price(admin.pubkey(), oracle, 30_000_000)],
        &[],
    );
    let acc = svm.get_account(&oracle).unwrap();
    let price = u64::from_le_bytes(acc.data[40..48].try_into().unwrap());
    assert_eq!(price, 30_000_000);
}

#[test]
fn oracle_non_admin_update_fails() {
    let mut svm = load_svm();
    let admin = Keypair::new();
    let stranger = Keypair::new();
    fund(&mut svm, &admin, 10_000_000_000);
    fund(&mut svm, &stranger, 10_000_000_000);
    let oracle = oracle_pda();
    send(
        &mut svm,
        &admin,
        &[initialize_oracle(admin.pubkey(), oracle, 25_000_000)],
        &[],
    );
    send_err(
        &mut svm,
        &stranger,
        &[update_price(stranger.pubkey(), oracle, 1)],
        &[],
    );
}

#[test]
fn oracle_zero_price_fails() {
    let mut svm = load_svm();
    let admin = Keypair::new();
    fund(&mut svm, &admin, 10_000_000_000);
    let oracle = oracle_pda();
    send(
        &mut svm,
        &admin,
        &[initialize_oracle(admin.pubkey(), oracle, 25_000_000)],
        &[],
    );
    send_err(
        &mut svm,
        &admin,
        &[update_price(admin.pubkey(), oracle, 0)],
        &[],
    );
}

#[test]
fn create_token_mints_supply() {
    let mut svm = load_svm();
    let creator = Keypair::new();
    fund(&mut svm, &creator, 10_000_000_000);
    let mint = Keypair::new();
    let (mint_authority, _) =
        Pubkey::find_program_address(&[b"mint_authority", mint.pubkey().as_ref()], &program_id());
    let creator_ata = get_associated_token_address(&creator.pubkey(), &mint.pubkey());

    let mut args = vec![6u8];
    args.extend_from_slice(&1_000u64.to_le_bytes());

    let ix = Instruction {
        program_id: program_id(),
        accounts: vec![
            AccountMeta::new(mint.pubkey(), true),
            AccountMeta::new(creator_ata, false),
            AccountMeta::new_readonly(mint_authority, false),
            AccountMeta::new(creator.pubkey(), true),
            AccountMeta::new_readonly(spl_token::id(), false),
            AccountMeta::new_readonly(spl_associated_token_account::id(), false),
            AccountMeta::new_readonly(system_program::id(), false),
            AccountMeta::new_readonly(solana_sdk::sysvar::rent::id(), false),
        ],
        data: ix_data("create_token", &args),
    };
    send(&mut svm, &creator, &[ix], &[&mint]);
    let ata = svm.get_account(&creator_ata).expect("ata");
    let amount = u64::from_le_bytes(ata.data[64..72].try_into().unwrap());
    assert_eq!(amount, 1_000_000_000);
}

#[test]
fn create_token_with_fee_pays_and_mints() {
    let mut svm = load_svm();
    let payer = Keypair::new();
    let treasury = Keypair::new();
    fund(&mut svm, &payer, 10_000_000_000);
    fund(&mut svm, &treasury, 1_000_000_000);
    let oracle = oracle_pda();
    send(
        &mut svm,
        &payer,
        &[initialize_oracle(payer.pubkey(), oracle, 25_000_000)],
        &[],
    );

    let mint = Keypair::new();
    let (mint_authority, _) =
        Pubkey::find_program_address(&[b"mint_authority", mint.pubkey().as_ref()], &program_id());
    let payer_ata = get_associated_token_address(&payer.pubkey(), &mint.pubkey());
    let before = svm.get_balance(&treasury.pubkey()).unwrap_or(0);

    let mut args = vec![6u8];
    args.extend_from_slice(&500u64.to_le_bytes());
    args.extend_from_slice(&25_000_000u64.to_le_bytes());

    let ix = Instruction {
        program_id: program_id(),
        accounts: vec![
            AccountMeta::new(mint.pubkey(), true),
            AccountMeta::new(payer_ata, false),
            AccountMeta::new_readonly(mint_authority, false),
            AccountMeta::new(payer.pubkey(), true),
            AccountMeta::new(treasury.pubkey(), false),
            AccountMeta::new_readonly(oracle, false),
            AccountMeta::new_readonly(system_program::id(), false),
            AccountMeta::new_readonly(spl_token::id(), false),
            AccountMeta::new_readonly(spl_associated_token_account::id(), false),
            AccountMeta::new_readonly(solana_sdk::sysvar::rent::id(), false),
        ],
        data: ix_data("create_token_with_fee", &args),
    };
    send(&mut svm, &payer, &[ix], &[&mint]);

    let after = svm.get_balance(&treasury.pubkey()).unwrap_or(0);
    assert_eq!(after - before, 1_000_000_000);
    let ata = svm.get_account(&payer_ata).unwrap();
    let amount = u64::from_le_bytes(ata.data[64..72].try_into().unwrap());
    assert_eq!(amount, 500_000_000);
}
