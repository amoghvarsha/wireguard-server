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

# IPv4 rules #
# Delete NAT for WireGuard subnet
$IPT -t nat -D POSTROUTING -s "$SUB_NET" -o "$IN_FACE" -j MASQUERADE

# Delete all incoming traffic on WireGuard interface
$IPT -D INPUT -i "$WG_FACE" -j ACCEPT

# Delete forwarding traffic between internet and WireGuard interfaces
$IPT -D FORWARD -i "$IN_FACE" -o "$WG_FACE" -j ACCEPT
$IPT -D FORWARD -i "$WG_FACE" -o "$IN_FACE" -j ACCEPT

# Delete incoming UDP traffic on WireGuard port
$IPT -D INPUT -i "$IN_FACE" -p udp --dport "$WG_PORT" -j ACCEPT

# Disable IPv4 forwarding
$SYSCTL -w net.ipv4.ip_forward=0


# IPv6 rules (uncomment if needed) #
## Delete NAT for WireGuard IPv6 subnet
## $IPT6 -t nat -D POSTROUTING -s $SUB_NET_6 -o $IN_FACE -j MASQUERADE

## Delete all incoming traffic on WireGuard interface
## $IPT6 -D INPUT -i $WG_FACE -j ACCEPT

## Delete forwarding traffic between internet and WireGuard interfaces
## $IPT6 -D FORWARD -i $IN_FACE -o $WG_FACE -j ACCEPT
## $IPT6 -D FORWARD -i $WG_FACE -o $IN_FACE -j ACCEPT

# Disable IPv6 forwarding
#$SYSCTL -w net.ipv6.conf.all.forwarding=0

# Unset variables
unset IPT IPT6 SYSCTL ENV_FILE SUB_NET IN_FACE WG_FACE WG_PORT

echo "All rules removed successfully."
