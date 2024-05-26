#!/bin/bash

copyToWireguard() {
    # Copy files to /etc/wireguard
    sudo cp ./wireguard/*.sh /etc/wireguard/

    # Change permissions and ownership
    sudo chmod 600 /etc/wireguard/*.sh
    sudo chown root:root /etc/wireguard/*.sh

    # Make all files executable
    sudo chmod +x /etc/wireguard/*.sh
}

main() {
    # Install packages
    sudo apt install wireguard-tools resolvconf net-tools -y

    # Copy all files to /etc/wireguard and make them executable
    copyToWireguard

    # Run script to create interface from /etc/wireguard directory
    cd /etc/wireguard || exit
    sudo ./create-interface.sh
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 2
else
    main
    exit 0
fi
