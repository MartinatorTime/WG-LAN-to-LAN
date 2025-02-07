#!/bin/bash

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Generate server keys if they don't exist
if [ ! -f /etc/wireguard/privatekey ]; then
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
  chmod 600 /etc/wireguard/privatekey
fi

# Server configuration
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/privatekey)
Address = ${VPN_SUBNET%/*}.1/24
ListenPort = ${SERVER_PORT}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

# Generate client configuration function
generate_client() {
  CLIENT_NAME=$1
  CLIENT_IP="${VPN_SUBNET%/*}.$((2 + $(ls /etc/wireguard/clients | wc -l)))"
  CLIENT_PRIVKEY=$(wg genkey)
  CLIENT_PUBKEY=$(echo ${CLIENT_PRIVKEY} | wg pubkey)

  # Add client to server config
  cat >> /etc/wireguard/wg0.conf <<EOF
[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = ${CLIENT_IP}/32, ${LAN_SUBNET}

EOF

  # Create client configuration
  cat > "/etc/wireguard/clients/${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = ${CLIENT_IP}/24
DNS = ${CLIENT_DNS}

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = ${SERVER_PUBLIC_IP:-$(curl -s ifconfig.me)}:${SERVER_PORT}
AllowedIPs = ${PEER_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
}

# Generate initial client configuration if none exist
if [ ! -f /etc/wireguard/clients/client1.conf ]; then
  generate_client "client1"
fi

# Start WireGuard
wg-quick up wg0

# Keep container running
tail -f /dev/null