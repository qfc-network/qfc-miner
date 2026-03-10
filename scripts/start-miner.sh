#!/usr/bin/env bash
# QFC Inference Miner — One-click start script
# Provides AI compute to the QFC network and earns rewards.
#
# Usage:
#   ./start-miner.sh              # Start miner (auto-checks for updates on every launch)
#   ./start-miner.sh --status     # Check miner status
#   ./start-miner.sh --update     # Force update to latest version
#   BUILD=1 ./start-miner.sh      # Force build from source instead of downloading
#   QFC_NO_UPDATE=1 ./start-miner.sh  # Skip auto-update check
#   QFC_NO_TUI=1 ./start-miner.sh     # Disable TUI dashboard (plain log output)
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
        if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            PLATFORM="linux-arm64"
            BACKEND="cpu"
            PLATFORM_DESC="Linux ARM64 (CPU)"
        else
            PLATFORM="linux-x86_64"
            if command -v nvidia-smi &>/dev/null; then
                BACKEND="cuda"
                PLATFORM_DESC="Linux x86_64 (NVIDIA GPU)"
            elif lspci 2>/dev/null | grep -qi 'amd.*vga\|radeon\|amd/ati'; then
                if command -v rocm-smi &>/dev/null || [[ -d /opt/rocm ]]; then
                    PLATFORM="linux-x86_64-rocm"
                    BACKEND="rocm"
                    PLATFORM_DESC="Linux x86_64 (AMD GPU via ROCm)"
                else
                    BACKEND="cpu"
                    PLATFORM_DESC="Linux x86_64 (AMD GPU detected — install ROCm for GPU acceleration)"
                fi
            else
                BACKEND="cpu"
                PLATFORM_DESC="Linux x86_64 (CPU)"
            fi
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
        FEATURES="coreml"
    elif [[ "$BACKEND" == "cuda" ]]; then
        FEATURES="cuda,candle"
    elif [[ "$BACKEND" == "rocm" ]]; then
        FEATURES="rocm"
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
    # Save version tag
    LATEST_VER=$(curl -sfL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4) || true
    [[ -n "${LATEST_VER:-}" ]] && echo "$LATEST_VER" > "$INSTALL_DIR/.version"
    ok "Update complete. Restart the miner to use the new version."
    exit 0
fi

# --- Check for updates (compares local version tag with latest GitHub release) ---
check_for_update() {
    # Skip if no binary installed yet
    [[ -x "$BINARY" ]] || return 0

    # Read saved version tag (if any)
    local VERSION_FILE="$INSTALL_DIR/.version"
    local LOCAL_VER=""
    [[ -f "$VERSION_FILE" ]] && LOCAL_VER=$(cat "$VERSION_FILE" 2>/dev/null)

    info "Checking for updates..."
    local LATEST_VER
    LATEST_VER=$(curl -sfL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4) || true

    if [[ -z "${LATEST_VER:-}" ]]; then
        warn "Could not check for updates (GitHub API unreachable). Continuing with current version."
        return 0
    fi

    if [[ "$LOCAL_VER" == "$LATEST_VER" ]]; then
        ok "qfc-miner is up to date ($LATEST_VER)"
        return 0
    fi

    if [[ -n "$LOCAL_VER" ]]; then
        info "Update available: $LOCAL_VER → $LATEST_VER"
    else
        info "Latest release: $LATEST_VER (local version unknown)"
    fi

    local DISPLAY_VER="${LOCAL_VER:-unknown}"
    local VER_LINE="${DISPLAY_VER} → ${LATEST_VER}"
    echo -e "${YELLOW}  ┌───────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │                                               │${NC}"
    printf "${YELLOW}  │   %-44s│${NC}\n" "A new version of qfc-miner is available!"
    printf "${YELLOW}  │   %-44s│${NC}\n" "$VER_LINE"
    echo -e "${YELLOW}  │                                               │${NC}"
    echo -e "${YELLOW}  └───────────────────────────────────────────────┘${NC}"

    # Auto-update unless QFC_NO_UPDATE=1
    if [[ "${QFC_NO_UPDATE:-0}" == "1" ]]; then
        warn "Auto-update disabled (QFC_NO_UPDATE=1). Skipping."
        return 0
    fi

    info "Updating qfc-miner..."
    VERSION="$LATEST_VER"
    if [[ "$BUILD" == "1" ]]; then
        build_from_source
    else
        download_binary || build_from_source
    fi

    # Save version tag
    echo "$LATEST_VER" > "$VERSION_FILE"
    ok "Updated to $LATEST_VER"
}

