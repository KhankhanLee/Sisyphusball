#!/usr/bin/env bash
# Usage: ./add-mainnet.sh <mainnet domain, e.g. sisyphusball.me>
# One-time move from a Testnet-only server to Mainnet + Testnet:
#   - the current domain, validation key and ranking become the Testnet app's
#   - <domain> becomes the Mainnet app's, starting with an empty ranking
# Afterwards set the Mainnet key with ./set-validation-key.sh.
set -euo pipefail
cd "$(dirname "$0")"
[ $# -eq 1 ] || { echo "usage: $0 <mainnet domain>"; exit 1; }
if grep -q '^TESTNET_DOMAIN=.' .env; then
  echo "Already done: TESTNET_DOMAIN is set in .env"; exit 1
fi

old_domain=$(grep '^DOMAIN=' .env | cut -d= -f2-)
old_key=$(grep '^PI_VALIDATION_KEY=' .env | cut -d= -f2- || true)
sed -i '/^TESTNET_DOMAIN=/d;/^TESTNET_PI_VALIDATION_KEY=/d' .env
sed -i "s|^DOMAIN=.*|DOMAIN=$1|;s|^PI_VALIDATION_KEY=.*|PI_VALIDATION_KEY=|" .env
printf 'TESTNET_DOMAIN=%s\nTESTNET_PI_VALIDATION_KEY=%s\n' "$old_domain" "$old_key" >> .env

sudo docker compose down
if [ -d data ] && [ ! -d data-testnet ]; then mv data data-testnet; fi
mkdir -p data data-testnet
sudo docker compose pull
sudo docker compose up -d

echo
echo "Mainnet: https://$1  (set its key: ./set-validation-key.sh <key>)"
echo "Testnet: https://$old_domain  (ranking kept)"
