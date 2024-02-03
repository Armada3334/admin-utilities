#!/bin/bash

# Get input from user flags for each variable
while getopts "o:s:i:n:" flag; do
    case "${flag}" in
        o) VMWARE_FILE_PATH=${OPTARG};;
        s) PROXMOX_STORAGE=${OPTARG};;
        i) VM_ID=${OPTARG};;
        n) VM_NAME=${OPTARG};;
    esac
done

# Prompt user for input if flags are not set
if [[ -z $VMWARE_FILE_PATH ]]; then
    read -p "Enter the VMware file path (OVF/OVA/VMDK): " VMWARE_FILE_PATH
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

FILE_EXTENSION="${VMWARE_FILE_PATH##*.}"


# Create a new VM in Proxmox
echo "Creating new VM in Proxmox..."
qm create "$VM_ID" --name "$VM_NAME" --memory 2048 --net0 virtio,bridge=vmbr0

sleep 10

# Function to convert and import disk
convert_and_import_disk() {
    DISK_PATH="$1"
    echo "Converting disk image..."
    qemu-img convert -f vmdk -O qcow2 "${DISK_PATH}" "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2"

    echo "Importing disk to Proxmox VM..."
    qm importdisk "$VM_ID" "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2" "$PROXMOX_STORAGE" --format qcow2
}

case $FILE_EXTENSION in
    ovf)
        DISK_FILE="$(dirname "$VMWARE_FILE_PATH")/$(grep -oPm1 "(?<=<File ovf:href=\").+?(?=\" ovf:id=)" "$VMWARE_FILE_PATH")"
        convert_and_import_disk "$DISK_FILE"
        ;;
    ova)
        TEMP_DIR="/tmp/ova_extract_$VM_ID"
        mkdir -p "$TEMP_DIR"
        tar -xf "$VMWARE_FILE_PATH" -C "$TEMP_DIR"
        DISK_FILE="$TEMP_DIR/$(ls $TEMP_DIR | grep -E '\.vmdk$')"
        convert_and_import_disk "$DISK_FILE"
        rm -rf "$TEMP_DIR"
        ;;
    vmdk)
        convert_and_import_disk "$VMWARE_FILE_PATH"
        ;;
    *)
        echo "Unsupported file format."
        exit 1
        ;;
esac

# Attach the disk to the VM
echo "Attaching disk to VM..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$PROXMOX_STORAGE:vm-$VM_ID-disk-1"

# Clean up
echo "Cleanup..."
rm "/var/lib/vz/images/$VM_ID/vm-$VM_ID-disk-1.qcow2"

echo "VM import completed. You can now start the VM from the Proxmox UI."
