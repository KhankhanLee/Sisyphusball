#!/usr/bin/env bash
# First-time setup on a fresh Ubuntu VM: installs Docker, writes .env, starts
# the game server and HTTPS. Safe to run again.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "==> Installing Docker"
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-v2
fi

if [ ! -f .env ]; then
  echo "==> Settings (saved to $(pwd)/.env)"
  read -rp "Domain, e.g. sisyphusball-testnet.koreacentral.cloudapp.azure.com: " DOMAIN
  read -rp "Contact email shown on Privacy/Terms [hajinchoi139@gmail.com]: " CONTACT_EMAIL
  CONTACT_EMAIL=${CONTACT_EMAIL:-hajinchoi139@gmail.com}
  printf 'DOMAIN=%s\nCONTACT_EMAIL=%s\nPI_VALIDATION_KEY=\n' "$DOMAIN" "$CONTACT_EMAIL" > .env
  chmod 600 .env
fi

mkdir -p data data-testnet
echo "==> Starting"
sudo docker compose pull
sudo docker compose up -d

DOMAIN=$(grep '^DOMAIN=' .env | cut -d= -f2)
echo
echo "Done. In a minute, open: https://$DOMAIN/privacy"
echo "Logs: sudo docker compose logs -f"
