/**
 * Create a token with fee on the configured cluster (for Devnet demo txs).
 * Usage: yarn ts-node scripts/create_token.ts
 */
import * as anchor from "@coral-xyz/anchor";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  getAssociatedTokenAddressSync,
} from "@solana/spl-token";
import { Keypair, PublicKey, SystemProgram, SYSVAR_RENT_PUBKEY } from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const idlPath = path.join(__dirname, "..", "target", "idl", "mini_launchpad.json");
  const idl = JSON.parse(fs.readFileSync(idlPath, "utf8"));
  const program = new anchor.Program(idl, provider);

  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("oracle")],
    program.programId
  );

  const treasuryEnv = process.env.TREASURY;
  const treasury = treasuryEnv
    ? new PublicKey(treasuryEnv)
    : provider.wallet.publicKey;

  const mint = Keypair.generate();
  const [mintAuthority] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), mint.publicKey.toBuffer()],
    program.programId
  );
  const payerAta = getAssociatedTokenAddressSync(
    mint.publicKey,
    provider.wallet.publicKey
  );

  const supply = new anchor.BN(process.env.SUPPLY || "1000");
  const feeUsd = new anchor.BN(process.env.FEE_USD || "25000000");

  // Refresh oracle so create_token_with_fee does not hit StaleOracle on slow scripts.
  const refreshPrice = new anchor.BN(25_000_000 + Math.floor(Math.random() * 10_000));
  await program.methods
    .updatePrice(refreshPrice)
    .accounts({
      oracle: oraclePda,
      admin: provider.wallet.publicKey,
    })
    .rpc();

  const sig = await program.methods
    .createTokenWithFee(6, supply, feeUsd)
    .accounts({
      mint: mint.publicKey,
      payerAta,
      mintAuthority,
      payer: provider.wallet.publicKey,
      treasury,
      oracle: oraclePda,
      systemProgram: SystemProgram.programId,
      tokenProgram: TOKEN_PROGRAM_ID,
      associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
      rent: SYSVAR_RENT_PUBKEY,
    })
    .signers([mint])
    .rpc();

  const rpc = provider.connection.rpcEndpoint;
  const cluster =
    rpc.includes("devnet") ? "devnet" : rpc.includes("127.0.0.1") || rpc.includes("localhost")
      ? "custom&customUrl=" + encodeURIComponent(rpc)
      : "devnet";

  console.log("create_token_with_fee signature:", sig);
  console.log("mint:", mint.publicKey.toBase58());
  console.log(
    "explorer:",
    `https://explorer.solana.com/tx/${sig}?cluster=${cluster}`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
