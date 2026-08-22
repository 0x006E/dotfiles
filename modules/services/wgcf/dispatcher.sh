#!/usr/bin/env bash
# NetworkManager dispatcher hook: keeps WARP state intact across interface
# up / DHCP renew / connectivity changes.
#
# - Ensures the policy-routing rules exist (normally created by the
#   wireguard-wg1 postSetup; NM events can coincide with service restarts).
# - When full-tunnel mode is active (a default route lives in table 51820),
#   reapplies the per-link DNS configuration on wg1, which systemd-resolved
#   drops when links bounce.

set -euo pipefail

TABLE=51820

case "${2:-}" in
  up | dhcp4-change | connectivity-change) ;;
  *)
    exit 0
    ;;
esac

if ! ip link show wg1 >/dev/null 2>&1; then
  exit 0
fi

if ! ip rule show | grep -q '^32764:'; then
  ip rule add priority 32764 table main suppress_prefixlength 0
fi
if ! ip rule show | grep -q '^32765:'; then
  ip rule add priority 32765 not fwmark 0x20000 table "$TABLE"
fi
if ! ip -6 rule show | grep -q '^32764:'; then
  ip -6 rule add priority 32764 table main suppress_prefixlength 0
fi
if ! ip -6 rule show | grep -q '^32765:'; then
  ip -6 rule add priority 32765 not fwmark 0x20000 table "$TABLE"
fi

dns_servers=()
if ip route show table "$TABLE" | grep -q '^default'; then
  dns_servers+=(45.90.28.0#8361b6.dns.nextdns.io 45.90.30.0#8361b6.dns.nextdns.io)
fi
if ip -6 route show table "$TABLE" | grep -q '^default'; then
  dns_servers+=(2a07:a8c0::83:61b6#8361b6.dns.nextdns.io 2a07:a8c1::83:61b6#8361b6.dns.nextdns.io)
fi

if [ "${#dns_servers[@]}" -gt 0 ]; then
  resolvectl dnsovertls wg1 yes || true
  resolvectl dns wg1 "${dns_servers[@]}"
  resolvectl domain wg1 "~."
fi
