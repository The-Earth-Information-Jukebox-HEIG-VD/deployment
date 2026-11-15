# Data Directory

This directory is a placeholder for local development data.

In production, data is provided by the `datasets` Docker image: the `data-init`
service copies it into the `jukebox-data` volume, which is mounted read-only by
the backend (`/app/data`) and by the webapp (`/usr/share/nginx/data`, served at
`/data/`).

On a small server, `docker-compose.hostdata.yml` replaces the image and the
volume with a host folder: set `JUKEBOX_DATA_PATH` (absolute path) in `.env`
and that folder is mounted read-only at the same two places. Total size of the
12 folders: 9.1 GB (`du -sh`).

The backend converts these folders on first start into its own `.npz` + `.json`
files in the `jukebox-cache` volume (`_datasets/`); the data folder itself is
never written.

## Volume layout (repository `datasets`)

One folder per dataset, one `.npy` per month (per year for night lights):

```
temperature_anomaly_1880_2025/temperature_anomaly_YYYY_MM.npy   °C anomaly   float16
co2_2002_2022/co2_YYYY_MM.npy                                   ppm          float32
lightning_2017_2023/lightning_YYYY_MM.npy                       0-1          float16
precipitation_rain_2000_2026/rain_YYYY_MM.npy                   mm/h         float16
precipitation_snow_2000_2026/snow_YYYY_MM.npy                   mm/h         float16
fires_2002_2026/fires_YYYY_MM.npy                               -            float16
nightlights_2012_2023/nightlights_YYYY.npy                      -            float32
sea_ice_1979_2026/sea_ice_YYYY_MM.npy                           %            float16
vegetation_ndvi_2000_2026/ndvi_YYYY_MM.npy                      NDVI         float16
carbon_monoxide_2000_2024/co_YYYY_MM.npy                        1e18 molec/cm2 float16
chlorophyll_2002_2026/chlorophyll_YYYY_MM.npy                   mg/m3        float16
rain_belt_2000_2026/rain_belt_YYYY_MM.npy                       mm/h         float32 (720 values, not used)
```

The first 11 folders feed the 11 instruments; the rain belt is not used by the
backend. Except the rain belt (one value per latitude row), every file is a 720 x 1440 grid of 0.25° pixels (row 0 = 90°N, column 0 = 180°W),
NaN = no data. The same `[row, column]` is the same place in every dataset.

## How the webapp uses it

While the music plays, the globe shows the stored values of the selected zone,
one color per dataset (`webapp/src/data/datasetRegistry.ts`). The browser:

1. lists the folders and months via `GET /data/` and `GET /data/<folder>/`
   (nginx `autoindex_format json`);
2. downloads only the rows covering the zone with HTTP `Range` requests on the
   uncompressed `.npy` files.

A new folder following the `<prefix>_YYYY_MM.npy` pattern is picked up
automatically (fallback color; add it to the registry for units and a label).

## Local development

- **Webapp (`npm run dev`)**: the Vite dev server serves `../datasets/data`
  at `/data/` (same JSON listing + Range support as nginx). Use another folder
  with `JUKEBOX_DATA_DIR=/path/to/data npm run dev`.
- **Docker with local files**: uncomment the bind mount in
  `docker-compose.override.yml` (backend) and add the same for the webapp:
  ```yaml
  services:
    webapp:
      volumes:
        - ../datasets/data:/usr/share/nginx/data:ro
  ```
  then `docker compose up -d`.

> AI assistance: Google Gemini and Anthropic Claude helped with research, data analysis, coding and debugging, and writing for the data volume setup. See [AI assistance](../README.md#ai-assistance).
