#!/usr/bin/env bash
# Usage: ./set-validation-key.sh <key from the Pi Developer Portal>
# Stores the key and restarts the server so /validation-key.txt serves it.
set -euo pipefail
cd "$(dirname "$0")"
[ $# -eq 1 ] || { echo "usage: $0 <validation key>"; exit 1; }
if grep -q '^PI_VALIDATION_KEY=' .env; then
  sed -i "s|^PI_VALIDATION_KEY=.*|PI_VALIDATION_KEY=$1|" .env
else
  echo "PI_VALIDATION_KEY=$1" >> .env
fi
sudo docker compose up -d app
DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
echo "Check: https://$DOMAIN/validation-key.txt — then press Verify in the portal."
