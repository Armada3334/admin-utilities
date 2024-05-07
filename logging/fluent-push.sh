#!/bin/bash

# Path to the file containing the list of IP addresses
HOSTS_FILE="hosts.txt"

# Read IP addresses into an array
mapfile -t HOSTS < "${HOSTS_FILE}"

# Path to the local fluent-bit.conf file
LOCAL_CONF_PATH="./fluent-bit.conf"
LOCAL_CONF_PATH2="./parsers.conf"

# Remote path where the fluent-bit.conf should be replaced
REMOTE_CONF_PATH="/etc/fluent-bit/fluent-bit.conf"
REMOTE_CONF_PATH2="/etc/fluent-bit/parsers.conf"

# SSH User
SSH_USER="root" # or "admin", depending on your setup

# Function to check and install Fluent Bit if not installed
install_fluent_bit_if_needed() {
    local host=$1
    echo "Checking if Fluent Bit is installed on ${host}..."
    local service_status=$(ssh "${SSH_USER}@${host}" "systemctl is-active fluent-bit")
    if [ "$service_status" == "active" ]; then
        echo "Fluent Bit is already installed on ${host}."
    else
        echo "Fluent Bit is not installed on ${host}. Installing..."
        ssh "${SSH_USER}@${host}" "curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh"
        echo "Fluent Bit installation completed on ${host}."
    fi
}

attempt_ssh() {
    local host=$1
    # Attempt to connect to the host
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${SSH_USER}@${host}" true; then
        echo "SSH key is already trusted on ${host}."
    else
        # If SSH connection fails, prompt for password and add the SSH key to the remote machine's authorized_keys
        echo "SSH key verification failed for ${host}. Attempting to add the SSH key..."
        read -s -p "Enter password for ${SSH_USER}@${host}: " password
        echo
        local sshpass_cmd="sshpass -p \"$password\""
        # Use sshpass and ssh-copy-id to add the SSH key
        eval "$sshpass_cmd ssh-copy-id -o StrictHostKeyChecking=no ${SSH_USER}@${host}"
    fi
}

verify_service_status() {
    local host=$1
    echo "Verifying Fluent Bit service status on ${host}..."
    local service_status=$(ssh "${SSH_USER}@${host}" "systemctl is-active fluent-bit")
    if [ "$service_status" == "active" ]; then
        echo "Fluent Bit service is running on ${host}."
    else
        echo "Fluent Bit service is not running on ${host}. Status: $service_status"
        echo "Attempting to start Fluent Bit service on ${host}..."
        ssh "${SSH_USER}@${host}" "systemctl start fluent-bit"
    fi
}

for HOST in "${HOSTS[@]}"; do
    # ping the host to check if it is reachable
    if ! ping -c 1 -W 1 "$HOST" &> /dev/null; then
        echo "Host $HOST is not reachable."
        continue
    fi

    echo "Updating fluent-bit.conf on ${HOST}"

    attempt_ssh "${HOST}"

    install_fluent_bit_if_needed "${HOST}"

    # Use SCP to copy the local configuration file to the remote path
    scp "$LOCAL_CONF_PATH" "${SSH_USER}@${HOST}:${REMOTE_CONF_PATH}"

    # Use SCP to copy the local configuration file to the remote path
    scp "$LOCAL_CONF_PATH2" "${SSH_USER}@${HOST}:${REMOTE_CONF_PATH2}"

    # Restart the Fluent Bit service on the remote machine
    ssh "${SSH_USER}@${HOST}" "systemctl restart fluent-bit && systemctl enable fluent-bit --now"

    echo "Update and restart completed for ${HOST}"
done

for HOST in "${HOSTS[@]}"; do
    # Verify Fluent Bit service status
    verify_service_status "${HOST}"

    echo "Verification completed for ${HOST}"
done
