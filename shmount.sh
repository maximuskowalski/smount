#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

#________ VARS DO NOT EDIT

SHMOUNT=smount      # this will be tname rcunion remote and systemd service
SDNAME=             # a share drive rclone config entry
SDID=               # a share drive ID
SAPATH=             # service account path "/opt/sa/mounts"
DRVLIST=            # list of drives configured
STRUNION=           # union upstream string (accumulates during drive additions)
VFSCACHESIZE=       # maximum size for VFS cache
STRMERGER=          # merger string
RCLONE_RC_PORT=5575 # initial port for VFS
RCI=true            # install or update Rclone?
RCB=false           # rclone beta?
CBI=false           # cloudbox install?
LGLVL=INFO          # Log level for mount logging
LGKP=7              # Number of days logs to keep
THIS_OS=            # OS
SYSTEMD=            # Use systemd?

MNTPNT=/mnt/${SHMOUNT}
FREESPACE=$(df -h --output=avail /home/"$USER")
RECSPACE=$(("${FREESPACE//[^0-9]/}" * 80 / 100))
VERSION=$(rclone --version 2>>errors | head -n 1)

#________ COLOURS

BOLD="$(tput bold)"        # bold
RESET="$(tput sgr0)"       # reset
RED="$(tput setaf 1)"      # red
GREEN="$(tput setaf 2)"    # green
YELLOW="$(tput setaf 3)"   # yellow
BRED="$(tput setaf 9)"     # bright red
BGREEN="$(tput setaf 10)"  # bright green
BYELLOW="$(tput setaf 11)" # bright yellow

#________ FUNCTIONS

# check if script user is root
rooter() {
    if [ "$(id -u)" = 0 ]; then
        echo "${BRED} Running as root or with sudo is not supported. Exiting.${RESET}"
        exit
    fi
}

# check compatible OS
osdetection() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        THIS_OS=$ID_LIKE
    elif type lsb_release >/dev/null 2>&1; then
        THIS_OS=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        THIS_OS=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        THIS_OS=Debian
    elif [ -f /etc/SuSe-release ]; then
        THIS_OS=SuSE
    elif [ -f /etc/redhat-release ]; then
        THIS_OS=RedHat
    else
        # Fall back to uname.
        THIS_OS=$(uname -s)
    fi

}

systemd_detection() {
    if [ -f /lib/systemd/system/systemd-resolved.service ]; then
        SYSTEMD=true
    else
        SYSTEMD=false
    fi
}

myball() {
    if [ $SYSTEMD = false ]; then
        echo "${BRED} Smount requires systemd. OS. not supported. Exiting.${RESET}"
        exit
    else
        osdetection
        if [[ "${THIS_OS}" != "arch" ]] || [ "${THIS_OS}" = "Debian" ] || [ "${THIS_OS}" = "Ubuntu" ]; then
            echo "${THIS_OS} supported"
        else
            echo "${BRED} ${THIS_OS} has not been tested with smount but should work."
            echo " Smounting will continue ${RESET}"
            exit
        fi
    fi
}

# TODO: add options for mergerfs edit and / or replace "remote"
cloudboxer() {
    echo
    read -r -p "${YELLOW}Is this a cloudbox install?  [Y/N] :${RESET}" i
    case $i in
    [yY])
        echo -e "${YELLOW}mergerfs content line will be displayed after smounting has occured"
        echo
        CBI="true"
        # TODO: readmergerfs line
        ;;
    [nN])
        echo -e "${YELLOW}thank you"
        echo
        RCI="false"
        ;;
    esac
}

# TODO: consider forcing install if beta detected
betachek() {
    if
        rclone --version 2>>errors | head -n 1 | grep -q 'beta'
    then
        echo you have "${VERSION}" installed
        echo
        echo "${YELLOW}this script will not configure rclone"
        echo "properly with the current rclone beta"
        echo "if you wish to use beta, or have beta installed"
        echo "please select rclone beta install to have smount"
        echo "temporarily install rclone stable to complete"
        echo "the config process and update to beta when done"
        echo
        rcloneinstall
    else
        rcloneinstall
    fi
}

rcloneinstall() {
    read -r -p "${YELLOW}Would you like to install or update rclone?  [Y/N] :${RESET}" i
    case $i in
    [yY])
        echo -e "${YELLOW}rclone will be installed"
        RCI="true"
        rclonebetaq
        ;;
    [nN])
        echo -e "${YELLOW}no clone for you"
        RCI="false"
        ;;
    *)
        echo "${BRED}Invalid Option"
        rcloneinstall
        ;;
    esac
}

rclonebetaq() {
    echo
    echo "${YELLOW}Do you want rclone beta or stable?${RESET}"
    select yn in "Beta" "Stable" "No"; do
        case $yn in
        Beta)
            RCB="true"
            break
            ;;
        Stable)
            RCB="false"
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
    ([ $RCI = true ] && rclonesetup) || :
}

