#!/usr/bin/env bash
set -euo pipefail

# Policy-routing constant; must match modules/services/wgcf/default.nix.
TABLE=51820

if [ -n "${2:-}" ]; then
  echo 'Too many arguments'
  exit 3
fi

if [ -z "${1:-}" ]; then
  echo "Usage: cfwarp-rm [-4 | -6 | <hostname>]"
  exit 1
fi

# Full-tunnel mode lives entirely in the policy table, so removal is a single
# route delete; NetworkManager's main-table default was never touched and no
# restart is needed.
if [ "${1:-}" == "-4" ]; then
  echo '>> Removing default IPv4 route via WARP'
  sudo ip route del default dev wg1 table "$TABLE" || true
  echo '>> Reverting WARP DNS'
  sudo resolvectl revert wg1 || true
elif [ "${1:-}" == "-6" ]; then
  echo '>> Removing default IPv6 route via WARP'
  sudo ip -6 route del default dev wg1 table "$TABLE" || true
  echo '>> Reverting WARP DNS'
  sudo resolvectl revert wg1 || true
else
  dig +short +tls @1.1.1.1 "$1" | grep -v '\.$' |
    xargs -r -tI % \
      sudo ip route del % dev wg1 || true
fi

echo '>> Finished removing routes!'
