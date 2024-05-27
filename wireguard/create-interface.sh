#!/bin/bash

WG_DIR='/etc/wireguard'
ENV_FILE="${WG_DIR}/wg-env.sh"

WG_SERVER_KEY=''
WG_SERVER_PUB=''

# Source the environment file
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo ".env file not found!"
    exit 1
fi

updateEnvFile() {

    local var_name="$1"
    local var_value="$2"

    # Check if the variable already exists in the file
    if grep -q "^${var_name}='" "${ENV_FILE}"; then
        # Update existing variable
        sudo sed -i "s|^${var_name}='.*'|${var_name}='${var_value}'|" "${ENV_FILE}"
    else
        # Append new variable
        sudo sed -i "\$a${var_name}='${var_value}'" "${ENV_FILE}"
    fi

}

createInterface() {

    sudo cat > /etc/wireguard/"${WG_FACE}".conf <<EOF
[Interface]
Address = ${WG_ADDR}/24
ListenPort = ${WG_PORT}
PrivateKey = ${WG_SERVER_KEY}
SaveConfig = true

PostUp = /etc/wireguard/post-up.sh
PreDown = /etc/wireguard/pre-down.sh

EOF

}

generateKey() {

    WG_SERVER_KEY="$(wg genkey | sudo tee /etc/wireguard/"${WG_FACE}".key)"

    sudo chmod go= /etc/wireguard/"${WG_FACE}".key

    WG_SERVER_PUB="$(sudo cat /etc/wireguard/"${WG_FACE}".key | wg pubkey | sudo tee /etc/wireguard/"${WG_FACE}".pub)"

}

main() {

    generateKey

    createInterface

    # Register it as a systemd service and start
    sudo systemctl enable wg-quick@${WG_FACE}.service
    sudo systemctl start  wg-quick@${WG_FACE}.service

    # Update or append variables to the environment file
    updateEnvFile 'WG_SERVER_KEY' "${WG_SERVER_KEY}"
    updateEnvFile 'WG_SERVER_PUB' "${WG_SERVER_PUB}"

}

if [ "$EUID" -ne 0 ]
then
    echo "Please run as root"
    exit 2
else
    main
    exit 0
fi
