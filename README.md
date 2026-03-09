# QFC Testnet

Join the QFC (Quantum-Flux Chain) public testnet.

## Network Info

| Item | Value |
|------|-------|
| Chain ID | `9000` |
| RPC | `https://rpc.testnet.qfc.network` |
| WebSocket | `wss://rpc.testnet.qfc.network/ws` |
| Explorer | `https://explorer.testnet.qfc.network` |
| Faucet | `https://faucet.testnet.qfc.network` |
| Block Time | ~3 seconds |
| Consensus | Proof of Contribution (PoC) |

---

## Inference Miner (Earn QFC with AI Compute)

QFC v2.0 supports **AI inference mining** — provide compute power to run AI models and earn QFC rewards.

### Option 1: One-Click Script (Recommended)

```bash
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/scripts/start-miner.sh
chmod +x start-miner.sh
./start-miner.sh
```

The script automatically detects your hardware, downloads the binary, generates a wallet, requests faucet tokens, and starts mining.

```bash
./start-miner.sh --status    # Check miner status
./start-miner.sh --update    # Update to latest version
BUILD=1 ./start-miner.sh     # Build from source instead of downloading
```

### Option 2: Build from Source

```bash
# Clone and build
git clone https://github.com/qfc-network/qfc-core.git
cd qfc-core
cargo build --release --bin qfc-miner

# Apple Silicon (Metal GPU acceleration):
# cargo build --release --features metal --bin qfc-miner

# With TUI dashboard:
# cargo build --release --features tui --bin qfc-miner

# Generate wallet
./target/release/qfc-miner --generate-wallet
# Save the Address and Private Key!

# Start mining
export QFC_MINER_WALLET=0x<YOUR_ADDRESS>
export QFC_MINER_PRIVATE_KEY=0x<YOUR_PRIVATE_KEY>
./target/release/qfc-miner \
  --validator-rpc https://rpc.testnet.qfc.network \
  --backend cpu
```

### Option 3: Docker

```bash
docker run --rm \
  -e QFC_MINER_MODE=true \
  -e QFC_MINER_WALLET=0x<YOUR_ADDRESS> \
  -e QFC_MINER_PRIVATE_KEY=0x<YOUR_PRIVATE_KEY> \
  -e QFC_MINER_RPC_URL=https://rpc.testnet.qfc.network \
  -e QFC_MINER_BACKEND=cpu \
  ghcr.io/qfc-network/qfc-core:latest
```

> Note: Set `QFC_MINER_MODE=true` to run as inference miner instead of full node.

### TUI Dashboard

Build with the `tui` feature to get a real-time terminal dashboard:

```bash
cargo build --release --features tui --bin qfc-miner

./target/release/qfc-miner \
  --wallet $QFC_MINER_WALLET \
  --private-key $QFC_MINER_PRIVATE_KEY \
  --validator-rpc https://rpc.testnet.qfc.network \
  --backend cpu \
  --dashboard
```

The dashboard shows earnings, task history, performance stats, and a scrollable log panel.

| Key | Action |
|-----|--------|
| `↑` / `k` | Scroll logs up |
| `↓` / `j` | Scroll logs down |
| `PgUp` / `PgDn` | Scroll 5 lines |
| `Home` / `End` | Jump to oldest / latest |
| `q` / `Esc` | Quit |

Logs are also saved to `qfc-miner.log` in the working directory.

### GPU Tiers & Supported Tasks

| Tier | Memory | Hardware Examples | Tasks |
|------|--------|-------------------|-------|
| Hot | 32 GB+ | M2 Ultra, M3 Max, A100 | All models, large LLMs |
| Warm | 16–31 GB | M1/M2/M3 Pro | Medium models, embeddings |
| Cold | < 16 GB | Intel Mac, M1/M2 base | Small models, embeddings |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `QFC_MINER_RPC_URL` | `https://rpc.testnet.qfc.network` | Validator RPC endpoint |
| `QFC_MINER_WALLET` | — | Wallet address (hex, with 0x prefix) |
| `QFC_MINER_PRIVATE_KEY` | — | Private key (hex, with 0x prefix) |
| `QFC_MINER_BACKEND` | `auto` | `cpu`, `metal`, `cuda`, or `auto` |
| `QFC_MINER_MODEL_DIR` | `./models` | Model cache directory |
| `QFC_MINER_MAX_MEMORY` | `0` (auto) | Max memory in MB |

