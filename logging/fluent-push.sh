#!/bin/bash


# Path to the file containing the list of IP addresses
HOSTS_FILE="hosts.txt"

# Read IP addresses into an array
mapfile -t HOSTS < "${HOSTS_FILE}"

#HOSTS=("172.16.0.27")

# Path to the local fluent-bit.conf file
LOCAL_CONF_PATH="./fluent-bit.conf"

# Remote path where the fluent-bit.conf should be replaced
REMOTE_CONF_PATH="/etc/fluent-bit/fluent-bit.conf"

# SSH User
SSH_USER="root" # or "admin", depending on your setup

# Function to check and install packages if they are not installed
check_and_install_packages() {
    local host=$1
    local sshpass_cmd=$2
    # Commands to check if packages are installed and install them if they are not
    local check_install_cmd="DEBIAN_FRONTEND=noninteractive apt-get update && \
    dpkg -l gpg software-properties-common curl || apt-get install -y gpg software-properties-common curl"
    
    # Execute the command
    echo "Checking and installing packages on ${host}"
    eval "$sshpass_cmd ssh -o StrictHostKeyChecking=no ${SSH_USER}@${host} \"$check_install_cmd\""
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

        # After adding the SSH key, check and install necessary packages
        check_and_install_packages "${host}" "$sshpass_cmd"
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
    fi
}

for HOST in "${HOSTS[@]}"; do
    echo "Updating fluent-bit.conf on ${HOST}"

    attempt_ssh "${HOST}"

    ssh "${SSH_USER}@${HOST}" "apt-get update && apt-get install -y gpg software-properties-common curl"

    ssh "${SSH_USER}@${HOST}" "curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh"

    # Use SCP to copy the local configuration file to the remote path
    scp "$LOCAL_CONF_PATH" "${SSH_USER}@${HOST}:${REMOTE_CONF_PATH}"

    # Restart the Fluent Bit service on the remote machine
    ssh "${SSH_USER}@${HOST}" "systemctl restart fluent-bit && systemctl enable fluent-bit --now"

    echo "Update and restart completed for ${HOST}"
done

for HOST in "${HOSTS[@]}"; do
    # Verify Fluent Bit service status
    verify_service_status "${HOST}"

    echo "Verification completed for ${HOST}"
done