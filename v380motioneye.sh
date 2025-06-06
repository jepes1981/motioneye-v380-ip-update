#!/bin/bash

# ---------------------- VARIABLES ----------------------
V380_MAC='AA:BB:CC:DD:EE:FF'
CONFIG_FILE='<path to camera config in motioneye>/camera-1.conf'
PREVIOUS_IP_FILE='<your preferred path>/v380ip.txt'

# ---------------------- FUNCTIONS ----------------------

# Function to print error and exit
error_exit() {
    echo "[ERROR] $1"
    exit 1
}

# Function to print info messages
log_info() {
    echo "[INFO] $1"
}

# ---------------------- MAIN SCRIPT ----------------------

# Check if previous IP file exists
if [ ! -f "$PREVIOUS_IP_FILE" ]; then
    error_exit "Previous IP file not found: $PREVIOUS_IP_FILE"
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "Camera config file not found: $CONFIG_FILE"
fi

# Extract current netcam_url IP
CURRENT_CONFIG_IP=$(grep "^netcam_url" "$CONFIG_FILE" | sed -nE 's|netcam_url rtsp://([^/]+)/|\1|p')
PREVIOUS_IP=$(cat "$PREVIOUS_IP_FILE" | tr -d ' \n')

log_info "Configured IP from config file: $CURRENT_CONFIG_IP"
log_info "Previous IP from file: $PREVIOUS_IP"

# Compare IPs
if [ "$CURRENT_CONFIG_IP" == "$PREVIOUS_IP" ]; then
    log_info "All is well. IPs match."
    exit 0
fi

# Check for root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root."
fi

log_info "Running as root. Proceeding with nmap scan..."

# Scan the network for RTSP (port 554)
NMAP_OUTPUT=$(nmap -oN - -p 554 --open 192.168.1.1/24 2>/dev/null)

log_info "Nmap scan completed. Searching for MAC: $V380_MAC"

# Extract the IP corresponding to the MAC
V380_NEW_IP=""
current_ip=""

while IFS= read -r line; do
    if [[ $line =~ ^Nmap\ scan\ report\ for\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
        current_ip="${BASH_REMATCH[1]}"
    elif [[ $line =~ MAC\ Address:\ ([0-9A-Fa-f:]{17}) ]]; then
        mac="${BASH_REMATCH[1]}"
        if [[ "$mac" == "$V380_MAC" ]]; then
            V380_NEW_IP="$current_ip"
            break
        fi
    fi
done <<< "$NMAP_OUTPUT"

# Check if IP was found
if [ -z "$V380_NEW_IP" ]; then
    error_exit "V380 camera IP for MAC $V380_MAC not found in network scan."
fi

log_info "Found new IP for V380 camera: $V380_NEW_IP"
log_info "Updating netcam_url in config file..."

# Backup original config
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Update netcam_url line
sed -i -E "s|^(netcam_url rtsp://)[^/]+/|\1$V380_NEW_IP/|" "$CONFIG_FILE"

# Save new IP to previous IP file
echo "$V380_NEW_IP" > "$PREVIOUS_IP_FILE"

log_info "Configuration updated successfully. New IP: $V380_NEW_IP"

#restart motioneye docker
docker restart motioneye
if [ $? -ne 0 ]; then
  echo "Error restarting motioneye docker."
  exit 1
fi

exit 0
