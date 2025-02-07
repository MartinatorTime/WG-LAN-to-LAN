# Use an official Ubuntu base image
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install WireGuard and required tools
RUN apt-get update && \
    apt-get install -y wireguard iproute2 iptables curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create WireGuard configuration directory
RUN mkdir -p /etc/wireguard && chmod 700 /etc/wireguard

# Copy the entrypoint script into the image
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose the WireGuard UDP port (default 51820)
EXPOSE 51820/udp

# Run the entrypoint script on container start
ENTRYPOINT ["/entrypoint.sh"]
