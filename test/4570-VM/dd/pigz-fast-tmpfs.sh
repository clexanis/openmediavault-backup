#!/bin/bash
#
# shellcheck disable=SC1091,SC2086,SC2181
#
# Copyright (c) 2013-2023 OpenMediaVault Plugin Developers
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# version: 1.1.0
#
set -e

. /etc/default/openmediavault
. /usr/share/openmediavault/scripts/helper-functions

OMV_BACKUP_DIR_NAME=${OMV_BACKUP_DIR_NAME:-"omvbackup"}
OMV_BACKUP_FILE_PREFIX=${OMV_BACKUP_FILE_PREFIX:-"backup-omv"}
OMV_BACKUP_MAX_DEPTH=${OMV_BACKUP_MAX_DEPTH:-"1"}

# logging location
logDir="/var/log/"
logFile="${logDir}/omv-backup.log"

_log()
{
  msg=${1}
  echo "[$(date +'%Y-%m-%d %H:%M:%S%z')] [backup] ${msg}" | tee -a ${logFile} >&2
}

purgeOld()
{
    # get number of days to keep
    keep=$(omv_config_get "/config/system/backup/keep")
    _log "keep days :: ${keep}"
    if [[ ${keep} -gt 0 ]]; then
        _log "Purging old files..."
        find "${backupDir}" -maxdepth ${OMV_BACKUP_MAX_DEPTH} -type f -mtime +${keep} -name "${OMV_BACKUP_FILE_PREFIX}*" -delete
        _log "Purging done."
    else
        _log "Purging disabled."
    fi
}

_log "Starting backup..."

# date
date=$(date +"%Y-%m-%d_%H-%M-%S")

# clean apt-get cache to save space
apt-get clean

