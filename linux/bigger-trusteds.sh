#!/bin/bash

# Path to the certificate on the local machine
LOCAL_CONF_PATH="CAroot.crt"

# Path where certificates should be copied on the remote machines
REMOTE_CONF_PATH="/usr/local/share/ca-certificates/"

# Name of the certificate file on the remote machine
REMOTE_CERTIFICATE_NAME="CAroot.crt"

# SSH User
SSH_USER="root"

# Path to the file containing the list of IP addresses
HOSTS_FILE="hosts.txt"

# Read IP addresses into an array
mapfile -t HOSTS < "${HOSTS_FILE}"

# Check if the local certificate exists
if [ ! -f "$LOCAL_CONF_PATH" ]; then
    echo "Certificate file does not exist: $LOCAL_CONF_PATH"
    exit 1
fi

# Check if hosts.txt file exists
if [ ! -f "hosts.txt" ]; then
    echo "Hosts file does not exist: hosts.txt"
    exit 1
fi

# Read each line from hosts.txt
for HOST in "${HOSTS[@]}"; do
    # Ping the host to check if it is reachable
    if ! ping -c 1 -W 1 "$HOST" &> /dev/null; then
        echo "Host $HOST is not reachable."
        continue
    fi
    
    echo "Processing host: $HOST"

    # Copy the certificate to the remote host
    scp "$LOCAL_CONF_PATH" "${SSH_USER}@${HOST}:${REMOTE_CONF_PATH}"
    
    # Install the certificate on the remote host, update the certificate store
    ssh "${SSH_USER}@${HOST}" "update-ca-certificates"
    
    echo "Certificate installed on host: $host"
done

echo "All hosts processed."
