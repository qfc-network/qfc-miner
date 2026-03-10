# QFC Inference Miner — Windows One-Click Install Script
# Provides AI compute to the QFC network and earns rewards.
#
# Usage (PowerShell as Administrator):
#   iwr https://raw.githubusercontent.com/qfc-network/qfc-miner/main/scripts/install.ps1 | iex
#
# Or download and run:
#   .\install.ps1              # Install and start miner
#   .\install.ps1 -Status      # Check miner status
#   .\install.ps1 -Update      # Force update to latest version
#
# Supports: Windows 10/11 x86_64 (NVIDIA GPU via CUDA or CPU)
# A dedicated CUDA build (qfc-windows-x86_64-cuda) is available for NVIDIA GPUs.
# The script auto-detects your GPU and downloads the appropriate version.
# No Rust toolchain required — downloads pre-built binaries.

param(
    [switch]$Status,
    [switch]$Update,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$GITHUB_REPO = "qfc-network/qfc-core"
$INSTALL_DIR = "$env:USERPROFILE\.qfc-miner"
$WALLET_FILE = "$INSTALL_DIR\wallet.json"
$RPC_URL     = if ($env:QFC_MINER_RPC_URL) { $env:QFC_MINER_RPC_URL } else { "https://rpc.testnet.qfc.network" }
$BINARY      = "$INSTALL_DIR\bin\qfc-miner.exe"
$VERSION_FILE = "$INSTALL_DIR\.version"

function Info  ($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok    ($msg) { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Warn  ($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Err   ($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# --- Detect GPU ---
function Detect-Backend {
    try {
        $nvidiaSmi = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $gpuInfo = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1
            if ($gpuInfo) {
                Ok "NVIDIA GPU detected: $gpuInfo"
                return "cuda"
            }
        }
    } catch {}
    Ok "No NVIDIA GPU detected — using CPU backend"
    return "cpu"
}

# --- Status ---
if ($Status) {
    Write-Host "`n=== QFC Miner Status ===" -ForegroundColor Cyan
    $proc = Get-Process "qfc-miner" -ErrorAction SilentlyContinue
    if ($proc) {
        Ok "Running (PID: $($proc.Id))"
    } else {
        Warn "Not running"
    }
    if (Test-Path $WALLET_FILE) {
        $wallet = Get-Content $WALLET_FILE | ConvertFrom-Json
        Write-Host "Wallet: $($wallet.address)"
    } else {
        Warn "No wallet found. Run install.ps1 first."
    }
    exit 0
}

# --- Banner ---
Write-Host ""
Write-Host "  +=======================================+" -ForegroundColor Cyan
Write-Host "  |   QFC Inference Miner Setup           |" -ForegroundColor Cyan
Write-Host "  |   Earn rewards by providing AI compute|" -ForegroundColor Cyan
Write-Host "  +=======================================+" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Detect platform ---
$Backend = Detect-Backend
$Platform = "windows-x86_64"
if ($Backend -eq "cuda") { $Platform = "windows-x86_64-cuda" }
Info "Platform: Windows x86_64 ($Backend)"

# --- Step 2: Get binary ---
New-Item -ItemType Directory -Force -Path "$INSTALL_DIR\bin" | Out-Null

function Download-Binary {
    Info "Fetching latest release..."
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$GITHUB_REPO/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -like "qfc-${Platform}.zip" } | Select-Object -First 1
        if (-not $asset) {
            # fallback to cpu version
            $asset = $release.assets | Where-Object { $_.name -like "qfc-windows-x86_64.zip" } | Select-Object -First 1
        }
        if (-not $asset) { return $false }

        $zipPath = "$INSTALL_DIR\qfc-windows.zip"
        Info "Downloading qfc-miner ($($release.tag_name))..."
        Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath

        # Verify checksum if available
        $checksumAsset = $release.assets | Where-Object { $_.name -like "qfc-${Platform}.zip.sha256" } | Select-Object -First 1
        if ($checksumAsset) {
            $expectedHash = (Invoke-WebRequest $checksumAsset.browser_download_url).Content.Trim().Split(" ")[0]
            $actualHash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
            if ($actualHash -ne $expectedHash.ToLower()) {
                Warn "Checksum mismatch! File may be corrupted."
            } else {
                Ok "Checksum verified"
            }
        }

        Expand-Archive $zipPath "$INSTALL_DIR\bin\" -Force
        Remove-Item $zipPath -Force
        $release.tag_name | Set-Content $VERSION_FILE
        Ok "Downloaded qfc-miner"
        return $true
    } catch {
        Warn "Download failed: $_"
        return $false
    }
}

$needInstall = (-not (Test-Path $BINARY)) -or $Update -or $Force

if ($needInstall) {
    $downloaded = Download-Binary
    if (-not $downloaded) {
        Err "Could not download qfc-miner.exe. No pre-built binary available for Windows yet.`nPlease check https://github.com/$GITHUB_REPO/releases"
    }
} else {
    Ok "qfc-miner already installed"

    # Check for updates
    if (-not $env:QFC_NO_UPDATE) {
        try {
            $latest = (Invoke-RestMethod "https://api.github.com/repos/$GITHUB_REPO/releases/latest").tag_name
            $local = if (Test-Path $VERSION_FILE) { Get-Content $VERSION_FILE } else { "" }
            if ($latest -and $local -ne $latest) {
                Warn "Update available: $local -> $latest"
                Info "Updating..."
                Download-Binary | Out-Null
            } else {
                Ok "qfc-miner is up to date"
            }
        } catch {
            Warn "Could not check for updates"
        }
    }
}

# --- Step 3: Generate wallet ---
if (Test-Path $WALLET_FILE) {
    $wallet = Get-Content $WALLET_FILE | ConvertFrom-Json
    $Addr = $wallet.address
    $Key  = $wallet.private_key
    Ok "Wallet loaded: $Addr"
} else {
    Info "Generating new miner wallet..."
    $walletOutput = & $BINARY --generate-wallet 2>&1

    $Addr = ($walletOutput | Select-String -Pattern '0x[0-9a-fA-F]{40}').Matches[0].Value
    $Key  = ($walletOutput | Select-String -Pattern '0x[0-9a-fA-F]{64}').Matches[0].Value

    if (-not $Addr -or -not $Key) {
        Err "Failed to generate wallet. Output: $walletOutput"
    }

    @{ address = $Addr; private_key = $Key } | ConvertTo-Json | Set-Content $WALLET_FILE
    Ok "Wallet created: $Addr"
    Ok "Saved to: $WALLET_FILE"
    Write-Host ""
    Warn "BACKUP your private key! If lost, your rewards are gone."
    Write-Host "  Private key: $Key" -ForegroundColor Yellow
    Write-Host ""
}

# --- Step 4: Request faucet tokens ---
Info "Requesting testnet tokens from faucet..."
try {
    $faucetBody = @{ address = $Addr } | ConvertTo-Json
    $faucetResp = Invoke-RestMethod "https://faucet.testnet.qfc.network/api/faucet" -Method Post -Body $faucetBody -ContentType "application/json" -ErrorAction SilentlyContinue
    Ok "Faucet tokens requested"
} catch {
    Warn "Faucet request failed (may already be funded or unavailable)"
}

# --- Step 5: Start miner ---
Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host "  |  Starting QFC Inference Miner            |" -ForegroundColor Green
Write-Host "  |  Wallet:  $($Addr.Substring(0,18))...          |" -ForegroundColor Green
Write-Host "  |  Backend: $Backend                            |" -ForegroundColor Green
Write-Host "  |                                          |" -ForegroundColor Green
Write-Host "  |  Press Ctrl+C to stop                    |" -ForegroundColor Green
Write-Host "  +------------------------------------------+" -ForegroundColor Green
Write-Host ""

& $BINARY `
    --wallet $Addr `
    --private-key $Key `
    --validator-rpc $RPC_URL `
    --backend $Backend
