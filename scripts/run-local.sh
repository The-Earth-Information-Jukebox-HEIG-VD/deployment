#!/bin/bash
# Build and run the full Earth Information Jukebox stack from local sources.
# Usage: ./scripts/run-local.sh [up|down|logs|rebuild]
#
# Requires the sibling repos ../webapp, ../sonification and ../datasets.

set -euo pipefail
cd "$(dirname "$0")/.."

COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.local.yml)

for repo in ../webapp ../sonification ../datasets/data; do
  [ -d "$repo" ] || { echo "Missing $repo (repos must sit next to deployment/)"; exit 1; }
done
if [ ! -f .env ]; then
  echo "Missing deployment/.env. Create it from the template, then review the values:"
  echo "  cp .env.example .env"
  exit 1
fi
set -a; . ./.env; set +a
if [ -z "${VITE_API_URL:-}" ]; then
  echo "VITE_API_URL is not set in deployment/.env (needed to build the webapp image)."
  echo "Add it, e.g.:  VITE_API_URL=/api   (see .env.example)"
  exit 1
fi

case "${1:-up}" in
  up)      "${COMPOSE[@]}" up -d --build --wait ;;
  rebuild) "${COMPOSE[@]}" build --no-cache && "${COMPOSE[@]}" up -d --wait ;;
  down)    "${COMPOSE[@]}" down; exit 0 ;;
  logs)    "${COMPOSE[@]}" logs -f; exit 0 ;;
  *)       echo "Usage: $0 [up|down|logs|rebuild]"; exit 1 ;;
esac

echo
echo "Earth Information Jukebox is running:"
echo "  Webapp       http://localhost:${WEBAPP_PORT:-80}"
echo "  API docs     http://localhost:${BACKEND_PORT:-8000}/docs"
echo "  API health   http://localhost:${BACKEND_PORT:-8000}/api/health"
echo "  (first start converts the datasets in the background; health shows preparing_data until done)"
