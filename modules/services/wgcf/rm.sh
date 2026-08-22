#!/usr/bin/env bash
set -euo pipefail

if [ -n "${2:-}" ]; then
  echo 'Too many arguments'
  exit 3
fi

if [ -z "${1:-}" ]; then
  echo "Usage: cfwarp-rm [-4 | -6 | <hostname>]"
  exit 1
fi

if [ "${1:-}" == "-4" ]; then
  echo '>> Removing default IPv4 route via WARP'
  sudo ip route del default dev wg1 || true
  sudo ip route del 8.8.8.8 dev wg1 || true
  echo '>> Reverting WARP DNS'
  sudo resolvectl revert wg1 || true
  echo '>> Restarting NetworkManager to restore default route'
  sudo systemctl restart NetworkManager
  sudo ip -4 route flush cache
elif [ "${1:-}" == "-6" ]; then
  echo '>> Removing default IPv6 route via WARP'
  sudo ip -6 route del default dev wg1 || true
  echo '>> Reverting WARP DNS'
  sudo resolvectl revert wg1 || true
  echo '>> Restarting NetworkManager to restore default route'
  sudo systemctl restart NetworkManager
  sudo ip -6 route flush cache
else
  dig +short +tls @1.1.1.1 "$1" | grep -v '\.$' |
    xargs -tI % \
      sudo ip route del % dev wg1 || true
fi

echo '>> Finished removing routes!'
