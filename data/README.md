# Data Directory

This directory is a placeholder for local development data.

In production, data is provided by the `datasets` Docker image and stored in Docker volumes.

## Local Development with Custom Data

To use local data files instead of the Docker image:

1. Place your `.npy`, `.npz`, and `.json` files in this directory
2. Uncomment the volume mount in `docker-compose.override.yml`:
   ```yaml
   services:
     backend:
       volumes:
         - ./data:/app/data:ro
   ```
3. Restart the services: `docker compose up -d`

## Data Format

The backend expects:
- `*_<variable>.npz` - NumPy compressed arrays with intensity maps
- `*.json` - Metadata files describing time axes and variable mappings

See the `datasets` repository for data processing scripts.
