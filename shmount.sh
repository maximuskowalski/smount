#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

#________ VARS DO NOT EDIT

SDNAME=             # a share drive rclone config entry
SDID=               # a share drive ID
SAPATH=             # service account path "/opt/sa/mounts"
DRVLIST=            # list of drives configured
RCUNAME=            # name for rclone union config entry
STRUNION=           # union upstream string (accumulates during drive additions)
VFSCACHESIZE=       # maximum size for VFS cache
STRMERGER=          # merger string
RCLONE_RC_PORT=5575 # initial port for VFS
RCI=true            # install or update Rclone?
RCB=false           # rclone beta?
CBI=false           # cloudbox install?

MNTPNT=/mnt/$RCUNAME
FREESPACE=$(df -h --output=avail /home/"$USER")
RECSPACE=$(("${FREESPACE//[^0-9]/}" * 80 / 100))
VERSION=$(rclone --version 2>>errors | head -n 1)

BOLD="$(tput bold)"        # bold
RESET="$(tput sgr0)"       # reset
RED="$(tput setaf 1)"      # red
GREEN="$(tput setaf 2)"    # green
YELLOW="$(tput setaf 3)"   # yellow
BRED="$(tput setaf 9)"     # bright red
BGREEN="$(tput setaf 10)"  # bright green
BYELLOW="$(tput setaf 11)" # bright yellow

#________ FUNCTIONS

rooter() {
    if [ "$(whoami)" = root ]; then
        echo "$BRED Running as root or with sudo is not supported. Exiting.$RESET"
        exit
    fi
}

cloudboxer() {
    read -r -p "${YELLOW}Is this a cloudbox install?  [Y/N] :$RESET" i
    case $i in
    [yY])
        echo -e "${YELLOW}mergerfs content line will be displayed after smounting has occured"
        CBI="true"
        # readmergerfs
        ;;
    [nN])
        echo -e "${YELLOW}thank you"
        RCI="false"
        ;;
    esac
}

betachek() {
    if
        rclone --version 2>>errors | head -n 1 | grep -q 'beta'
    then
        echo you have "$VERSION" installed
        echo
        echo "${YELLOW}this script will not work with rclone beta"
        echo "select beta install to have smount"
        echo "temporarily install rclone stable to complete"
        echo "the config process and update to beta when done"
        echo
        rcloneinstall
    else
        rcloneinstall
    fi
}

rcloneinstall() {
    read -r -p "${YELLOW}Would you like to install or update rclone?  [Y/N] :$RESET" i
    case $i in
    [yY])
        echo -e "${YELLOW}rclone will be installed"
        RCI="true"
        rclonebetaq
        ;;
    [nN])
        echo -e "${YELLOW}fine"
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
    echo "${YELLOW}Do you want rclone beta or stable?$RESET"
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
    ([ "$RCI" = true ] && rclonesetup) || :
}

rclonecheckmate() {
    ([ "$RCB" = true ] && rclonebaker) || :
}

rclonesetup() {
    if [ "$RCB" = true ]; then
        echo "${YELLOW}Installing rclone stable, rclone beta will be installed after config$GREEN"
        curl https://rclone.org/install.sh | sudo bash || :
        clear
        echo "${YELLOW}rclone stable installed for configuration bug"
        echo "rclone beta will be installed after configuration is completed"
        echo
    else
        echo "${GREEN}Installing rclone stable$GREEN"
        curl https://rclone.org/install.sh | sudo bash || :
        VERSION=$(rclone --version 2>>errors | head -n 1)
        clear
        echo "${YELLOW}rclone stable installed"
        echo "$VERSION"
        echo
    fi
}

rclonebaker() {
    echo "${YELLOW}Now installing rclone beta$GREEN"
    curl https://rclone.org/install.sh | sudo bash -s beta || :
    VERSION=$(rclone --version 2>>errors | head -n 1)
    clear
    echo "${YELLOW}rclone beta installed"
    echo "$VERSION"
    echo
}

universals() {
    echo
    echo "${YELLOW}Please enter service account file path, for example /opt/sa/mounts :$RESET"
    read -r SAPATH
    echo
    echo "${YELLOW}Please enter name to use for rclone union mount, eg reunion :$RESET"
    read -r RCUNAME
    MNTPNT="/mnt/$RCUNAME"
    echo
    echo "${BYELLOW}You currently have $FREESPACE,"
    echo "${BYELLOW}DO NOT use all of this for cache."
    echo "$BYELLOW""${BOLD}"Suggest using no more than "$RED""${RECSPACE}"G "$RESET"
    echo
    echo "${YELLOW}""Please enter cache max size +G (ex ${RESET}50G$YELLOW)""$RESET"
    read -r VFSCACHESIZE
    echo
}