rclonesetup() {
    if [ $RCB = true ]; then
        echo "${YELLOW}Installing rclone stable, rclone beta"
        echo "will be installed after config${GREEN}"
        curl https://rclone.org/install.sh | sudo bash || :
        clear
        echo "${YELLOW}rclone stable installed for configuration bug"
        echo "rclone beta will be installed after configuration is completed"
        echo
    else
        echo "${GREEN}Installing rclone stable${GREEN}"
        curl https://rclone.org/install.sh | sudo bash || :
        VERSION=$(rclone --version 2>>errors | head -n 1)
        clear
        echo "${YELLOW}rclone stable installed"
        echo "${VERSION}"
        echo
    fi
}

rclonecheckmate() {
    ([ $RCB = true ] && rclonebaker) || :
}

rclonebaker() {
    echo "${YELLOW}Now installing rclone beta${GREEN}"
    curl https://rclone.org/install.sh | sudo bash -s beta || :
    VERSION=$(rclone --version 2>>errors | head -n 1)
    clear
    echo "${YELLOW}rclone beta installed"
    echo "${VERSION}"
    echo
}

universals() {
    echo
    echo "${YELLOW}Please enter name to use for mount, and service"
    echo "default is smount :${RESET}"
    read -r SHMOUNT
    MNTPNT="/mnt/${SHMOUNT}"
    echo
    echo "${YELLOW}Please enter service account file path, for example /opt/sa/mounts :${RESET}"
    read -r SAPATH
    echo
    echo "${BYELLOW}You currently have ${FREESPACE},"
    echo "${BYELLOW}DO NOT use all of this for cache."
    echo "${BYELLOW}""${BOLD}"Suggest using no more than "${RED}""${RECSPACE}"G "${RESET}"
    echo
    echo "${YELLOW}""Please enter cache max size +G (ex ${RESET}50G${YELLOW})""${RESET}"
    read -r VFSCACHESIZE
    echo
    logginglevel
    echo
    echo "${YELLOW}""If you have set log level to debug this can add up quickly"
    echo "How many days worth of mount logs would you like to keep?"
    echo "enter a number, ex ${RESET}10${YELLOW})""${RESET}"
    read -r LGKP
    echo
}

logginglevel() {
    echo "Logging levels are:-"
    echo
    echo "${RESET}""DEBUG  - ""${YELLOW}""lots of debug info. larger log files"
    echo "${RESET}""INFO   - ""${YELLOW}""RECOMMENDED information and events."
    echo "${RESET}""NOTICE - ""${YELLOW}""warnings and significant events."
    echo "${RESET}""ERROR  - ""${YELLOW}""only outputs error messages. smallest log files.""${RESET}"
    echo
    echo 'Choose your logging level: '
    # PS3='Choose your logging level: '
    select i in "DEBUG" "INFO" "NOTICE" "ERROR"; do
        case $i in
        "DEBUG")
            LGLVL="DEBUG"
            break
            ;;
        "INFO")
            LGLVL="INFO"
            break
            ;;
        "NOTICE")
            LGLVL="NOTICE"
            break
            ;;
        "ERROR")
            LGLVL="ERROR"
            break
            ;;
        esac
    done
}

# TODO: make ID and NAME a paired input.  "SM_TV:0A1xxxxxxxxxUk9PVA"
# TODO: make option to import list or file?
driveadd() {
    echo
    echo "${YELLOW}Please enter a share drive name :${RESET}"
    read -r SDNAME
    echo
    echo "${YELLOW}Please enter ""${SDNAME}"" Drive ID, for example ${RESET}0A1xxxxxxxxxUk9PVA ${YELLOW}:${RESET}"
    read -r "SDID"
    SAFILE="$(shuf -n1 -e "${SAPATH}"/*.json)"
    driveconfig
    arewedone
}

arewedone() {
    read -r -p "${YELLOW}Would you like to add another drive?  [Y/N] : ${RESET}" i
    case $i in
    [yY])
        echo -e "${YELLOW}adding more drives"
        echo
        driveadd
        ;;
    [nN])
        echo -e "${YELLOW}lettuce build mounts"
        return 0
        ;;
    *)
        echo "${BRED}Invalid Option"
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

# check and fix fuse.conf if needed
fusebox() {
    echo
    sudo sed -i -e "s/\#user_allow_other/user_allow_other/" "/etc/fuse.conf" || :
}

# rclone beta bug - no drive ID created, use only stable
# maybe force stable condition for rclone install dodgers
sdrmconfig() {
    echo
    echo "${YELLOW}"creating rclone config for "${SDNAME}" with ID "${SDID}" "${RESET}"
    echo
    rclone config create "${SDNAME}" drive scope drive server_side_across_configs true team_drive "$SDID" service_account_file "${SAFILE}"
    echo
}