# === Main flow ===

echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║                                               ║"
echo "  ║   QFC Inference Miner Setup                   ║"
echo "  ║   Earn rewards by providing AI compute        ║"
echo "  ║                                               ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""

# --- Step 1: Detect platform ---
detect_platform
ok "Platform: $PLATFORM_DESC"

# --- Step 2: Get binary ---
mkdir -p "$INSTALL_DIR"

if [[ -x "$BINARY" && "${1:-}" != "--force" ]]; then
    ok "qfc-miner already installed"
    # Check for updates on every start
    check_for_update
elif [[ "$BUILD" == "1" ]]; then
    build_from_source
    # Save initial version tag
    INIT_VER=$(curl -sfL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4) || true
    [[ -n "${INIT_VER:-}" ]] && echo "$INIT_VER" > "$INSTALL_DIR/.version"
else
    download_binary || build_from_source
    # Save initial version tag
    INIT_VER=$(curl -sfL "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
        | grep '"tag_name"' | head -1 | cut -d'"' -f4) || true
    [[ -n "${INIT_VER:-}" ]] && echo "$INIT_VER" > "$INSTALL_DIR/.version"
fi

# --- Step 3: Generate wallet (if needed) ---
if [[ -f "$WALLET_FILE" ]]; then
    ADDR=$(grep '"address"' "$WALLET_FILE" | cut -d'"' -f4)
    KEY=$(grep '"private_key"' "$WALLET_FILE" | cut -d'"' -f4)
    ok "Wallet loaded: $ADDR"
else
    info "Generating new miner wallet..."
    WALLET_OUTPUT=$("$BINARY" --generate-wallet 2>&1)

    ADDR=$(echo "$WALLET_OUTPUT" | grep -oE '0x[0-9a-fA-F]{40}' | head -1)
    KEY=$(echo "$WALLET_OUTPUT" | grep -oE '0x[0-9a-fA-F]{64}' | head -1)

    if [[ -z "$ADDR" || -z "$KEY" ]]; then
        err "Failed to parse wallet output. Raw output:\n$WALLET_OUTPUT"
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
echo "  ┌───────────────────────────────────────────────┐"
echo "  │                                               │"
printf "  │   %-44s│\n" "Starting QFC Inference Miner"
printf "  │   %-44s│\n" "Wallet:  ${ADDR:0:20}..."
printf "  │   %-44s│\n" "Backend: $BACKEND"
printf "  │   %-44s│\n" "RPC:     $RPC_URL"
echo "  │                                               │"
printf "  │   %-44s│\n" "Press Ctrl+C to stop"
echo "  │                                               │"
echo "  └───────────────────────────────────────────────┘"
echo ""

DASHBOARD_FLAG=""
if [ -t 0 ] && [ "${QFC_NO_TUI:-0}" != "1" ]; then
    echo -e "${CYAN}Enable TUI dashboard? (interactive stats & logs)${NC}"
    echo -e "  ${GREEN}Y${NC} = TUI dashboard  |  ${YELLOW}n${NC} = plain log output"
    printf "  [Y/n]: "
    read -r -t 10 ans || ans=""
    case "$ans" in
        [nN]) ;;
        *)    DASHBOARD_FLAG="--dashboard" ;;
    esac
    echo ""
fi

exec "$BINARY" \
    --wallet "$ADDR" \
    --private-key "$KEY" \
    --validator-rpc "$RPC_URL" \
    --backend auto \
    $DASHBOARD_FLAG
