# Use Alpine Linux as base image
FROM alpine:latest

# Install WireGuard and dependencies
RUN apk add --no-cache wireguard-tools iptables bash

# Create directories for WireGuard configuration
RUN mkdir -p /etc/wireguard/clients

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Set permissions
RUN chmod +x /entrypoint.sh

# Environment variables
ENV SERVER_PORT=51820
ENV VPN_SUBNET=10.8.0.0/24
ENV CLIENT_DNS=1.1.1.1
ENV PEER_ALLOWED_IPS="0.0.0.0/0, ::/0"
ENV LAN_SUBNET=192.168.1.0/24

# Expose WireGuard port
EXPOSE ${SERVER_PORT}/udp

# Persist WireGuard config
VOLUME [ "/etc/wireguard" ]

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]