#!/bin/bash
#set -x  # enable for debugging

# ---------------------- VARIABLES ----------------------
V380_MAC='20:98:ED:63:18:39'
CONFIG_FILE='/home/jepes/motioneye/etc/motioneye/camera-1.conf'

# ---------------------- FUNCTIONS ----------------------
error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

log_info() {
    echo "[INFO] $1"
}

# ---------------------- MAIN SCRIPT ----------------------
# Ensure config file exists
[ -f "$CONFIG_FILE" ] || error_exit "Configuration file not found: $CONFIG_FILE"

# Extract IP from config
CURRENT_CONFIG_IP=$(grep -E '^netcam_url' "$CONFIG_FILE" \
                   | sed -nE 's|netcam_url rtsp://([^:/]+).*|\1|p')
[ -n "$CURRENT_CONFIG_IP" ] || error_exit "Failed to parse current IP from config"
log_info "Configured IP from config: $CURRENT_CONFIG_IP"

# Check for root privileges
[[ $EUID -ne 0 ]] && error_exit "Script must be run as root for network scan"

# Perform network scan to find camera's actual IP
log_info "Scanning network for camera MAC $V380_MAC..."
NMAP_OUT=$(nmap -Pn -p 554 --open 192.168.1.0/24 2>/dev/null)

# Parse scan results
ACTUAL_IP=""
CURRENT_SCAN_IP=""
while IFS= read -r line; do
    if [[ $line =~ ^Nmap\ scan\ report\ for\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        CURRENT_SCAN_IP="${BASH_REMATCH[1]}"
    elif [[ $line =~ MAC\ Address:\ ([0-9A-Fa-f:]{17}) ]]; then
        if [[ "${BASH_REMATCH[1]}" == "$V380_MAC" ]]; then
            ACTUAL_IP="$CURRENT_SCAN_IP"
            break
        fi
    fi
done <<< "$NMAP_OUT"

[ -n "$ACTUAL_IP" ] || error_exit "Could not find camera IP via nmap"
log_info "Detected actual camera IP: $ACTUAL_IP"

# Compare config IP vs actual IP
if [[ "$CURRENT_CONFIG_IP" == "$ACTUAL_IP" ]]; then
    log_info "Configured IP matches actual IP. No update needed."
    exit 0
fi

# Backup, update config, restart service
log_info "IP mismatch: updating config from $CURRENT_CONFIG_IP to $ACTUAL_IP"
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak" || error_exit "Backup failed"

sed -i -E "s|^(netcam_url rtsp://)[^:/]+|\1$ACTUAL_IP|" "$CONFIG_FILE" \
    || error_exit "Failed to update config"

log_info "Configuration updated successfully"

# Restart MotionEye
docker restart motioneye || error_exit "Failed to restart motioneye container"

log_info "Script completed. New IP is now $ACTUAL_IP"
exit 0
