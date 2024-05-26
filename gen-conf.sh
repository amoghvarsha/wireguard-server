#!/bin/bash

EXIT_CODE=0
VERBOSE_FLAG=0

WG_DIR="/etc/wireguard"
ENV_FILE="${WG_DIR}/wg-env.sh"

WG_PEER=""
WG_PEER_DIR=""
WG_PEER_ID=""
WG_PEER_SUBNET="32"
WG_PEER_KEY=""
WG_PEER_PSK=""
WG_PEER_PUB=""
WG_PEER_CONF_FILE=""
WG_PEER_TAR_FILE=""
WG_PEER_PERSISTENT_KEEPALIVE=20

Echo() {
    if [ $VERBOSE_FLAG -eq 1 ]; then
        echo "$1"
    fi
}

Help() {
    echo
    echo "Create WireGuard Conf"
    echo
    echo "Syntax: wg-gen-conf [ -h | -v ] [ -p <VAL> | -i <VAL> | -k <VAL> ]"
    echo "options:"
    echo " -h  Print Help"
    echo " -v  Verbose Mode"
    echo " -p  Peer Name"
    echo " -i  Peer ID"
    echo
}

AddPeerToNetwork() {
    wg  set "${WG_FACE}" \
        peer "${WG_PEER_PUB}" \
        preshared-key "${WG_PEER_DIR}/wg-${WG_PEER}.psk" \
        persistent-keepalive "${WG_PEER_PERSISTENT_KEEPALIVE}" \
        allowed-ips "${WG_ADDR%.*}.${WG_PEER_ID}/${WG_PEER_SUBNET}"
}

GenConfFile() {
    rm -f "${WG_PEER_CONF_FILE}"
    touch "${WG_PEER_CONF_FILE}"

    {
        printf "[Interface]\n"
        printf "PrivateKey = %s\n" "${WG_PEER_KEY}"
        printf "Address = %s.%s/%s\n" "${WG_ADDR%.*}" "${WG_PEER_ID}" "${WG_PEER_SUBNET}"
        printf "DNS = 9.9.9.9\n"
        printf "\n"
        printf "[Peer]\n"
        printf "PublicKey = %s\n" "${WG_SERVER_PUB}"
        printf "PresharedKey = %s\n" "${WG_PEER_PSK}"
        printf "AllowedIPs = 0.0.0.0/0\n"
        printf "Endpoint = %s:%s\n" "${WG_DOMAIN}" "${WG_PORT}"
        printf "PersistentKeepalive = %s\n" "${WG_PEER_PERSISTENT_KEEPALIVE}"
    } >> "${WG_PEER_CONF_FILE}"
}

GenKeys() {
    local UMASK
    UMASK=$(umask)
    umask u=rw,g=,o=

    wg genkey | tee "wg-${WG_PEER}.key" | wg pubkey > "wg-${WG_PEER}.pub"
    wg genpsk > "wg-${WG_PEER}.psk"

    WG_PEER_KEY=$(<wg-${WG_PEER}.key)
    WG_PEER_PSK=$(<wg-${WG_PEER}.psk)
    WG_PEER_PUB=$(<wg-${WG_PEER}.pub)

    umask "$UMASK"
}

main() {
    if [ $# -eq 0 ]; then
        Help
        exit 0
    else
        while getopts ":hvp:i:" OPTION; do
            case $OPTION in
                h) # Help Option
                    Help
                    exit 0
                    ;;
                v) # Verbose Mode Option
                    VERBOSE_FLAG=1
                    ;;
                p)
                    WG_PEER=$OPTARG
                    ;;
                i)
                    WG_PEER_ID=$OPTARG
                    ;;
                \?) # Invalid Option
                    echo "Error: Invalid option"
                    exit 11
                    ;;
                :)  # No argument
                    echo "Option -$OPTARG requires an argument"
                    exit 12
                    ;;
            esac
        done

        if [ -z "$WG_PEER" ] || [ -z "$WG_PEER_ID" ]; then
            echo "Peer Name and/or Peer ID not provided"
            exit 10
        else
            WG_PEER_DIR="$WG_DIR/peers.d/$WG_PEER"

            WG_PEER_CONF_FILE="$WG_PEER_DIR/wg-$WG_PEER.conf"
            WG_PEER_TAR_FILE="$WG_PEER_DIR/wg-$WG_PEER.tar"

            mkdir -p "$WG_PEER_DIR" && cd "$WG_PEER_DIR"

            Echo "Generating WireGuard Keys File for Peer: '$WG_PEER'"
            logger -p notice -t WG-GEN-CONF "Generating WireGuard Keys File for Peer: '$WG_PEER'"
            GenKeys

            Echo "Generating WireGuard Conf File for Peer: '$WG_PEER'"
            logger -p notice -t WG-GEN-CONF "Generating WireGuard Conf File for Peer: '$WG_PEER'"
            GenConfFile

            echo "Apply Configuration To Wireguard"
            AddPeerToNetwork
            systemctl restart wg-quick@wg-server.service

            wg show

            exit $EXIT_CODE
        fi
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 2
else
    if [ -f "${ENV_FILE}" ]; then
        source "${ENV_FILE}"
    else
        echo "Environment file ${ENV_FILE} not found."
        exit 3
    fi

    main "$@"
    exit 0
fi
