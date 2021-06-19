#!/usr/bin/env bash
set -Eeuo pipefail
# set -xv
# IFS=$'\n\t'

#________ INTERACTIVE VARS

# Share Drives
SDNAME=                        # The name for this mount and rclone config entry
SDID=XXX                       # The share drive ID for this mount
SAFILENAME=                    # 123.json. The initial service account file for this mount.
SAPATH=                        # /opt/sa/mounts
SAFILE=${SAPATH}/${SAFILENAME} #
DRVLIST=                       # List of drives added to report back during interactive testing.

# Rclone UNION
RCUNAME=               # The name for this rclone union and mount directory
MNTPNT=/mnt/${RCUNAME} #
STRUNION=              # The union upstream string (accumulates during drive additions)

# MergerFS var
STRMERGER= # The union upstream string (accumulates during drive additions)

# MOUNT VARS
VFSCACHESIZE=100G   # Max size for VFS cache
RCLONE_RC_PORT=5575 # Port for VFS RC ( will be checked with "sudo lsof -i:5575" )

# installs
RCI=true  # Install or update Rclone?
RCB=false # Rclone Beta installed or updated?

# facts

NOW=$(date)
FREESPACE=$(df -h --output=avail /home/"$USER")

#
#________ FUNCTIONS

# Check for sudo runner
rooter() {
    if [ "$(whoami)" = root ]; then
        echo "Running as root or with sudo is not supported. Exiting."
        exit
    fi
}

## RCLONE
rcloneinstall() {
    read -r -p "Would you like to install or update rclone?  [Y/N] : " i
    case $i in
    [yY])
        echo -e "rclone will be installed"
        RCI="true"
        rclonebetaq
        ;;
    [nN])
        echo -e "fine"
        RCI="false"
        # return 0
        ;;
    *)
        echo "Invalid Option"
        rcloneinstall
        ;;
    esac
}

rclonebetaq() {
    echo "Do you want rclone beta or stable?"
    select yn in "Beta" "Stable" "No"; do
        case $yn in
        Beta)
            RCB="true"
            RCI="true"
            break
            ;;
        Stable)
            RCB="false"
            RCI="true"
            break
            ;;
        No)
            RCI="false"
            break
            #return 0
            ;;
        esac
    done
}

rclonecheck() {
    ([ $RCI = true ] && rclonebaker) || :
    # fi
}

rclonebaker() {
    if [ $RCB = true ]; then
        echo "Installing rclone beta"
        curl https://rclone.org/install.sh | sudo bash -s beta || :
    else
        echo "Installing rclone stable"
        curl https://rclone.org/install.sh | sudo bash || :
    fi
}

universals() {
    echo "Please enter service account file path, for example /opt/sa/mounts :"
    read -r SAPATH
    echo "Please enter an existing service account filename, for example 123.json :"
    read -r SAFILENAME
    SAFILE="${SAPATH}/${SAFILENAME}"
    echo "--------------------"
    echo "Please enter name to use for rclone union mount, eg reunion."
    read -r RCUNAME
    MNTPNT="/mnt/${RCUNAME}"
    echo "--------------------"
    echo "You currently have ${FREESPACE} free,"
    echo "DO NOT use all of this for cache."
    echo "--------------------"
    echo "Rclone mount will use vfs-cache-mode full, and use 100GB, do you want to change max cache size?"
    select yn in "Yes" "No"; do
        case $yn in
        Yes)
            echo "Please enter cache max size +G (ex 50G)"
            read -r VFSCACHESIZE
            break
            ;;
        No)
            VFSCACHESIZE=100G
            break
            ;;
        esac
    done

}

driveadd() {
    echo "Please enter Share Drive Name :"
    read -r SDNAME
    echo "Please enter ""${SDNAME}"" Drive ID, for example 0A1xxxxxxxxxUk9PVA :"
    read -r "SDID"
    # add this drive to rclone config and set the union var
    driveconfig
    # check for next drive
    arewedone
}

arewedone() {
    read -r -p "Would you like to add another drive?  [Y/N] : " i
    case $i in
    [yY])
        echo -e "adding more drives"
        driveadd
        ;;
    [nN])
        echo -e "lettuce build mounts"
        return 0
        ;;
    *)
        echo "Invalid Option"
        arewedone
        ;;
    esac
}

driveconfig() {
    STRUNION="${STRUNION}${SDNAME}: "
    DRVLIST="${DRVLIST}${SDNAME} "
    STRMERGER="${STRMERGER}${SDNAME}: "
    sdrmconfig
}

fusebox() {
    # check and fix fuse.conf
    sudo sed -i -e "s/\#user_allow_other/user_allow_other/" "/etc/fuse.conf" || :
}

