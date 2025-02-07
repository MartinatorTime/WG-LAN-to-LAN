#!/bin/bash

# Create directory structure if missing
mkdir -p /etc/wireguard/clients

# Enable IP forwarding at kernel level
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Generate server keys if missing
if [ ! -f /etc/wireguard/privatekey ]; then
  umask 077
  wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
fi

# Get public IP if not set
if [ -z "$SERVER_PUBLIC_IP" ]; then
  SERVER_PUBLIC_IP=$(curl -4 -s ifconfig.co)
fi

# Server configuration
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/privatekey)
Address = ${VPN_SUBNET%/*}.1/24
ListenPort = ${SERVER_PORT}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

# Client generation function
generate_client() {
  CLIENT_NAME=$1
  CLIENT_IP="${VPN_SUBNET%/*}.$((2 + $(ls /etc/wireguard/clients | wc -l)))"
  CLIENT_PRIVKEY=$(wg genkey | tee /etc/wireguard/clients/${CLIENT_NAME}.key)
  CLIENT_PUBKEY=$(echo ${CLIENT_PRIVKEY} | wg pubkey)

  cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = ${CLIENT_PUBKEY}
AllowedIPs = ${CLIENT_IP}/32, ${LAN_SUBNET}
EOF

  cat > "/etc/wireguard/clients/${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVKEY}
Address = ${CLIENT_IP}/24
DNS = ${CLIENT_DNS}

[Peer]
PublicKey = $(cat /etc/wireguard/publickey)
Endpoint = ${SERVER_PUBLIC_IP}:${SERVER_PORT}
AllowedIPs = ${PEER_ALLOWED_IPS}
PersistentKeepalive = 25
EOF
}

# Generate initial client if none exist
if [ ! -f /etc/wireguard/clients/client1.conf ]; then
  generate_client "client1"
fi

# Start WireGuard with clean interface
wg-quick down wg0 2>/dev/null
wg-quick up wg0

# Keep container running
tail -f /dev/null