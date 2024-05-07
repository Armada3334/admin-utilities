#!/bin/bash

# Use flags to specify the NFS server, share, and mount point

while getopts s:p:m: flag
do
    case "${flag}" in
        s) NFS_SERVER=${OPTARG};;
        p) NFS_SHARE=${OPTARG};;
        m) MOUNT_POINT=${OPTARG};;
    esac
done

# Install NFS Client Utilities
echo "Installing NFS client utilities..."
sudo apt update
sudo apt install -y nfs-common

# Create a Mount Point
echo "Creating mount point at ${MOUNT_POINT}..."
sudo mkdir -p "${MOUNT_POINT}"

# Mount the NFS Share
echo "Mounting NFS share..."
sudo mount -t nfs "${NFS_SERVER}:${NFS_SHARE}" "${MOUNT_POINT}"

# Add entry to /etc/fstab for automatic mounting on boot
echo "Adding NFS share to /etc/fstab for automatic mounting on boot..."
echo "${NFS_SERVER}:${NFS_SHARE} ${MOUNT_POINT} nfs defaults 0 0" | sudo tee -a /etc/fstab

echo "NFS share mounted successfully."