# rclone sharedrive config entry function
sdrmconfig() {
    echo creating rclone config for "${SDNAME}" with ID "${SDID}"
    rclone config create "${SDNAME}" drive scope drive server_side_across_configs true team_drive "$SDID" service_account_file "${SAFILE}"
}

# rclone union config entry function
rcunionconfig() {
    echo creating "${RCUNAME}" rclone union config with default policy options.
    echo "ACTION:  epall"
    echo "CREATE:  epmfs"
    echo "SEARCH:  ff"
    rclone config create "${RCUNAME}" union upstreams "${STRUNION}"
}

carryon() {
    select yn in "Continue" "Exit"; do
        case $yn in
        Continue) break ;;
        Exit) exit 0 ;;
        esac
    done

}

# mountpoints
mkmounce() {
    sudo mkdir -p "${MNTPNT}" && sudo chown "${USER}":"${USER}" "${MNTPNT}"
    mkdir -p /home/"${USER}"/logs && touch /home/"${USER}"/logs/shmount.log
}

checkport() {
    echo "checking if port ${RCLONE_RC_PORT} is already in use"
    if [[ $(sudo lsof -i:"${RCLONE_RC_PORT}") != *localhost* ]]; then
        echo "port ${RCLONE_RC_PORT} is available and will be used"
    else
        RCLONE_RC_PORT=$((${RCLONE_RC_PORT} + 1))
        echo "setting port to ${RCLONE_RC_PORT}"
        checkport
    fi
}

# servicemaker
sysdmaker() {
    sudo bash -c 'cat > /etc/systemd/system/shmount.service' <<EOF
# /etc/systemd/system/shmount.service
[Unit]
Description=shmount RCUnion Mount
After=network-online.target

[Service]
User=${USER}
Group=${USER}

Type=notify

ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/rclone mount \\
          --config=/home/${USER}/.config/rclone/rclone.conf \\
          --rc-addr=localhost:${RCLONE_RC_PORT} \\
          --allow-other \\
          --allow-non-empty \\
          --fast-list \\
          --async-read=true \\
          --cache-db-purge \\
          --dir-cache-time=1000h \\
          --buffer-size=32M \\
          --poll-interval=15s \\
          --rc \\
          --rc-no-auth \\
          --use-mmap \\
          --vfs-read-ahead=128M \\
          --vfs-read-chunk-size=32M \\
          --vfs-read-chunk-size-limit=2G \\
          --vfs-cache-max-age=504h \\
          --vfs-cache-mode=full \\
          --vfs-cache-poll-interval=30s \\
          --vfs-cache-max-size=${VFSCACHESIZE} \\
          --timeout=10m \\
          --drive-skip-gdocs \\
          --drive-pacer-min-sleep=10ms \\
          --umask=002 \\
          --log-file=/home/${USER}/logs/shmount.log \\
          -v \\
          ${RCUNAME}: ${MNTPNT}

ExecStop=/bin/fusermount -uz ${MNTPNT}
ExecStartPost=/usr/bin/rclone rc vfs/refresh recursive=true --rc-addr localhost:${RCLONE_RC_PORT} _async=true
Restart=on-abort
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=default.target
EOF
}

enabler() {
    sudo systemctl enable shmount.service
}

#________ SET LIST

rooter
rcloneinstall
universals
echo "--------------------"
echo "User is:          ${USER}"
echo "SA Path:          ${SAPATH}"
echo "SA file:          ${SAFILE}"
echo "Cache size:       ${VFSCACHESIZE}"
echo "Mount Name:       ${RCUNAME}"
echo "Mount Point:      ${MNTPNT}"
echo "Continue with installation?"
echo "--------------------"
carryon
mkmounce
rclonecheck
fusebox
driveadd
echo "Drives added:   ${DRVLIST}"
echo "--------------------"
sleep 3
rcunionconfig
sleep 3
checkport
echo "--------------------"
echo "Preparing shmount service"
sysdmaker
enabler
sudo systemctl daemon-reload
echo "starting the ${RCUNAME} service, be patient. If you have a big one this might take a while."
sudo systemctl start shmount.service
# nohup sh sudo systemctl start shmount.service &>/dev/null &
echo "--------------------"
echo "${RCUNAME} rclone union mount smounted"
echo "--------------------"
echo "--------------------"
echo "/etc/systemd/system/mergerfs.service can be edited to include ${RCUNAME} eg:-"
echo "  /mnt/local=RW:/mnt/remote=NC:/mnt/${RCUNAME}:NC /mnt/unionfs"
echo "--------------------"
echo "please consider reporting any issues"
