# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Community-facing testnet onboarding repo for the QFC (Quantum-Flux Chain) blockchain. Provides everything needed to join the QFC testnet as a full node, mining node, validator, or inference miner. This is NOT the internal testnet infrastructure (that's `qfc-testnet`).

## Repository Contents

- `docker-compose.yml` — Single-service Docker Compose for community nodes (full node, miner, or validator via env vars)
- `genesis.json` — Testnet genesis block (Chain ID 9000, PoC consensus, 5 initial validators, 100-block epochs, 3s block time)
- `scripts/start-miner.sh` — One-click inference miner setup script (downloads binary, generates wallet, requests faucet, starts mining)
- `README.md` — User-facing documentation

## Network Details

| Item | Value |
|------|-------|
| Chain ID | 9000 |
| RPC | `https://rpc.testnet.qfc.network` |
| Explorer | `https://explorer.testnet.qfc.network` |
| Faucet | `https://faucet.testnet.qfc.network` |
| Consensus | Proof of Contribution (PoC) — 7 scoring dimensions |
| Docker image | `ghcr.io/qfc-network/qfc-core:main` |

## start-miner.sh Architecture

The script supports three modes: default (full setup + start), `--status` (check running miner), `--update` (update binary).

Flow: detect platform → download binary (or build from source as fallback) → generate Ed25519 wallet → request faucet tokens via `qfc_requestFaucet` RPC → exec miner process.

Supported platforms: macOS Intel (CPU), macOS Apple Silicon (Metal), Linux x86_64 (CPU/CUDA/ROCm), Linux ARM64 (CPU). Backend auto-detection: nvidia-smi → CUDA, lspci AMD + ROCm → ROCm, Apple Silicon → Metal, else CPU.

Wallet stored at `~/.qfc-miner/wallet.json` (chmod 600). Binary installed to `~/.qfc-miner/bin/qfc-miner`.

Set `BUILD=1` to force building from source instead of downloading pre-built binaries.

## Related Repos

- `qfc-core` — Blockchain node + miner binary (Rust). Source of the Docker image and miner binary.
- `qfc-testnet` — Internal testnet deployment infrastructure (Docker Compose with full stack: nodes, explorer, monitoring, Traefik)
- `qfc-explorer` — Next.js block explorer frontend
- `qfc-explorer-api` — Fastify API backend for the explorer
