#!/bin/bash
level=${1}
method=dd
devicefile=/dev/mapper/internal-root
root=/dev/sda
OMV_BACKUP_FILE_PREFIX="backup-omv"

echo "Starting backup..."

# date
date=$(date +"%Y-%m-%d_%H-%M-%S")

# clean apt-get cache to save space
apt-get clean

# set backup directory and create it if it doesn't exist
backupDir="/srv/tmpfs"

# Get the method of backup
echo "Method: ${method}"

echo "Device file:  ${devicefile}"

# try alternate method to get root device if /dev/root is returned
if [ "${devicefile}" = "/dev/root" ]; then
  devicefile=$(findmnt -n / | awk '{ print $2 }')
fi

if [ "${devicefile}" = "/dev/root" ] || [ -z "${devicefile}" ]; then
    echo "Could not determine root device file. Please specify in the root device textbox. Exiting..."
    exit 12
fi

# if root is empty, try to determine root device
if [ -z "${root}" ]; then
    root="/dev/$(lsblk -no pkname ${devicefile})"
fi
echo "Root drive: ${root}"

if [ -z "${root}" ]; then
    echo "Could not determine root device.  Exiting..."
    exit 13
fi

# save helpful information
echo "Save fdisk output for ${root}"
fdisk -l ${root} > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.fdisk"
echo "Save blkid output"
blkid > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.blkid"
echo "Save package list"
dpkg -l | grep openmediavault > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.packages"

# calculate partition table size to accommodate GPT and MBR.
part_type=$(blkid -p ${root} | cut -d \" -f4)
echo "Partition type :: ${part_type}"
if [ "${part_type}" = "gpt" ]; then
    num_parts=$(parted -m ${root} print | tail -n1 | cut -b1)
    grubparts_bs_calc=$(((128 * num_parts) + 1024))
    esp=$(parted -m ${root} print | awk -F ":" '$7 ~ /esp/ { print $1 }')
    partletter=""
    if [[ ${root} =~ nvme ]]; then
        partletter="p"
    fi
    esppart="${root}${partletter}${esp}"
    echo "ESP partition :: ${esppart}"
    if [ -e "${esppart}" ]; then
      echo "Backup ESP partition"
      dd if=${esppart} bs=1M conv=sync,noerror status=progress | zstdmt -${level} -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.espdd.zst"
    else
      echo "ESP partition '${esppart}' not found."
    fi
else
    grubparts_bs_calc=512
fi


# save partition table and mbr
echo "Save mbr"
dd if=${root} of="${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.grub" bs=446 count=1
echo "Save mbr and partition table"
dd if=${root} of="${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.grubparts" bs=${grubparts_bs_calc} count=1

# check for /boot partition
bootpart=$(awk '$2 == "/boot" { print $1 }' /proc/mounts)
if [ ! -b "${bootpart}" ]; then
    bootpart=""
else
    echo "Boot drive: ${bootpart}"
fi

# backup u-boot if platform_install.sh exists
if [ -f "/usr/lib/u-boot/platform_install.sh" ]; then
    . /usr/lib/u-boot/platform_install.sh
    if [ -d "${DIR}" ]; then
        echo "Backup u-boot"
        tar cjf "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}_u-boot.tar.bz" ${DIR}/*
    fi
fi

# perform backup based on method selected
case ${method} in
    dd)
        echo "Starting dd backup..."
        dd if=${devicefile} bs=1M conv=sync,noerror status=progress | zstdmt -${level} -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.dd.zst"
        status=( "${PIPESTATUS[@]}" )
        echo "dd exit code = ${status[0]}"
        echo "gzip exit code = ${status[1]}"
        if [[ ${status[0]} -gt 0 ]] || [[ ${status[1]} -gt 0 ]]; then
            echo "dd backup failed!"
        else
            echo "dd backup complete."
        fi
        sync
        if [ -n "${bootpart}" ]; then
            echo "Starting dd backup of boot partition..."
            dd if=${bootpart} bs=1M conv=sync,noerror status=progress | zstdmt -${level} -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}_boot.dd.zst"
            echo "dd backup of boot partition complete."
        fi
        sync
        ;;
esac

echo "Backup complete."

exit 0
