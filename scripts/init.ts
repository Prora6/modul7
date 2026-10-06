/**
 * Initialize oracle PDA on the configured cluster.
 * Prints ORACLE_STATE_PUBKEY for backend/.env
 */
import * as anchor from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const idlPath = path.join(__dirname, "..", "target", "idl", "mini_launchpad.json");
  if (!fs.existsSync(idlPath)) {
    throw new Error(`IDL not found at ${idlPath}. Run: make build && make deploy`);
  }
  const idl = JSON.parse(fs.readFileSync(idlPath, "utf8"));
  const program = new anchor.Program(idl, provider);

  const [oraclePda] = PublicKey.findProgramAddressSync(
    [Buffer.from("oracle")],
    program.programId
  );

  const existing = await provider.connection.getAccountInfo(oraclePda);
  if (existing) {
    console.log("Oracle already initialized.");
  } else {
    // 25_000_000 = $25 with 6 decimals (price quote unit used by fee math)
    const initialPrice = new anchor.BN(25_000_000);
    const sig = await program.methods
      .initializeOracle(initialPrice)
      .accounts({
        oracle: oraclePda,
        admin: provider.wallet.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();
    console.log("initialize_oracle signature:", sig);
  }

  const oracle = await (program.account as any).oracleState.fetch(oraclePda);
  console.log("");
  console.log("ORACLE_STATE_PUBKEY=" + oraclePda.toBase58());
  console.log("PROGRAM_ID=" + program.programId.toBase58());
  console.log("admin=" + oracle.admin.toBase58());
  console.log("price=" + oracle.price.toString());
  console.log("decimals=" + oracle.decimals);
  console.log("");
  console.log("Copy ORACLE_STATE_PUBKEY into backend/.env (see backend/.env.example)");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
