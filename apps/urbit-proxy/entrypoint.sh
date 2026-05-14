#!/usr/bin/env sh
set -eu

KEY_FILE="/data/wg-private.key"
IP_FILE="/data/wg-ip"

if [ ! -f "$KEY_FILE" ]; then
  wg genkey > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
fi

if [ -f "$IP_FILE" ]; then
  WG_IP="$(cat "$IP_FILE")"
elif [ -n "${WG_IP:-}" ]; then
  echo "$WG_IP" > "$IP_FILE"
else
  echo "ERROR: WG_IP not set and $IP_FILE not found" >&2
  exit 1
fi

echo "WIREGUARD_PUBKEY=$(wg pubkey < "$KEY_FILE")"

WG_PRIVATE_KEY="$(cat "$KEY_FILE")"
sed \
  -e "s|WG_IP_PLACEHOLDER|${WG_IP}|g" \
  -e "s|WG_PRIVATE_KEY_PLACEHOLDER|${WG_PRIVATE_KEY}|g" \
  /etc/wireguard/wg0.conf.template > /etc/wireguard/wg0.conf

chmod 600 /etc/wireguard/wg0.conf
wg-quick up wg0

exec ./ssh-server
