#!/usr/bin/env bash
# Pulls the newest image built by GitHub Actions and restarts. The ranking in
# ./data is kept.
set -euo pipefail
cd "$(dirname "$0")"
sudo docker compose pull
sudo docker compose up -d
sudo docker image prune -f
echo "Updated."