# clean openmediavault upload cache and recreate Packages file
rm -f /var/cache/openmediavault/archives/*
touch /var/cache/openmediavault/archives/Packages

# Get the shared folder reference and path
sfref=$(omv_config_get "/config/system/backup/sharedfolderref")
if ! omv_isuuid "${sfref}"; then
    _log "No backup volume set.  Please choose a backup volume."
    exit 10
fi
sfpath="$(omv_get_sharedfolder_path "${sfref}")"
if [ ! -d "${sfpath}" ]; then
    _log "Shared folder directory does not exist.  Exiting..."
    exit 11
fi

# set backup directory and create it if it doesn't exist
backupDir="${sfpath}/${OMV_BACKUP_DIR_NAME}"
_log "Create ${backupDir}"
mkdir -p "${backupDir}"

# Get the method of backup
method=$(omv_config_get "/config/system/backup/method")
_log "Method: ${method}"

# get device file for /
devicefile=$(awk '$5 == "/" { print $10 }' /proc/self/mountinfo)
_log "Device file:  ${devicefile}"

# try alternate method to get root device if /dev/root is returned
if [ "${devicefile}" = "/dev/root" ]; then
  devicefile=$(findmnt -n / | awk '{ print $2 }')
fi

if [ "${devicefile}" = "/dev/root" ] || [ -z "${devicefile}" ]; then
    _log "Could not determine root device file. Please specify in the root device textbox. Exiting..."
    exit 12
fi

# get root device
root=$(omv_config_get "/config/system/backup/root")

# if root is empty, try to determine root device
if [ -z "${root}" ]; then
    root="/dev/$(lsblk -no pkname ${devicefile})"
fi
_log "Root drive: ${root}"

if [ -z "${root}" ]; then
    _log "Could not determine root device.  Exiting..."
    exit 13
fi

# save helpful information
_log "Save fdisk output for ${root}"
fdisk -l ${root} > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.fdisk"
_log "Save blkid output"
blkid > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.blkid"
_log "Save package list"
dpkg -l | grep openmediavault > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.packages"

# calculate partition table size to accommodate GPT and MBR.
part_type=$(blkid -p ${root} | cut -d \" -f4)
_log "Partition type :: ${part_type}"
if [ "${part_type}" = "gpt" ]; then
    num_parts=$(parted -m ${root} print | tail -n1 | cut -b1)
    grubparts_bs_calc=$(((128 * num_parts) + 1024))
    esp=$(parted -m ${root} print | awk -F ":" '$7 ~ /esp/ { print $1 }')
    partletter=""
    if [[ ${root} =~ nvme ]]; then
        partletter="p"
    fi
    esppart="${root}${partletter}${esp}"
    _log "ESP partition :: ${esppart}"
    if [ -e "${esppart}" ]; then
      _log "Backup ESP partition"
      dd if=${esppart} bs=1M conv=sync,noerror status=progress | pigz --fast -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.espdd.gz"
    else
      _log "ESP partition '${esppart}' not found."
    fi
else
    grubparts_bs_calc=512
fi


# save partition table and mbr
_log "Save mbr"
dd if=${root} of="${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.grub" bs=446 count=1
_log "Save mbr and partition table"
dd if=${root} of="${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.grubparts" bs=${grubparts_bs_calc} count=1

# check for /boot partition
bootpart=$(awk '$2 == "/boot" { print $1 }' /proc/mounts)
if [ ! -b "${bootpart}" ]; then
    bootpart=""
else
    _log "Boot drive: ${bootpart}"
fi

# backup u-boot if platform_install.sh exists
if [ -f "/usr/lib/u-boot/platform_install.sh" ]; then
    . /usr/lib/u-boot/platform_install.sh
    if [ -d "${DIR}" ]; then
        _log "Backup u-boot"
        tar cjf "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}_u-boot.tar.bz" ${DIR}/*
    fi
fi

# perform backup based on method selected
case ${method} in
    dd)
        _log "Starting dd backup..."
        dd if=${devicefile} bs=1M conv=sync,noerror status=progress | pigz --fast -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.dd.gz"
        status=( "${PIPESTATUS[@]}" )
        _log "dd exit code = ${status[0]}"
        _log "pigz --fast exit code = ${status[1]}"
        if [[ ${status[0]} -gt 0 ]] || [[ ${status[1]} -gt 0 ]]; then
            _log "dd backup failed!"
        else
            _log "dd backup complete."
        fi
        sync
        if [ -n "${bootpart}" ]; then
            _log "Starting dd backup of boot partition..."
            dd if=${bootpart} bs=1M conv=sync,noerror status=progress | pigz --fast -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}_boot.dd.gz"
            _log "dd backup of boot partition complete."
        fi
        sync
        touch "${backupDir}/${OMV_BACKUP_FILE_PREFIX}"-${date}*.dd.gz
        purgeOld
        ;;

    ddfull)
        _log "Starting dd full disk..."
        dd if=${root} bs=1M conv=sync,noerror status=progress | pigz --fast -c > "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.ddfull.gz"
        status=( "${PIPESTATUS[@]}" )
        _log "dd exit code = ${status[0]}"
        _log "pigz --fast exit code = ${status[1]}"
        if [[ ${status[0]} -gt 0 ]] || [[ ${status[1]} -gt 0 ]]; then
            _log "dd full disk backup failed!"
        else
            _log "dd full disk backup complete."
        fi
        sync
        sync
        touch "${backupDir}/${OMV_BACKUP_FILE_PREFIX}"*-${date}.ddfull.gz
        purgeOld
        ;;

    fsarchiver)
        _log "Starting FSArchiver backup..."
        extra=$(omv_config_get "/config/system/backup/extraoptions")
        passwd="$(omv_config_get "/config/system/backup/passwd")"
        password=""
        if [ -n "${passwd}" ]; then
            _log "Encrypting archive..."
            password="--cryptpass=${passwd} "
        fi
        fsarchiver savefs ${password}-o "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.fsa" ${devicefile} ${bootpart} -v -A ${extra}
        if [ $? -ne 0 ]; then
            _log "FSArchiver backup failed!"
        else
            _log "FSArchiver backup complete."
        fi
        touch "${backupDir}/${OMV_BACKUP_FILE_PREFIX}"-${date}.*
        purgeOld
        fsarchiver archinfo ${password} "${backupDir}/${OMV_BACKUP_FILE_PREFIX}-${date}.fsa"
        ;;

    borg)
        _log "Starting borgbackup..."
        extra=$(omv_config_get "/config/system/backup/extraoptions")
        passwd="$(omv_config_get "/config/system/backup/passwd")"
        if [ -n "${passwd}" ]; then
            _log "Encrypting archive..."
            export BORG_PASSPHRASE="${passwd}"
        fi
        if [ ! -d "${backupDir}/borgbackup" ] ; then
          # First run - init borg directory
          _log "First run - init borg directory..."
          if [ -n "${passwd}" ]; then
            borg init -e repokey "${backupDir}/borgbackup"
          else
            borg init -e none "${backupDir}/borgbackup"
          fi
        fi
        _log "Starting borgbackup create..."
        borg create --stats "${backupDir}/borgbackup::${OMV_BACKUP_FILE_PREFIX}-${date}" / \
          -x --exclude-caches \
          -e "/dev" -e "/proc" -e "/sys" -e "/tmp" -e "/run" -e "/mnt" \
          -e "/media" -e "/lost+found" -e "/export" -e "/home/ftp" -e "/srv" ${extra}
        if [ $? -ne 0 ]; then
            _log "borgbackup create failed!"
        else
            _log "borgbackup create complete."
        fi
        keep=$(omv_config_get "/config/system/backup/keep")
        if [[ ${keep} -gt 0 ]]; then
          purgeOld
          _log "Starting borgbackup prune..."
          borg prune "${backupDir}/borgbackup" --keep-daily "${keep}"
          _log "borgbackup prune complete."
        fi
        ;;

    rsync)
        _log "Starting rsync..."
        extra=$(omv_config_get "/config/system/backup/extraoptions")

        rsync -aAXvxx /* "${backupDir}/" \
            --delete \
            --exclude=/dev \
            --exclude=/proc \
            --exclude=/sys \
            --exclude=/tmp \
            --exclude=/run \
            --exclude=/mnt \
            --exclude=/media \
            --exclude=/lost+found \
            --exclude=/export \
            --exclude=/home/ftp \
            --exclude=/srv ${extra}
        if [ $? -ne 0 ]; then
            _log "rsync backup failed!"
        else
            _log "rsync backup complete."
        fi
        purgeOld
        ;;
esac

_log "Backup complete."

exit 0