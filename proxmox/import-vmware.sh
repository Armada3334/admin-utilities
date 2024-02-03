#!/bin/bash

# Get input from user flags for each variable
while getopts "o:s:i:n:" flag; do
    case "${flag}" in
        o) VMWARE_OVF_PATH=${OPTARG};;
        s) PROXMOX_STORAGE=${OPTARG};;
        i) VM_ID=${OPTARG};;
        n) VM_NAME=${OPTARG};;
    esac
done

# Prompt user for input if flags are not set
if [[ -z $VMWARE_OVF_PATH ]]; then
    read -p "Enter the VMware OVF path: " VMWARE_OVF_PATH
fi

if [[ -z $PROXMOX_STORAGE ]]; then
    read -p "Enter the Proxmox storage ID (local-lvm): " PROXMOX_STORAGE
fi

if [[ -z $VM_ID ]]; then
    read -p "Enter the new VM ID: " VM_ID
fi

if [[ -z $VM_NAME ]]; then
    read -p "Enter the new VM name: " VM_NAME
fi

# Convert VMware disk to QCOW2 format
echo "Converting disk image..."
qemu-img convert -f vmdk -O qcow2 "$(dirname "$VMWARE_OVF_PATH")/$(grep -oPm1 "(?<=<File ovf:href=\").+?(?=\" ovf:id=)" "$VMWARE_OVF_PATH")" "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2"

# Create a new VM in Proxmox
echo "Creating new VM in Proxmox..."
qm create "$VM_ID" --name "$VM_NAME" --memory 2048 --net0 virtio,bridge=vmbr0

# Import the disk to Proxmox VM
echo "Importing disk to Proxmox VM..."
qm importdisk "$VM_ID" "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2" "$PROXMOX_STORAGE" --format qcow2

# Attach the disk to the VM
echo "Attaching disk to VM..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$PROXMOX_STORAGE:vm-$VM_ID-disk-1"

# Clean up
echo "Cleanup..."
rm "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2"

echo "VM import completed. You can now start the VM from the Proxmox UI."
