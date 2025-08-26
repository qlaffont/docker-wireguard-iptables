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

# Copy default configurations if they don't exist
if [ ! -f "/config/coredns/Corefile" ] && [ -f "/defaults/Corefile" ]; then
    log "Copying default CoreDNS configuration..."
    cp /defaults/Corefile /config/coredns/
fi

if [ ! -f "/config/wg0.conf" ] && [ -f "/defaults/server.conf" ]; then
    log "Copying default WireGuard server configuration..."
    cp /defaults/server.conf /config/wg0.conf
fi

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

# Start WireGuard if configuration exists
if [ -f "/config/wg0.conf" ]; then
    log "Starting WireGuard..."
    
    # Clean up existing WireGuard interface if it exists
    if ip link show wg0 >/dev/null 2>&1; then
        log "Cleaning up existing WireGuard interface..."
        wg-quick down wg0 2>/dev/null || true
        ip link del wg0 2>/dev/null || true
    fi
    
    wg-quick up /config/wg0.conf
    log "WireGuard started successfully"
    
    # Enable IP forwarding but let custom PostUp/PostDown rules handle iptables
    log "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    
    log "IP forwarding enabled - using your custom iptables rules from PostUp/PostDown"
else
    log "No WireGuard configuration found, skipping WireGuard service"
fi

log "Container startup completed successfully"

# Keep container running
log "WireGuard service running, keeping container alive..."
while true; do
    sleep 3600
done
