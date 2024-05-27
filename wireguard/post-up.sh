#!/bin/bash

IPT="/usr/sbin/iptables"
IPT6="/usr/sbin/ip6tables"
SYSCTL="/sbin/sysctl"

WG_DIR='/etc/wireguard'
ENV_FILE="${WG_DIR}/wg-env.sh"

set -e  # Exit immediately if a command exits with a non-zero status

# Function to handle errors
error_exit() {
    echo "Error on line $1"
    exit 1
}

# Trap errors and call error_exit function
trap 'error_exit $LINENO' ERR

# Check if iptables binary exists
if ! command -v $IPT &>/dev/null; then
    echo "Error: iptables not found. Please make sure it is installed."
    exit 1
fi

# Check if ip6tables binary exists
if ! command -v $IPT6 &>/dev/null; then
    echo "Error: ip6tables not found. Please make sure it is installed."
    exit 1
fi

# Check if sysctl binary exists
if ! command -v $SYSCTL &>/dev/null; then
    echo "Error: sysctl not found. Please make sure it is installed."
    exit 1
fi

# Source the environment file
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo ".env file not found!"
    exit 1
fi

SUB_NET="$WG_ADDR/24"
#SUB_NET_6=''

## IPv4 rules ##
# Enable NAT for WireGuard subnet
$IPT -t nat -I POSTROUTING 1 -s "$SUB_NET" -o "$IN_FACE" -j MASQUERADE

# Accept all incoming traffic on WireGuard interface
$IPT -I INPUT 1 -i "$WG_FACE" -j ACCEPT

# Allow forwarding traffic between internet and WireGuard interfaces
$IPT -I FORWARD 1 -i "$IN_FACE" -o "$WG_FACE" -j ACCEPT
$IPT -I FORWARD 1 -i "$WG_FACE" -o "$IN_FACE" -j ACCEPT

# Accept incoming UDP traffic on WireGuard port
$IPT -I INPUT 1 -i "$IN_FACE" -p udp --dport "$WG_PORT" -j ACCEPT

# Enable IPv4 forwarding
$SYSCTL -w net.ipv4.ip_forward=1


## IPv6 rules (Uncomment to enable) ##
## Enable NAT for WireGuard IPv6 subnet
#$IPT6 -t nat -I POSTROUTING 1 -s "$SUB_NET_6" -o "$IN_FACE" -j MASQUERADE

## Accept all incoming traffic on WireGuard interface
#$IPT6 -I INPUT 1 -i "$WG_FACE" -j ACCEPT

## Allow forwarding traffic between internet and WireGuard interfaces
#$IPT6 -I FORWARD 1 -i "$IN_FACE" -o "$WG_FACE" -j ACCEPT
#$IPT6 -I FORWARD 1 -i "$WG_FACE" -o "$IN_FACE" -j ACCEPT

# Enable IPv6 forwarding
#$SYSCTL -w net.ipv6.conf.all.forwarding=1

# Unset variables to avoid any unintended consequences
unset IPT IPT6 SYSCTL ENV_FILE SUB_NET IN_FACE WG_FACE WG_PORT SUB_NET_6

echo "All rules applied successfully."