### How It Works

1. Miner registers with the validator and reports hardware capabilities
2. Validator assigns inference tasks every ~10 seconds (embedding, text generation, etc.)
3. Miner runs inference and submits a cryptographic proof
4. Validators verify proofs (5% random spot-check re-execution)
5. Honest miners earn QFC rewards proportional to compute contribution
6. Dishonest proofs → 5% stake slash + 6h ban

---

## Full Node (Docker)

```bash
# Download config files
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/docker-compose.yml
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/genesis.json

# Start a full node
docker compose up -d

# Check logs
docker logs -f qfc-node
```

Your node will connect to the bootnode and start syncing.

### Mining (optional)

Contribute compute power and earn the **20% compute contribution** score in PoC:

```bash
QFC_MINING_ENABLED=true QFC_MINING_THREADS=4 docker compose up -d
```

### Validator (requires stake)

Run a validator node (requires 10,000+ QFC staked):

```bash
QFC_VALIDATOR_KEY=<your-secret-key-hex> QFC_MINING_ENABLED=true docker compose up -d
```

## Build from Source (Full Node)

```bash
git clone https://github.com/qfc-network/qfc-core.git
cd qfc-core
cargo build --release

# Run full node
./target/release/qfc-node \
  --datadir ./data \
  --bootnodes "/ip4/bootnode.testnet.qfc.network/tcp/30303/p2p/<PEER_ID>"

# With mining
./target/release/qfc-node \
  --datadir ./data \
  --bootnodes "/ip4/bootnode.testnet.qfc.network/tcp/30303/p2p/<PEER_ID>" \
  --mine --threads 4
```

## Get Test Tokens

Visit the [Faucet](https://faucet.testnet.qfc.network) to get **100 QFC** (24h cooldown).

## Add to MetaMask

| Field | Value |
|-------|-------|
| Network Name | QFC Testnet |
| RPC URL | `https://rpc.testnet.qfc.network` |
| Chain ID | `9000` |
| Symbol | `QFC` |
| Explorer | `https://explorer.testnet.qfc.network` |

## Verify Your Node

```bash
# Current block height
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Node info & peer count
curl -s http://localhost:8545 -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"qfc_nodeInfo","params":[],"id":1}'
```

## Become a Validator

1. Get 10,000+ QFC from the faucet or community
2. Generate a validator key: `./target/release/qfc-node keygen`
3. Stake your QFC via the staking RPC
4. Start with `QFC_VALIDATOR_KEY=<key> QFC_MINING_ENABLED=true docker compose up -d`

## PoC Contribution Scores

Your validator priority is determined by 7 dimensions:

| Dimension | Weight | How to Earn |
|-----------|--------|-------------|
| Staking | 30% | Stake more QFC |
| Compute | 20% | Enable mining (`--mine`) |
| Uptime | 15% | Keep your node online |
| Accuracy | 15% | Don't miss assigned blocks |
| Network | 10% | Good P2P connectivity |
| Storage | 5% | Serve state snapshots |
| Reputation | 5% | Long-term honest behavior |

## Hardware Requirements

| Role | CPU | RAM | Disk | Network |
|------|-----|-----|------|---------|
| Full node | 2 cores | 4 GB | 50 GB SSD | 10 Mbps |
| Mining node | 4+ cores | 4 GB | 50 GB SSD | 10 Mbps |
| Inference miner | 2+ cores | 8 GB+ | 20 GB SSD | 10 Mbps |
| Validator | 4 cores | 8 GB | 100 GB SSD | 50 Mbps |

## Troubleshooting

**Node not syncing?**
- Check port `30303` is open (firewall / security group)
- Verify genesis.json matches (re-download if unsure)

**Reset node data:**
```bash
docker compose down -v
docker compose up -d
```

**Update to latest:**
```bash
docker compose pull
docker compose up -d
```

## Links

- [QFC Core](https://github.com/qfc-network/qfc-core) — Blockchain source code
- [Explorer](https://explorer.testnet.qfc.network) — Block explorer
- [Faucet](https://faucet.testnet.qfc.network) — Get test tokens
