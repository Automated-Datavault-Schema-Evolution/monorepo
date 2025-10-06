#!/usr/bin/env bash
set -euo pipefail

NETWORK="data_automation-net"
VOLUMES=(
  grafana-data
  prometheus-data
  loki-data
  uptime-kuma-data
  marquez-db
  delta-jars
  ext-jars
  jdbc-driver
)

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found" >&2
  exit 1
fi

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "Creating docker network: $NETWORK"
  docker network create "$NETWORK"
else
  echo "Docker network already exists: $NETWORK"
fi

for volume in "${VOLUMES[@]}"; do
  if docker volume inspect "$volume" >/dev/null 2>&1; then
    echo "Volume already exists: $volume"
  else
    echo "Creating volume: $volume"
    docker volume create "$volume" >/dev/null
  fi

done

echo "Control plane prerequisites created."