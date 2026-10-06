/**
 * Off-chain oracle feeder for Mini-Launchpad.
 * Reads backend/.env and periodically (or once) sends update_price.
 */
import * as anchor from "@coral-xyz/anchor";
import { Connection, Keypair, PublicKey } from "@solana/web3.js";
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

dotenv.config({ path: path.join(__dirname, "..", ".env") });

function expandHome(p: string): string {
  if (p.startsWith("~/")) {
    return path.join(os.homedir(), p.slice(2));
  }
  return p;
}

function loadKeypair(walletPath: string): Keypair {
  const raw = fs.readFileSync(expandHome(walletPath), "utf8");
  const secret = Uint8Array.from(JSON.parse(raw));
  return Keypair.fromSecretKey(secret);
}

async function updateOnce(
  program: anchor.Program,
  oraclePda: PublicKey,
  admin: Keypair
): Promise<void> {
  const mockPrice = 1_500_000 + Math.floor(Math.random() * 100_000);
  console.log(`[feeder] mock price (6 decimals): ${mockPrice}`);

  const sig = await program.methods
    .updatePrice(new anchor.BN(mockPrice))
    .accounts({
      oracle: oraclePda,
      admin: admin.publicKey,
    })
    .signers([admin])
    .rpc();

  console.log(`[feeder] signature: ${sig}`);
  const oracle = await (program.account as any).oracleState.fetch(oraclePda);
  console.log(
    `[feeder] price=${oracle.price.toString()} last_updated_slot=${oracle.lastUpdatedSlot.toString()}`
  );
}

async function main() {
  const rpcUrl = process.env.RPC_URL || "http://127.0.0.1:8899";
  const programIdStr = process.env.PROGRAM_ID;
  const oracleStr = process.env.ORACLE_STATE_PUBKEY;
  const walletPath =
    process.env.ANCHOR_WALLET ||
    path.join(os.homedir(), ".config", "solana", "id.json");
  const intervalMs = Number(process.env.FEED_INTERVAL_MS || "15000");

  if (!programIdStr || !oracleStr) {
    throw new Error(
      "Set PROGRAM_ID and ORACLE_STATE_PUBKEY in backend/.env (see .env.example)"
    );
  }

  const admin = loadKeypair(walletPath);
  const connection = new Connection(rpcUrl, "confirmed");
  const wallet = new anchor.Wallet(admin);
  const provider = new anchor.AnchorProvider(connection, wallet, {
    commitment: "confirmed",
  });
  anchor.setProvider(provider);

  const idlPath = path.join(
    __dirname,
    "..",
    "..",
    "target",
    "idl",
    "mini_launchpad.json"
  );
  if (!fs.existsSync(idlPath)) {
    throw new Error(`IDL not found: ${idlPath}. Run make build first.`);
  }
  const idl = JSON.parse(fs.readFileSync(idlPath, "utf8"));
  // Ensure address matches env
  idl.address = programIdStr;
  const program = new anchor.Program(idl, provider);
  const oraclePda = new PublicKey(oracleStr);

  console.log(`[feeder] RPC=${rpcUrl}`);
  console.log(`[feeder] program=${programIdStr}`);
  console.log(`[feeder] oracle=${oracleStr}`);
  console.log(`[feeder] admin=${admin.publicKey.toBase58()}`);

  if (intervalMs <= 0) {
    await updateOnce(program, oraclePda, admin);
    return;
  }

  // eslint-disable-next-line no-constant-condition
  while (true) {
    try {
      await updateOnce(program, oraclePda, admin);
    } catch (e) {
      console.error("[feeder] update failed:", e);
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
