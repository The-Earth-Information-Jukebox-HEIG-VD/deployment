# Earth Information Jukebox - Deployment

Docker Compose orchestration for the Earth Information Jukebox project.

## Quick Start

```bash
# Clone this repository
git clone git@github.com:The-Earth-Information-Jukebox-HEIG-VD/deployment.git
cd deployment

# Configure environment
cp .env.example .env

# Login to GitHub Container Registry (if images are private)
docker login ghcr.io

# Start all services
docker compose up -d

# View logs
docker compose logs -f
```

## Run Locally From Source

Builds the images from the sibling repositories instead of pulling them, and
mounts `../datasets/data` read-only (no copy into a volume):

```
SpaceAppsChallenge/
├── deployment/     ← run from here
├── webapp/
├── sonification/
└── datasets/
```

```bash
cp .env.example .env            # required: set VITE_API_URL (webapp build arg)
./scripts/run-local.sh          # build + start, waits until healthy
./scripts/run-local.sh logs     # follow logs
./scripts/run-local.sh down     # stop
```

`VITE_API_URL` is baked into the webapp bundle at build time; the webapp
Dockerfile writes it to `.env` before `npm run build`. Keep `/api` so the
browser goes through the nginx proxy. If port 8000 is taken on your machine,
set `BACKEND_PORT` to another port (the webapp still reaches the backend
internally on 8000).

## Services

| Service | Description | Port |
|---------|-------------|------|
| webapp | React frontend (Nginx) | 80 |
| backend | FastAPI sonification API | 8000 |
| data-init | Initializes data volume | N/A (runs once) |

## Access Points

