#!/usr/bin/env bash
set -euo pipefail

_default_route=$(ip route show default | head -n1)
_gateway=$(echo "$_default_route" | awk '/via/ {print $3}')
_wan=$(echo "$_default_route" | awk '/dev/ {print $5}')

if [ -z "$_gateway" ] || [ -z "$_wan" ]; then
  echo "Could not auto-detect default gateway or interface! Falling back..."
  _gateway=${GATEWAY_IP:-192.168.1.1}
  _wan=${WAN_INTERFACE:-eth0}
fi

_cf=$(dig +short engage.cloudflareclient.com | tail -1)

echo "CF: $_cf"

# make current wireguard connections permanent
echo '>> Ensuring connection to the VPNs'
sudo ip route replace "$_cf" via "$_gateway" dev "$_wan" || true

if [ -n "${2:-}" ]; then
  echo 'Too many arguments'
  exit 3
fi

# attempt
echo '>> Test connection to WARP'
sudo ip route replace 8.8.8.8 dev wg1
sleep 1
if ! ping -c 8 8.8.8.8; then
  echo '>> Failed to ping google, reverting...'
  sudo ip route del 8.8.8.8 dev wg1
  exit 1
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

if [ "${1:-}" == "-4" ]; then
  # make default through zero-trust
  echo '>> Introduce and test default IPv4 route via WARP'
  sudo ip route replace default dev wg1
  sleep 1
  if ! ping -c 8 1.1.1.1; then
    echo '>> Failed to ping cloudflare, reverting...'
    sudo ip route del default dev wg1
    sudo ip route del 8.8.8.8 dev wg1
    exit 2
  fi

  configure_split_dns

  echo '>> Configuring DNS to use NextDNS over WARP'
  sudo resolvectl dnsovertls wg1 yes || true
  sudo resolvectl dns wg1 45.90.28.0#8361b6.dns.nextdns.io 45.90.30.0#8361b6.dns.nextdns.io
  sudo resolvectl domain wg1 "~."
  sudo ip -4 route flush cache
elif [ "${1:-}" == "-6" ]; then
  echo '>> Introduce and test default IPv6 route via WARP'
  sudo ip -6 route replace default dev wg1
  sleep 1
  curl -6 'https://google.com'

  configure_split_dns

  echo '>> Configuring DNS to use NextDNS over WARP'
  sudo resolvectl dnsovertls wg1 yes || true
  sudo resolvectl dns wg1 2a07:a8c0::83:61b6#8361b6.dns.nextdns.io 2a07:a8c1::83:61b6#8361b6.dns.nextdns.io
  sudo resolvectl domain wg1 "~."
  sudo ip -6 route flush cache
elif [ -n "${1:-}" ]; then
  dig +short +tls @1.1.1.1 "$1" | grep -v '\.$' |
    xargs -tI % \
      sudo ip route replace % dev wg1
fi

echo '>> Finished with success!'