driveadd() {
    echo
    echo "${YELLOW}Please enter a share drive name :$RESET"
    read -r SDNAME
    echo
    echo "${YELLOW}Please enter ""$SDNAME"" Drive ID, for example ${RESET}0A1xxxxxxxxxUk9PVA $YELLOW:$RESET"
    read -r "SDID"
    SAFILE="$(shuf -n1 -e "$SAPATH"/*.json)"
    driveconfig
    arewedone
}

arewedone() {
    read -r -p "${YELLOW}Would you like to add another drive?  [Y/N] : $RESET" i
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
    STRUNION="$STRUNION$SDNAME: "
    DRVLIST="$DRVLIST$SDNAME "
    STRMERGER="$STRMERGER$SDNAME: "
    sdrmconfig
}

fusebox() {
    # check and fix fuse.conf if needed
    sudo sed -i -e "s/\#user_allow_other/user_allow_other/" "/etc/fuse.conf" || :
}

sdrmconfig() {
    echo
    echo "${YELLOW}"creating rclone config for "$SDNAME" with ID "$SDID" "$RESET"
    echo
    rclone config create "$SDNAME" drive scope drive server_side_across_configs true team_drive "$SDID" service_account_file "$SAFILE"
    echo
}

rcunionconfig() {
    echo "${YELLOW}"creating "$RCUNAME" rclone union config with default policy options.
    echo "ACTION:  epall"
    echo "CREATE:  epmfs"
    echo "SEARCH:  ff"
    echo "$RESET"
    rclone config create "$RCUNAME" union upstreams "$STRUNION"
}

carryon() {
    echo "${YELLOW}Continue with installation?$RESET"
    select yn in "Continue" "Exit"; do
        case $yn in
        Continue) break ;;
        Exit) exit 0 ;;
        esac
    done

}

mkmounce() {
    sudo mkdir -p "$MNTPNT" && sudo chown "$USER":"$USER" "$MNTPNT"
    mkdir -p /home/"$USER"/logs && touch /home/"$USER"/logs/smount.log
}

checkport() {
    echo "${GREEN}checking if port $RCLONE_RC_PORT is already in use"
    if [[ $(sudo lsof -i:"${RCLONE_RC_PORT}") != *localhost* ]]; then
        echo "${YELLOW}port $RCLONE_RC_PORT is available and will be used"
    else
        RCLONE_RC_PORT=$((RCLONE_RC_PORT + 1))
        echo "${BGREEN}setting port to $RCLONE_RC_PORT"
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
    if [ "$CBI" = true ]; then
        echo "$GREEN--------------------"
        echo "in cloudbox installations the union can be included in mergerfs directory"
        echo "/etc/systemd/system/mergerfs.service can be edited to include $RCUNAME eg:-"
        echo "$RESET  /mnt/local=RW:/mnt/remote=NC:/mnt/$RCUNAME:NC /mnt/unionfs"
        echo "$GREEN--------------------"
        echo
    else
        echo
    fi
}

exiting() {

    echo "$YELLOW"
    echo "    **************************"
    echo "    * ---------------------- *"
    echo "    * - install Completed! - *"
    echo "    * ---------------------- *"
    echo "    **************************"
    echo "$RESET"
    echo
}

#________ SET LIST

clear
echo
rooter
betachek
universals
echo "$YELLOW--------------------"
echo "${RESET}User is:          $YELLOW$USER"
echo "${RESET}SA Path:          $YELLOW$SAPATH"
echo "${RESET}Cache size:       $YELLOW$VFSCACHESIZE"
echo "${RESET}Mount Name:       $YELLOW$RCUNAME"
echo "${RESET}Mount Point:      $YELLOW$MNTPNT"
echo "--------------------"
carryon
mkmounce
echo
rclonecheck
echo
fusebox
echo "${YELLOW}add your first drive"
driveadd
echo
echo "${RESET}Drives added:   $YELLOW$DRVLIST"
echo
rcunionconfig
sleep 1
rclonecheckmate
echo
cloudboxer
echo
checkport
echo
echo "${YELLOW}Preparing smount service"
sysdmaker
enabler
sudo systemctl daemon-reload
echo
echo "${YELLOW}starting the $RCUNAME service, be patient. If you have a big one this might take a while."
sudo systemctl start smount.service
# nohup sh sudo systemctl start smount.service &>/dev/null &
echo
cloudboxmsg
exiting
echo "  $BOLD$YELLOW$RCUNAME smount smounty smounted"
echo
echo '           ᕙ(⇀‸↼‶)ᕗ'
echo
echo "  ${RESET}please consider reporting any issues"
