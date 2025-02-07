#!/bin/bash
set -e

# --- Configuration Variables ---
# You may override these by passing environment variables when running the container.
# SERVER_PORT: UDP port that WireGuard will listen on (default: 51820)
# SERVER_VPN_IP: The WireGuard IP for the server (with subnet, e.g. 10.0.0.1/24)
# CLIENT_VPN_IP: The WireGuard IP for the client (usually a /32, e.g. 10.0.0.2/32)
# CLIENT_LAN: (Optional) The client’s LAN network that should be routed via the VPN (default: 192.168.1.0/24)
# SERVER_ENDPOINT: The public IP or DNS name of your server – used in the client config
SERVER_PORT=${SERVER_PORT:-51820}
SERVER_VPN_IP=${SERVER_VPN_IP:-10.0.0.1/24}
CLIENT_VPN_IP=${CLIENT_VPN_IP:-10.0.0.2/32}
CLIENT_LAN=${CLIENT_LAN:-192.168.1.0/24}
SERVER_ENDPOINT=${SERVER_ENDPOINT:-"your.server.domain"}  # <-- Replace or override at runtime!

WG_INTERFACE="wg0"
WG_CONFIG="/etc/wireguard/${WG_INTERFACE}.conf"
CLIENT_CONFIG="/client.conf"

echo "Starting auto‑configuration for WireGuard..."
echo "  Server VPN IP: ${SERVER_VPN_IP}"
echo "  Client VPN IP: ${CLIENT_VPN_IP}"
echo "  Listening on UDP port: ${SERVER_PORT}"
echo "  Server endpoint (for client config): ${SERVER_ENDPOINT}"
echo "  Client LAN (routed via VPN): ${CLIENT_LAN}"

# --- Generate Keys (if not already present) ---
umask 077

if [ ! -f /etc/wireguard/server_private.key ]; then
    echo "Generating server keypair..."
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
fi

if [ ! -f /etc/wireguard/client_private.key ]; then
    echo "Generating client keypair..."
    wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
fi

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIVATE_KEY=$(cat /etc/wireguard/client_private.key)
CLIENT_PUBLIC_KEY=$(cat /etc/wireguard/client_public.key)

# --- Create WireGuard Server Configuration ---
cat > ${WG_CONFIG} <<EOF
[Interface]
Address = ${SERVER_VPN_IP}
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}
# Enable forwarding and NAT (adjust interface "eth0" if needed)
PostUp = iptables -A FORWARD -i %i -o %i -j ACCEPT; \
         iptables -A FORWARD -i %i -o eth0 -j ACCEPT; \
         iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -o %i -j ACCEPT; \
           iptables -D FORWARD -i %i -o eth0 -j ACCEPT; \
           iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# Client configuration
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_VPN_IP}, ${CLIENT_LAN}
EOF

echo "Server configuration written to ${WG_CONFIG}"

# --- Create WireGuard Client Configuration ---
cat > ${CLIENT_CONFIG} <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_VPN_IP}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_ENDPOINT}:${SERVER_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "Client configuration written to ${CLIENT_CONFIG}"
echo "==> You can download the client configuration from the container (e.g., via 'docker cp')"

# --- Bring Up the WireGuard Interface ---
echo "Starting WireGuard interface '${WG_INTERFACE}'..."
wg-quick up ${WG_INTERFACE}

# --- Keep the Container Running ---
echo "WireGuard is running. Tail logs to keep the container alive."
tail -f /dev/null
