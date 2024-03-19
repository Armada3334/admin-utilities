#!/bin/bash

# Get -s flag for share folder path. -s is the only one that has an argument, all following flags are toggles: -a for if anonymous access is allowed (default no), -r for if read-only access is allowed (default no)
while getopts "s:a:r:" flag; do
    case "${flag}" in
        s) SHARE_FOLDER_PATH=${OPTARG};;
        a) ANONYMOUS_ACCESS="YES";;
        r) READ_ONLY="YES";;
    esac
done

# Install vsftpd
sudo apt-get update
sudo apt-get install vsftpd -y

# Backup the original vsftpd configuration
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

# config vsftpd
echo "listen=NO
listen_ipv6=YES
anonymous_enable=$ANONYMOUS_ACCESS
local_enable=NO
write_enable=NO
anon_root=$SHARE_FOLDER_PATH
anon_max_rate=2048000
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
pasv_enable=Yes
pasv_min_port=10000
pasv_max_port=10100" | sudo tee /etc/vsftpd.conf > /dev/null

# Create the shared folder
sudo mkdir -p $SHARE_FOLDER_PATH
sudo chmod -R 755 $SHARE_FOLDER_PATH
sudo chown -R ftp:ftp $SHARE_FOLDER_PATH

# Restart vsftpd to apply the changes
sudo systemctl restart vsftpd
