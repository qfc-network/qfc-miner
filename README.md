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

## Quick Start (Docker)

```bash
# Download config files
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/docker-compose.yml
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/genesis.json

# Start a full node
docker compose up -d

# Check logs
docker logs -f qfc-node
```

That's it. Your node will connect to the bootnode and start syncing.

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

## Build from Source

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

## Inference Miner (Earn Rewards with AI Compute)

QFC v2.0 supports **AI inference mining** — provide compute power to run AI models and earn QFC rewards.

### One-Click Start (macOS / Linux)

```bash
curl -sLO https://raw.githubusercontent.com/qfc-network/testnet/main/scripts/start-miner.sh
chmod +x start-miner.sh
./start-miner.sh
```

The script automatically:
1. Installs Rust (if needed)
2. Detects your hardware (CPU/Metal/CUDA)
3. Builds the miner binary
4. Generates a wallet
5. Requests faucet tokens
6. Starts mining


### Windows (PowerShell)

```powershell
iwr https://raw.githubusercontent.com/qfc-network/qfc-miner/main/scripts/install.ps1 | iex
```

The script automatically:
1. Detects your GPU (NVIDIA CUDA or CPU fallback)
2. Downloads the pre-built `qfc-miner.exe`
3. Generates a wallet
4. Requests faucet tokens
5. Starts mining

> **Requires:** Windows 10/11 x86_64, PowerShell 5.1+
> **NVIDIA GPU:** Automatically used if `nvidia-smi` is found

### Manual Setup

```bash
# 1. Build (Intel Mac or Linux CPU-only)
git clone https://github.com/qfc-network/qfc-core.git
cd qfc-core
cargo build --release --features candle --bin qfc-miner

# Apple Silicon (Metal GPU):
# cargo build --release --features metal,candle --bin qfc-miner

# 2. Generate wallet
./target/release/qfc-miner --generate-wallet

# 3. Start mining
./target/release/qfc-miner \
  --wallet <YOUR_WALLET_ADDRESS> \
  --private-key <YOUR_PRIVATE_KEY> \
  --validator-rpc https://rpc.testnet.qfc.network \
  --backend cpu
```

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
| `QFC_MINER_WALLET` | — | Wallet address (hex) |
| `QFC_MINER_PRIVATE_KEY` | — | Private key (hex) |
| `QFC_MINER_BACKEND` | `auto` | `cpu`, `metal`, `cuda`, or `auto` |
| `QFC_MINER_MODEL_DIR` | `./models` | Model cache directory |
| `QFC_MINER_MAX_MEMORY` | `0` (auto) | Max memory in MB |

### Docker

```bash
docker run -e QFC_MINER_WALLET=<ADDR> \
           -e QFC_MINER_PRIVATE_KEY=<KEY> \
           -e QFC_MINER_RPC_URL=https://rpc.testnet.qfc.network \
           -e QFC_MINER_BACKEND=cpu \
           ghcr.io/qfc-network/qfc-miner:main
```

### How It Works

1. Miner fetches inference tasks from the network (every ~10s)
2. Loads the required AI model (cached after first download)
3. Runs inference and submits a cryptographic proof
4. Validators verify proofs (5% random spot-check)
5. Honest miners earn block rewards proportional to compute contribution
6. Dishonest proofs → 5% stake slash + 6h ban

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
