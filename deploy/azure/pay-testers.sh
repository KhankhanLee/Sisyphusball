#!/usr/bin/env bash
# Usage: ./pay-testers.sh [--dry-run]
# Sends 0.01 test-Pi (App-to-User) once to every Pi player in the Testnet
# ranking (data-testnet/scores.json). Paid players are remembered in
# data-testnet/a2u-ledger.json, so running it again only pays newcomers.
# Needs a2u.env next to this script with the TESTNET app's PI_API_KEY and
# APP_WALLET_SEED. Never put a Mainnet wallet seed there.
set -euo pipefail
cd "$(dirname "$0")"
[ -f a2u.env ] || { echo "Create a2u.env first: PI_API_KEY=... and APP_WALLET_SEED=S... (Testnet app)"; exit 1; }
chmod 600 a2u.env
sudo docker run --rm \
  -v "$PWD/a2u:/app:ro" -v "$PWD/data-testnet:/data" --env-file a2u.env \
  node:20-alpine sh -c "cp -r /app /work && cd /work && npm ci --omit=dev --silent && node a2u.js $*"
