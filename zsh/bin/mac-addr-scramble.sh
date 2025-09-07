#!/usr/bin/env bash

set -e

# Generate new MAC Address
NEW_ADDRESS=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g;s/.$//')
INTERFACE=${1:-wlp1s0}

echo "Backing up old mac address for ${INTERFACE} >> /tmp/${INTERFACE}.mac..."
sudo ip link show dev ${INTERFACE} > /tmp/${INTERFACE}.mac

# Update MAC Address (requires sudo permissions)
echo "Setting new mac address to ${NEW_ADDRESS}..."
sudo ip link set dev ${INTERFACE} address ${NEW_ADDRESS}

echo "MAC Address successfully changed!"
sudo ip link show dev ${INTERFACE}
