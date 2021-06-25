#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

#________ VARS DO NOT EDIT

SDNAME=                # a share drive rclone config entry
SDID=                  # a share drive ID
SAPATH=                # service account path "/opt/sa/mounts"
DRVLIST=               # list of drives configured
RCUNAME=               # name for rclone union config entry
STRUNION=              # union upstream string (accumulates during drive additions)
VFSCACHESIZE=          # maximum size for VFS cache
STRMERGER=             # merger string
MNTPNT=/mnt/${RCUNAME} #
RCLONE_RC_PORT=5575    # initial port for VFS
RCI=true               # install or update Rclone?
RCB=false              # rclone beta?
CBI=false              # cloudbox install?
NOW=$(date)
FREESPACE=$(df -h --output=avail /home/"$USER")
RECSPACE=$(("${FREESPACE//[^0-9]/}" * 80 / 100))

#________ FUNCTIONS

rooter() {
    if [ "$(whoami)" = root ]; then
        echo "Running as root or with sudo is not supported. Exiting."
        exit
    fi
}

cloudboxer() {
    read -r -p "Is this a cloudbox install?  [Y/N] : " i
    case $i in
    [yY])
        echo -e "mergerfs content line will be displayed after smounting has occured"
        CBI="true"
        # readmergerfs
        ;;
    [nN])
        echo -e "thank you"
        RCI="false"
        ;;
    esac
}

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
        curl https://rclone.org/install.sh | sudo bash -s beta &>/dev/null || :
        echo "rclone beta installed"
    else
        echo "Installing rclone stable"
        curl https://rclone.org/install.sh | sudo bash &>/dev/null || :
        echo "rclone stable installed"
    fi
}

universals() {
    echo
    echo "Please enter service account file path, for example /opt/sa/mounts :"
    read -r SAPATH
    echo
    echo "Please enter name to use for rclone union mount, eg reunion."
    read -r RCUNAME
    MNTPNT="/mnt/${RCUNAME}"
    echo
    echo "You currently have ${FREESPACE},"
    echo "DO NOT use all of this for cache."
    echo Suggest using no more than "${RECSPACE}"G
    echo
    echo "Please enter cache max size +G (ex 50G)"
    read -r VFSCACHESIZE
    echo
}

driveadd() {
    echo
    echo "Please enter a share drive name :"
    read -r SDNAME
    echo
    echo "Please enter ""${SDNAME}"" Drive ID, for example 0A1xxxxxxxxxUk9PVA :"
    read -r "SDID"
    SAFILE="$(shuf -n1 -e "${SAPATH}"/*.json)"
    driveconfig
    arewedone
}

arewedone() {
    read -r -p "Would you like to add another drive?  [Y/N] : " i
    case $i in
    [yY])
        echo -e "adding more drives"
        echo
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
    # check and fix fuse.conf if needed
    sudo sed -i -e "s/\#user_allow_other/user_allow_other/" "/etc/fuse.conf" || :
}

sdrmconfig() {
    echo
    echo creating rclone config for "${SDNAME}" with ID "${SDID}"
    rclone config create "${SDNAME}" drive scope drive server_side_across_configs true team_drive "$SDID" service_account_file "${SAFILE}"
    echo
}

rcunionconfig() {
    echo creating "${RCUNAME}" rclone union config with default policy options.
    echo "ACTION:  epall"
    echo "CREATE:  epmfs"
    echo "SEARCH:  ff"
    echo
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

mkmounce() {
    sudo mkdir -p "${MNTPNT}" && sudo chown "${USER}":"${USER}" "${MNTPNT}"
    mkdir -p /home/"${USER}"/logs && touch /home/"${USER}"/logs/smount.log
}

checkport() {
    echo "checking if port ${RCLONE_RC_PORT} is already in use"
    if [[ $(sudo lsof -i:"${RCLONE_RC_PORT}") != *localhost* ]]; then
        echo "port ${RCLONE_RC_PORT} is available and will be used"
    else
        RCLONE_RC_PORT=$((RCLONE_RC_PORT + 1))
        echo "setting port to ${RCLONE_RC_PORT}"
        checkport
    fi
}

sysdmaker() {
    sudo bash -c 'cat > /etc/systemd/system/smount.service' <<EOF
# /etc/systemd/system/smount.service
[Unit]
Description=smount RCUnion Mount
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
          --log-file=/home/${USER}/logs/smount.log \\
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
    sudo systemctl enable smount.service
}

cloudboxmsg() {
    if [ $CBI = true ]; then
        echo "--------------------"
        echo "in cloudbox installations the union can be included in mergerfs directory"
        echo "/etc/systemd/system/mergerfs.service can be edited to include ${RCUNAME} eg:-"
        echo "  /mnt/local=RW:/mnt/remote=NC:/mnt/${RCUNAME}:NC /mnt/unionfs"
        echo "--------------------"
        echo
    else
        echo
    fi
}

#________ SET LIST

rooter
echo
rcloneinstall
universals
echo "--------------------"
echo "User is:          ${USER}"
echo "SA Path:          ${SAPATH}"
echo "Cache size:       ${VFSCACHESIZE}"
echo "Mount Name:       ${RCUNAME}"
echo "Mount Point:      ${MNTPNT}"
echo "Continue with installation?"
echo "--------------------"
carryon
mkmounce
echo
rclonecheck
echo
fusebox
echo "add your first drive"
driveadd
echo
echo "Drives added:   ${DRVLIST}"
echo
rcunionconfig
sleep 1
echo
cloudboxer
echo
checkport
echo
echo "Preparing smount service"
sysdmaker
enabler
sudo systemctl daemon-reload
echo
echo "starting the ${RCUNAME} service, be patient. If you have a big one this might take a while."
sudo systemctl start smount.service
# nohup sh sudo systemctl start smount.service &>/dev/null &
echo
cloudboxmsg
echo "${RCUNAME} smount smounty smounted"
echo
echo 'ᕙ(⇀‸↼‶)ᕗ'
echo
echo "please consider reporting any issues"
