FROM alpine:latest

# Install dependencies with cache cleanup
RUN apk add --no-cache wireguard-tools iptables bash curl jq && \
    rm -rf /var/cache/apk/*

# Create necessary directories
RUN mkdir -p /etc/wireguard/clients && \
    mkdir -p /var/run/wireguard

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

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]