#!/bin/bash

set -e

echo "**** Starting WireGuard Docker container... ****"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Initialize basic configuration
log "Initializing basic configuration..."
mkdir -p /config/{templates,coredns}
mkdir -p /etc/wireguard
chmod 755 /config
chmod 755 /etc/wireguard

# Check for wireguard module
log "Checking WireGuard module..."
ip link del dev test 2>/dev/null || true
if ip link add dev test type wireguard; then
    log "WireGuard module is already active"
    ip link del dev test
    if capsh --current | grep "Current:" | grep -q "cap_sys_module"; then
        log "You can remove the SYS_MODULE capability from your container run/compose"
        log "If your host doesn't automatically load iptables, you may still need SYS_MODULE"
    fi
else
    log "ERROR: WireGuard module is not active"
    log "If you believe your kernel should have WireGuard support, make sure it's activated via modprobe"
    log "If you have an old kernel without WireGuard support, try using the 'legacy' tag for this image"
    exit 1
fi

# Start CoreDNS if configuration exists
if [ -f "/config/coredns/Corefile" ]; then
    log "Starting CoreDNS..."
    /usr/sbin/coredns -conf /config/coredns/Corefile &
    COREDNS_PID=$!
    log "CoreDNS started with PID: $COREDNS_PID"
else
    log "No CoreDNS configuration found, skipping DNS service"
fi

# Start WireGuard if configuration exists
if [ -f "/config/wg0.conf" ]; then
    log "Starting WireGuard..."
    wg-quick up /config/wg0.conf
    log "WireGuard started successfully"
else
    log "No WireGuard configuration found, skipping WireGuard service"
fi

log "Container startup completed successfully"

# Keep container running
if [ -n "$COREDNS_PID" ]; then
    # Wait for CoreDNS if it's running
    wait $COREDNS_PID
else
    # Keep container alive
    tail -f /dev/null
fi
