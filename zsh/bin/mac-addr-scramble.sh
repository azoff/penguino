#!/usr/bin/env bash

# Generate new MAC Address
NEW_ADDRESS=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g;s/.$//')

# Update MAC Address (requires sudo permissions)
sudo ifconfig en0 ether $NEW_ADDRESS

echo "MAC Address successfully changed!"

echo "Your new MAC Address is..."
sudo ifconfig en0 | grep ether
