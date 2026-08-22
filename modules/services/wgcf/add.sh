#!/usr/bin/env bash
set -euo pipefail

# Policy-routing constants; must match modules/services/wgcf/default.nix.
TABLE=51820

_default_route=$(ip route show default | head -n1)
_wan=$(echo "$_default_route" | awk '/dev/ {print $5}')

if [ -z "$_wan" ]; then
  echo "Could not auto-detect WAN interface, falling back..."
  _wan=${WAN_INTERFACE:-eth0}
fi

if [ -n "${2:-}" ]; then
  echo 'Too many arguments'
  exit 3
fi

# Route LAN search domains natively and keep Tailscale resolving through its
# own resolver instead of leaking into the WARP tunnel.
configure_split_dns() {
  echo '>> Configuring Split DNS for local network and Tailscale'
  local _wan_domains _d
  _wan_domains=$(resolvectl domain "$_wan" 2>/dev/null | cut -d':' -f2 | xargs || true)
  if [ -n "$_wan_domains" ]; then
    local _wan_routing=()
    for _d in $_wan_domains; do
      if [[ "$_d" != ~* ]]; then
        _wan_routing+=("~$_d" "$_d")
      else
        _wan_routing+=("$_d")
      fi
    done
    sudo resolvectl domain "$_wan" "${_wan_routing[@]}" || true
  fi
  if ip link show tailscale0 >/dev/null 2>&1; then
    sudo resolvectl domain tailscale0 "~ts.net" "~100.100.in-addr.arpa" || true
    sudo resolvectl dns tailscale0 100.100.100.100 || true
  fi
}

# $@: NextDNS resolvers for the activated family.
apply_warp_dns() {
  configure_split_dns
  echo '>> Configuring DNS to use NextDNS over WARP'
  sudo resolvectl dnsovertls wg1 yes || true
  sudo resolvectl dns wg1 "$@"
  sudo resolvectl domain wg1 "~."
}

# Full-tunnel mode only adds a default route to the dedicated policy table;
# the main-table default stays owned by NetworkManager, so network switches
# cannot strand the endpoint host-route anymore.
if [ "${1:-}" == "-4" ]; then
  echo '>> Introduce and test default IPv4 route via WARP'
  sudo ip route add default dev wg1 table "$TABLE" 2>/dev/null || true
  sleep 1
  if ! ping -c3 -W2 1.1.1.1; then
    echo '>> Failed to ping cloudflare, reverting...'
    sudo ip route del default dev wg1 table "$TABLE" || true
    exit 2
  fi

  apply_warp_dns 45.90.28.0#8361b6.dns.nextdns.io 45.90.30.0#8361b6.dns.nextdns.io
elif [ "${1:-}" == "-6" ]; then
  echo '>> Introduce and test default IPv6 route via WARP'
  sudo ip -6 route add default dev wg1 table "$TABLE" 2>/dev/null || true
  sleep 1
  if ! ping -c3 -W2 2606:4700:4700::1111; then
    echo '>> Failed to ping cloudflare, reverting...'
    sudo ip -6 route del default dev wg1 table "$TABLE" || true
    exit 2
  fi

  apply_warp_dns 2a07:a8c0::83:61b6#8361b6.dns.nextdns.io 2a07:a8c1::83:61b6#8361b6.dns.nextdns.io
elif [ -n "${1:-}" ]; then
  # Per-site mode: device routes on wg1 are gateway-independent and survive
  # network switches; NetworkManager leaves wg1 (unmanaged) alone.
  dig +short +tls @1.1.1.1 "$1" | grep -v '\.$' |
    xargs -r -tI % \
      sudo ip route replace % dev wg1
fi

echo '>> Finished with success!'