- **Webapp**: http://localhost
- **API Docs**: http://localhost:8000/docs
- **API Health**: http://localhost:8000/api/health

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ :80
┌─────────────────────────────────────────────────────────────┐
│  webapp (nginx)                                             │
│  ├── Serves React SPA                                       │
│  └── Proxies /api/* → backend:8000                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ :8000
┌─────────────────────────────────────────────────────────────┐
│  backend (FastAPI)                                          │
│  ├── /api/health - Health check                             │
│  ├── /api/datasets - List available datasets                │
│  ├── /api/compose - Generate sonification                   │
│  └── /api/cache/* - Serve generated audio/MIDI              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  jukebox-data (volume)                                      │
│  ├── *.npz - Intensity maps                                 │
│  └── *.json - Dataset metadata                              │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBAPP_VERSION` | latest | Version of the `webapp` image (Git tag without `v`) |
| `SONIFICATION_VERSION` | latest | Version of the `sonification` (backend) image |
| `DATASETS_VERSION` | latest | Version of the `datasets` image |
| `TAG` / `DATA_TAG` | - | Legacy fallbacks: `TAG` for webapp + sonification, `DATA_TAG` for datasets, used only when the variables above are unset |
| `WEBAPP_PORT` | 80 | Public port for webapp |
| `BACKEND_PORT` | 8000 | Port for backend API |
| `JUKEBOX_CORS` | * | CORS allowed origins |
| `DOMAIN` | (required in prod) | Domain served by Traefik: webapp on `DOMAIN`, `www.DOMAIN` redirects to it, API on `api.DOMAIN` |
| `ACME_EMAIL` | (required in prod) | Let's Encrypt account email |
| `TRAEFIK_VERSION` | v3.6 | Traefik image tag |
| `JUKEBOX_CORS_PROD` | `https://DOMAIN,https://www.DOMAIN` | Backend CORS origins in prod |

### Production Deployment

Production runs behind **Traefik** with automatic Let's Encrypt certificates:

| URL | Service |
|-----|---------|
| `https://DOMAIN` | webapp |
| `https://www.DOMAIN` | permanent redirect to `https://DOMAIN` |
| `https://api.DOMAIN` | backend API (e.g. `https://api.DOMAIN/api/health`) |

1. Point DNS records for `DOMAIN`, `www.DOMAIN` and `api.DOMAIN` at the server.
2. Open ports 80 and 443 (the certificate challenge runs on 443).
3. Set `DOMAIN` and `ACME_EMAIL` in `.env` (see `.env.example`).
4. Start:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Production differences:
- Traefik owns ports 80/443; webapp and backend publish no host ports
- HTTP redirects to HTTPS; certificates stored in `./data/letsencrypt/` (gitignored)
- Backend CORS restricted to `https://DOMAIN` and `https://www.DOMAIN`
- The webapp keeps calling `/api` on its own origin (nginx proxies it to the
  backend internally), so the GHCR image works on any domain without a rebuild
- Traefik dashboard is not exposed
- Resource limits (CPU/memory) and JSON file logging with rotation
- Requires Docker Compose v2.24+ (`!reset`)

### Small Server (data from a host folder)

The datasets image is a single 6.3 GB layer: pulling it needs about twice
that, and `data-init` then copies another 6.3 GB into the `jukebox-data`
volume (~19-23 GB in total). On a small server (e.g. 1 vCPU, 2 GB RAM,
20 GB disk) use `docker-compose.hostdata.yml` instead: the data is stored
once as plain files and mounted read-only into the backend and the webapp
(~11 GB in total). Measured at 1 CPU / 1.5 GB RAM: first-start data
preparation 53 s with a 911 MiB peak, one 30 s chunk with all six
instruments in ~1.7 s.

```bash
# Optional on 2 GB RAM: swap as a safety margin
sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Data: clone once, keep only data/ (fires_2002_2026 is used by neither
# the backend nor the globe, 580 MB)
git clone --depth 1 git@github.com:The-Earth-Information-Jukebox-HEIG-VD/datasets.git
mv datasets/data ~/jukebox-data && rm -rf datasets ~/jukebox-data/fires_2002_2026
```

In `.env`:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.prod.yml:docker-compose.hostdata.yml
JUKEBOX_DATA_PATH=/home/ubuntu/jukebox-data   # absolute path
WEBAPP_VERSION=1.1.0
SONIFICATION_VERSION=1.1.0
DOMAIN=example.com
ACME_EMAIL=admin@example.com
```

Then `docker compose pull` (no datasets image is pulled) and, once DNS points
at the server, `docker compose up -d --wait`. `DATASETS_VERSION` is unused
here: update the data by replacing the folder's contents and running
`docker compose restart backend`.

## Data Management

### Pre-populate Data Volume

```bash
# Initialize data before starting services
./scripts/init-data.sh

# Or with a specific version
./scripts/init-data.sh 1.1.0   # image tag: git tag without the "v"
```

### Update Data

Set the new `DATASETS_VERSION` in `.env` (e.g. `1.2.0`, no `v`) and run
`docker compose up -d` again. `data-init` compares a fingerprint of the image's
data with the one stored in the volume (`/data/.initialized`); when they differ
it empties the volume and copies the new data. The backend then rebuilds only
the datasets that changed in its cache.

To force a full re-copy anyway:

```bash
docker compose down
docker volume rm jukebox-data
docker compose up -d
```

### Use Local Data (Development)

1. Place data files in `./data/`
2. Uncomment volume mount in `docker-compose.override.yml`
3. Restart services

## Troubleshooting

### Services won't start

```bash
# Check container logs
docker compose logs backend
docker compose logs webapp

# Verify data volume
docker volume inspect jukebox-data
```

### Data not loading

```bash
# Check data-init completed
docker compose ps data-init

# Manually inspect volume
docker run --rm -v jukebox-data:/data alpine ls -la /data
```

### API not responding

```bash
# Check backend health
curl http://localhost:8000/api/health

# Check nginx proxy
curl -v http://localhost/api/health
```

## Image Repositories

| Image | Registry |
|-------|----------|
| webapp | ghcr.io/the-earth-information-jukebox-heig-vd/webapp |
| backend (sonification) | ghcr.io/the-earth-information-jukebox-heig-vd/sonification |
| datasets | ghcr.io/the-earth-information-jukebox-heig-vd/datasets |

## License

Part of the NASA Space Apps Challenge 2026 project.
