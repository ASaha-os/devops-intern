#!/usr/bin/env bash
set -euo pipefail

target_url="${1:-http://localhost:8080}"

if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' 'healthcheck: curl is required but was not found' >&2
  exit 127
fi

if ! status_code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 5 "$target_url")"; then
  printf 'healthcheck: request failed for %s\n' "$target_url" >&2
  exit 1
fi

if [ "$status_code" != '200' ]; then
  printf 'healthcheck: expected HTTP 200 from %s, received %s\n' "$target_url" "$status_code" >&2
  exit 1
fi

printf 'healthcheck: %s returned HTTP 200\n' "$target_url"
