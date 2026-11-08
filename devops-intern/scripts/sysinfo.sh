#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'System Information'
printf 'User: %s\n' "$(id -un)"
printf 'Effective UID: %s\n' "$(id -u)"
printf 'Hostname: %s\n' "$(hostname)"
printf 'Kernel: %s\n' "$(uname -r)"
printf 'Date: %s\n' "$(date -Iseconds)"

printf '\nDisk usage:\n'
df -h

printf '\nMemory usage:\n'
if command -v free >/dev/null 2>&1; then
  free -h
elif [ -r /proc/meminfo ]; then
  awk '/^(MemTotal|MemAvailable):/ { print }' /proc/meminfo
else
  printf '%s\n' 'Memory usage is unavailable on this host.'
fi

printf '\nDocker daemon:\n'
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    printf '%s\n' 'running'
  else
    printf '%s\n' 'not running or not accessible to this user'
  fi
else
  printf '%s\n' 'Docker is not installed'
fi
