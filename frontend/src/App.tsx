import { useMemo, useState } from "react";
import {
  ConnectionProvider,
  WalletProvider,
  useAnchorWallet,
  useConnection,
  useWallet,
} from "@solana/wallet-adapter-react";
import {
  WalletModalProvider,
  WalletMultiButton,
} from "@solana/wallet-adapter-react-ui";
import { PhantomWalletAdapter } from "@solana/wallet-adapter-wallets";
import {
  clusterApiUrl,
  Keypair,
  PublicKey,
  SystemProgram,
  SYSVAR_RENT_PUBKEY,
} from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  getAssociatedTokenAddressSync,
} from "@solana/spl-token";
import * as anchor from "@coral-xyz/anchor";
import idl from "./idl/mini_launchpad.json";

type ClusterChoice = "localnet" | "devnet";

const LOCAL_RPC = "http://127.0.0.1:8899";

function LaunchpadForm() {
  const { connection } = useConnection();
  const wallet = useAnchorWallet();
  const { publicKey, connected } = useWallet();

  const [supply, setSupply] = useState("1000");
  const [feeUsd, setFeeUsd] = useState("25000000");
  const [treasury, setTreasury] = useState("");
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  const programId = useMemo(() => {
    try {
      return new PublicKey((idl as { address: string }).address);
    } catch {
      return null;
    }
  }, []);

  async function onCreate() {
    if (!wallet || !publicKey || !programId) {
      setStatus("Connect a wallet first.");
      return;
    }
    setBusy(true);
    setStatus("Sending create_token_with_fee...");
    try {
      const provider = new anchor.AnchorProvider(connection, wallet, {
        commitment: "confirmed",
      });
      const program = new anchor.Program(idl as anchor.Idl, provider);
      const [oraclePda] = PublicKey.findProgramAddressSync(
        [Buffer.from("oracle")],
        program.programId
      );
      const mint = Keypair.generate();
      const [mintAuthority] = PublicKey.findProgramAddressSync(
        [Buffer.from("mint_authority"), mint.publicKey.toBuffer()],
        program.programId
      );
      const payerAta = getAssociatedTokenAddressSync(mint.publicKey, publicKey);
      const treasuryPk = treasury.trim()
        ? new PublicKey(treasury.trim())
        : publicKey;

      const sig = await program.methods
        .createTokenWithFee(
          6,
          new anchor.BN(supply),
          new anchor.BN(feeUsd)
        )
        .accounts({
          mint: mint.publicKey,
          payerAta,
          mintAuthority,
          payer: publicKey,
          treasury: treasuryPk,
          oracle: oraclePda,
          systemProgram: SystemProgram.programId,
          tokenProgram: TOKEN_PROGRAM_ID,
          associatedTokenProgram: ASSOCIATED_TOKEN_PROGRAM_ID,
          rent: SYSVAR_RENT_PUBKEY,
        })
        .signers([mint])
        .rpc();

      setStatus(
        `OK\nmint: ${mint.publicKey.toBase58()}\nsignature: ${sig}\noracle: ${oraclePda.toBase58()}`
      );
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      setStatus(`ERROR\n${msg}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="card">
      <label>Initial supply (whole tokens)</label>
      <input value={supply} onChange={(e) => setSupply(e.target.value)} />

      <label>Fee USD (fixed-point, 6 decimals; 25000000 = $25)</label>
      <input value={feeUsd} onChange={(e) => setFeeUsd(e.target.value)} />

      <label>Treasury (empty = your wallet)</label>
      <input
        value={treasury}
        onChange={(e) => setTreasury(e.target.value)}
        placeholder="Treasury pubkey"
      />

      <button
        className="primary"
        disabled={!connected || busy}
        onClick={onCreate}
      >
        {busy ? "Creating..." : "Create token with fee"}
      </button>

      <div className={`status ${status.startsWith("OK") ? "ok" : status.startsWith("ERROR") ? "error" : ""}`}>
        {status || (programId ? `Program: ${programId.toBase58()}` : "Missing IDL address")}
      </div>
    </div>
  );
}

function Shell() {
  const [cluster, setCluster] = useState<ClusterChoice>("localnet");
  const endpoint = cluster === "localnet" ? LOCAL_RPC : clusterApiUrl("devnet");
  const wallets = useMemo(() => [new PhantomWalletAdapter()], []);

  return (
    <ConnectionProvider endpoint={endpoint}>
      <WalletProvider wallets={wallets} autoConnect>
        <WalletModalProvider>
          <h1>Mini-Launchpad</h1>
          <p className="subtitle">
            Oracle-priced token minting — connect wallet and create a token.
          </p>

          <div className="card wallet-row">
            <div>
              <label>Cluster</label>
              <select
                value={cluster}
                onChange={(e) => setCluster(e.target.value as ClusterChoice)}
              >
                <option value="localnet">Localhost (127.0.0.1:8899)</option>
                <option value="devnet">Devnet</option>
              </select>
            </div>
            <WalletMultiButton />
          </div>

          <LaunchpadForm />
        </WalletModalProvider>
      </WalletProvider>
    </ConnectionProvider>
  );
}

export default function App() {
  return <Shell />;
}