rcunionconfig() {
    echo
    echo "${YELLOW}"creating "${SHMOUNT}" rclone union config with default policy options.
    echo "ACTION:  epall"
    echo "CREATE:  epmfs"
    echo "SEARCH:  ff"
    echo "${RESET}"
    rclone config create "${SHMOUNT}" union upstreams "${STRUNION}"
}

carryon() {
    echo "${YELLOW}Continue with installation?${RESET}"
    select yn in "Continue" "Exit"; do
        case $yn in
        Continue) break ;;
        Exit) exit 0 ;;
        esac
    done
}

mkmounce() {
    sudo mkdir -p "${MNTPNT}" && sudo chown "${USER}":"${USER}" "${MNTPNT}"
    mkdir -p /home/"${USER}"/logs && touch /home/"${USER}"/logs/"${SHMOUNT}".log
    echo
}

logsplitter() {
    sudo bash -c 'cat > /etc/logrotate.d/${SHMOUNT}log' <<EOF
/home/${USER}/logs/"${SHMOUNT}".log {
    daily
    copytruncate
    create 660 ${USER} ${USER}
    dateext
    size=+4096k
    extension log
    rotate ${LGKP}
    delaycompress
}
EOF
}

detect_system

checkport() {
    echo "${GREEN}checking if port ${RCLONE_RC_PORT} is already in use"
    if [[ $(sudo lsof -i:"${RCLONE_RC_PORT}") != *localhost* ]]; then
        echo "${YELLOW}port ${RCLONE_RC_PORT} is available and will be used"
        echo
        echo "${YELLOW}Preparing smount service"
        echo
    else
        RCLONE_RC_PORT=$((RCLONE_RC_PORT + 1))
        echo "${BGREEN}setting port to ${RCLONE_RC_PORT}"
        checkport
    fi
}

sysdmaker() {
    sudo bash -c 'cat > /etc/systemd/system/${SHMOUNT}.service' <<EOF
# /etc/systemd/system/"${SHMOUNT}".service
[Unit]
Description=${SHMOUNT} RCUnion Mount
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
          --log-level=${LGLVL} \\
          --log-file=/home/${USER}/logs/${SHMOUNT}.log \\
          ${SHMOUNT}: ${MNTPNT}

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
    sudo systemctl enable "${SHMOUNT}".service
}

# change start to restart to test if existing mount restarts correctly
# perhaps check for existing file first instead of restart
firehol() {
    enabler
    sudo systemctl daemon-reload
    echo
    echo "${YELLOW}starting the ${SHMOUNT} service, be patient. If you have a big one this might take a while."
    sudo systemctl restart "${SHMOUNT}".service
    echo
}

cloudboxmsg() {
    if [ $CBI = true ]; then
        echo "${GREEN}--------------------"
        echo "in cloudbox installations the union can be included in mergerfs directory"
        echo "/etc/systemd/system/mergerfs.service can be edited to include ${SHMOUNT} eg:-"
        echo "${RESET}  /mnt/local=RW:/mnt/remote=NC:/mnt/${SHMOUNT}:NC /mnt/unionfs"
        echo "${GREEN}--------------------"
        echo
    else
        echo
    fi
}

muhfacts() {
    echo "${YELLOW}--------------------"
    echo "${RESET}User is:          ${YELLOW}${USER}"
    echo "${RESET}SA Path:          ${YELLOW}${SAPATH}"
    echo "${RESET}Cache size:       ${YELLOW}${VFSCACHESIZE}"
    echo "${RESET}Mount Name:       ${YELLOW}${SHMOUNT}"
    echo "${RESET}Mount Point:      ${YELLOW}${MNTPNT}"
    echo "--------------------"
}

exiting() {
    echo "${YELLOW}"
    echo "    **************************"
    echo "    * ---------------------- *"
    echo "    * - install Completed! - *"
    echo "    * ---------------------- *"
    echo "    **************************"
    echo "${RESET}"
    echo
}

smounted() {
    echo "  ${BOLD}${YELLOW}"
    echo "          ${SHMOUNT}"
    echo "     smount smounty smounted"
    echo "    **************************"
    echo
    echo "  ${RESET}please report issues"
}

#________ SET LIST

clear
echo
rooter
systemd_detection
betachek

myball

universals

# check for existing smount service name and rclone entry to avoid overwriting

muhfacts
carryon
mkmounce
logsplitter
rclonecheck
fusebox
echo "${YELLOW}add your first drive"
driveadd
echo
echo "${RESET}Drives added:   ${YELLOW}${DRVLIST}"
rcunionconfig
sleep 1
rclonecheckmate
cloudboxer
checkport
sysdmaker
firehol
cloudboxmsg
exiting

# Back up vars to file?
# echo "${SHMOUNT}" > /$PWD/${SHMOUNT}.txt
smounted
