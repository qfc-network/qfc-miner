#!/usr/bin/env bash
# QFC Inference Miner — One-click start script
# Provides AI compute to the QFC network and earns rewards.
#
# Usage:
#   ./start-miner.sh              # First run: downloads binary, generates wallet, starts
#   ./start-miner.sh --status     # Check miner status
#   ./start-miner.sh --update     # Update to latest version
#   BUILD=1 ./start-miner.sh      # Force build from source instead of downloading
#
# Supports: macOS (Intel/Apple Silicon), Linux (x86_64)
# No Rust toolchain required — downloads pre-built binaries.

set -euo pipefail

VERSION="${QFC_VERSION:-latest}"
GITHUB_REPO="qfc-network/qfc-core"
INSTALL_DIR="${QFC_MINER_DIR:-$HOME/.qfc-miner}"
WALLET_FILE="$INSTALL_DIR/wallet.json"
RPC_URL="${QFC_MINER_RPC_URL:-https://rpc.testnet.qfc.network}"
BINARY="$INSTALL_DIR/bin/qfc-miner"
BUILD="${BUILD:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Detect platform ---
detect_platform() {
    OS=$(uname -s)
    ARCH=$(uname -m)

    if [[ "$OS" == "Darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            PLATFORM="macos-arm64"
            BACKEND="metal"
            PLATFORM_DESC="macOS Apple Silicon (Metal GPU)"
        else
            PLATFORM="macos-intel"
            BACKEND="cpu"
            PLATFORM_DESC="macOS Intel (CPU)"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        PLATFORM="linux-x86_64"
        if command -v nvidia-smi &>/dev/null; then
            BACKEND="cuda"
            PLATFORM_DESC="Linux x86_64 (NVIDIA GPU)"
        else
            BACKEND="cpu"
            PLATFORM_DESC="Linux x86_64 (CPU)"
        fi
    else
        err "Unsupported OS: $OS"
    fi
}

# --- Download pre-built binary ---
download_binary() {
    mkdir -p "$INSTALL_DIR/bin"

    if [[ "$VERSION" == "latest" ]]; then
        info "Fetching latest release..."
        DOWNLOAD_URL=$(curl -sfL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
            | grep "browser_download_url.*qfc-${PLATFORM}.tar.gz\"" \
            | cut -d'"' -f4)
    else
        DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$VERSION/qfc-${PLATFORM}.tar.gz"
    fi

    if [[ -z "${DOWNLOAD_URL:-}" ]]; then
        warn "No pre-built binary found for $PLATFORM. Falling back to build from source."
        BUILD=1
        return 1
    fi

    info "Downloading qfc-miner for $PLATFORM_DESC..."
    curl -sfL "$DOWNLOAD_URL" -o "$INSTALL_DIR/qfc-${PLATFORM}.tar.gz" || {
        warn "Download failed. Falling back to build from source."
        BUILD=1
        return 1
    }

    # Verify checksum if available
    CHECKSUM_URL="${DOWNLOAD_URL}.sha256"
    if curl -sfL "$CHECKSUM_URL" -o "$INSTALL_DIR/qfc-${PLATFORM}.tar.gz.sha256" 2>/dev/null; then
        cd "$INSTALL_DIR"
        if command -v sha256sum &>/dev/null; then
            sha256sum -c "qfc-${PLATFORM}.tar.gz.sha256" || warn "Checksum verification failed"
        elif command -v shasum &>/dev/null; then
            shasum -a 256 -c "qfc-${PLATFORM}.tar.gz.sha256" || warn "Checksum verification failed"
        fi
    fi

    # Extract
    tar xzf "$INSTALL_DIR/qfc-${PLATFORM}.tar.gz" -C "$INSTALL_DIR/bin/"
    chmod +x "$INSTALL_DIR/bin/qfc-miner"
    rm -f "$INSTALL_DIR/qfc-${PLATFORM}.tar.gz" "$INSTALL_DIR/qfc-${PLATFORM}.tar.gz.sha256"

    ok "Downloaded qfc-miner ($PLATFORM)"
    return 0
}

# --- Build from source (fallback) ---
build_from_source() {
    info "Building from source (this requires Rust and may take a few minutes)..."

    if ! command -v cargo &>/dev/null; then
        warn "Rust not found. Installing via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    local FEATURES="candle"
    if [[ "$BACKEND" == "metal" ]]; then
        FEATURES="metal,candle"
    elif [[ "$BACKEND" == "cuda" ]]; then
        FEATURES="cuda,candle"
    fi

    local SRC_DIR="$INSTALL_DIR/qfc-core"
    if [[ -d "$SRC_DIR" ]]; then
        cd "$SRC_DIR" && git pull --ff-only origin main 2>/dev/null || true
    else
        git clone --depth 1 "https://github.com/$GITHUB_REPO.git" "$SRC_DIR"
        cd "$SRC_DIR"
    fi

    cargo build --release --features "$FEATURES" --bin qfc-miner 2>&1 | tail -3
    mkdir -p "$INSTALL_DIR/bin"
    cp "$SRC_DIR/target/release/qfc-miner" "$INSTALL_DIR/bin/"
    ok "Build complete"
}

# --- Check status ---
if [[ "${1:-}" == "--status" ]]; then
    echo "=== QFC Miner Status ==="
    MINER_PID=$(pgrep -f "qfc-miner" 2>/dev/null || true)
    if [[ -n "$MINER_PID" ]]; then
        echo -e "${GREEN}Running${NC} (PID: $MINER_PID)"
    else
        echo -e "${YELLOW}Not running${NC}"
    fi
    if [[ -f "$WALLET_FILE" ]]; then
        ADDR=$(grep '"address"' "$WALLET_FILE" | cut -d'"' -f4)
        echo "Wallet: $ADDR"
        echo ""
        echo "Balance:"
        curl -s "$RPC_URL" -X POST -H "Content-Type: application/json" \
            -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"0x$ADDR\",\"latest\"],\"id\":1}" \
            | python3 -m json.tool 2>/dev/null || echo "(RPC unavailable)"
    else
        echo "No wallet found. Run ./start-miner.sh first."
    fi
    exit 0
fi

# --- Update ---
if [[ "${1:-}" == "--update" ]]; then
    detect_platform
    info "Updating qfc-miner..."
    if [[ "$BUILD" == "1" ]]; then
        build_from_source
    else
        download_binary || build_from_source
    fi
    ok "Update complete. Restart the miner to use the new version."
    exit 0
fi

# === Main flow ===

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   QFC Inference Miner Setup           ║"
echo "  ║   Earn rewards by providing AI compute║"
echo "  ╚═══════════════════════════════════════╝"
echo ""

# --- Step 1: Detect platform ---
detect_platform
ok "Platform: $PLATFORM_DESC"

# --- Step 2: Get binary ---
mkdir -p "$INSTALL_DIR"

if [[ -x "$BINARY" && "${1:-}" != "--force" ]]; then
    ok "qfc-miner already installed"
elif [[ "$BUILD" == "1" ]]; then
    build_from_source
else
    download_binary || build_from_source
fi

# --- Step 3: Generate wallet (if needed) ---
if [[ -f "$WALLET_FILE" ]]; then
    ADDR=$(grep '"address"' "$WALLET_FILE" | cut -d'"' -f4)
    KEY=$(grep '"private_key"' "$WALLET_FILE" | cut -d'"' -f4)
    ok "Wallet loaded: $ADDR"
else
    info "Generating new miner wallet..."
    WALLET_OUTPUT=$("$BINARY" --generate-wallet 2>&1)

    ADDR=$(echo "$WALLET_OUTPUT" | grep -i "address" | awk '{print $NF}' | tr -d '[:space:]')
    KEY=$(echo "$WALLET_OUTPUT" | grep -i "private" | awk '{print $NF}' | tr -d '[:space:]')

    if [[ -z "$ADDR" || -z "$KEY" ]]; then
        ADDR=$(echo "$WALLET_OUTPUT" | head -1 | awk '{print $NF}')
        KEY=$(echo "$WALLET_OUTPUT" | tail -1 | awk '{print $NF}')
    fi

    cat > "$WALLET_FILE" <<EOJSON
{
  "address": "$ADDR",
  "private_key": "$KEY"
}
EOJSON
    chmod 600 "$WALLET_FILE"
    ok "Wallet created: $ADDR"
    ok "Saved to: $WALLET_FILE"
    echo ""
    warn "BACKUP your private key! If lost, your rewards are gone."
    echo ""
fi

# --- Step 4: Request faucet tokens ---
info "Requesting testnet tokens from faucet..."
FAUCET_RESP=$(curl -sf "$RPC_URL" -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"qfc_requestFaucet\",\"params\":[\"0x$ADDR\"],\"id\":1}" 2>/dev/null || echo "")

if echo "$FAUCET_RESP" | grep -q "result"; then
    ok "Faucet tokens received"
elif echo "$FAUCET_RESP" | grep -q "cooldown\|already"; then
    ok "Faucet: already funded (24h cooldown)"
else
    warn "Faucet request failed (node may be unavailable). You can try later."
fi

# --- Step 5: Start miner ---
echo ""
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Starting QFC Inference Miner            │"
echo "  │  Wallet:  ${ADDR:0:16}...                │"
echo "  │  Backend: $BACKEND                            │"
echo "  │  RPC:     $RPC_URL   │"
echo "  │                                         │"
echo "  │  Press Ctrl+C to stop                   │"
echo "  └─────────────────────────────────────────┘"
echo ""

exec "$BINARY" \
    --wallet "$ADDR" \
    --private-key "$KEY" \
    --validator-rpc "$RPC_URL" \
    --backend "$BACKEND"
