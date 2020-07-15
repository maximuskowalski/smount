#!/usr/bin/env bash
set -euo pipefail
# VARIABLES
# User/Group Information
# readonly DETECTED_PUID=${SUDO_UID:-$UID}
# readonly DETECTED_UNAME=$(id -un "${DETECTED_PUID}" 2> /dev/null || true)
# readonly DETECTED_PGID=$(id -g "${DETECTED_PUID}" 2> /dev/null || true)
# export DETECTED_PGID
# readonly DETECTED_UGROUP=$(id -gn "${DETECTED_PUID}" 2> /dev/null || true)
# export DETECTED_UGROUP
# readonly DETECTED_HOMEDIR=$(eval echo "~${DETECTED_UNAME}" 2> /dev/null || true)


USER=max # user name
GROUP=max # group name
SET_DIR="./sets/" # set file dir [ REMOVE VARIABLE ]
SA_PATH=/opt/sa/mounts # sharedrive mounting service accounts [ NO TRAILING SLASH ]
MOUNT_DIR=/mnt/sharedrives # sharedrive mount [ NO TRAILING SLASH ]
MSTYLE=aio # OPTIONS: aio,strm,csd,cst [ All-In-One | Streamer | Cloudseed | Custom ] (Simplify while we work out VARIABLES)

# MergerFS Variables
RW_LOCAL='/mnt/local' # read write dir for merger
UMOUNT_DIR='/mnt/sharedrives/sd_*' # if common prefix wildcard is possible (sd_* = sd_tv sd_movies) usually drive names in set file
MERGER_DIR='/mnt/unionfs' # if this is a non empty dir or already in use by another merger service a reboot is required.

# TESTING
MERGERNAME=shmerger # The name of your merger service [not working]
CNAME=shmount # The name of your new custom mount service [not working]
BINARY=/opt/smount/rclone_gclone # full path of rclone binary to use.

# count fuctions

# Add a check for existing file, if none then create and assign '5575' or a new ${VAR}. Then we can ignore our existing counters and not break with a git pull.

get_port_no_count () {
  read count < port_no.count
  echo $(( count + 1 )) > port_no.count
}

# Add a check for existing file, if none then create and assign '1' or a new ${VAR}, do not let it create and be 0. Maybe we can do this with maths. It might even be possible to read a random .json file from a supplied dir. This would allow for non numeric names, non sequential names.

get_sa_count () {
  read sacount < sa.count
  echo $(( sacount + 1 )) > sa.count
}

## mount functions

aio () {
  # create
  export myuser=${USER} mygroup=${GROUP} myrwloc=${RW_LOCAL} my_umnt_dir=${UMOUNT_DIR} my_merger=${MERGER_DIR} mystyle=${MSTYLE} my_sa_path=${SA_PATH} mybinary=${BINARY} mycstnm=${CNAME} mymergernm=${MERGERNAME}
  envsubst '${myuser},${mygroup},${my_sa_path},${mybinary}' <./input/aio@.service >./output/aio@.service
  envsubst '${myuser},${mygroup}' <./input/primer@.service >./output/aio.primer@.service
  envsubst '${myuser},${mygroup},${MSTYLE}' <./input/primer@.timer >./output/aio.primer@.timer
  envsubst '${myrwloc},${my_umnt_dir},${my_merger}' <./input/smerger.service >./output/aio.merger.service
  # place
  sudo bash -c 'cp ./output/aio@.service /etc/systemd/system/aio@.service'
  sudo bash -c 'cp ./output/aio.primer@.service /etc/systemd/system/aio.primer@.service'
  sudo bash -c 'cp ./output/aio.primer@.timer /etc/systemd/system/aio.primer@.timer'
  # enable
  sudo systemctl enable aio@.service
  sudo systemctl enable aio.primer@.service
  sudo systemctl enable aio.primer@.timer
}

cst () {
  export myuser=${USER} mygroup=${GROUP} myrwloc=${RW_LOCAL} my_umnt_dir=${UMOUNT_DIR} my_merger=${MERGER_DIR} mystyle=${MSTYLE} my_sa_path=${SA_PATH} mybinary=${BINARY} mycstnm=${CNAME} mymergernm=${MERGERNAME}
  # create
  envsubst '${myuser},${mygroup},${my_sa_path},${mybinary}' <./input/cst@.service >./output/${CNAME}@.service
  envsubst '${myuser},${mygroup}' <./input/primer@.service >./output/cst.primer@.service
  envsubst '${myuser},${mygroup},${MSTYLE}' <./input/primer@.timer >./output/${CNAME}.primer@.timer
  envsubst '${myrwloc},${my_umnt_dir},${my_merger}' <./input/smerger.service >./output/${CNAME}.merger.service
  # place
  sudo bash -c 'cp ./output/cst@.service /etc/systemd/system/${CNAME}@.service'
  sudo bash -c 'cp ./output/cst.primer@.service /etc/systemd/system/${CNAME}.primer@.service'
  sudo bash -c 'cp ./output/cst.primer@.timer /etc/systemd/system/${CNAME}.primer@.timer'
  # enable
  sudo systemctl enable ${CNAME}@.service
  sudo systemctl enable ${CNAME}.primer@.service
  sudo systemctl enable ${CNAME}.primer@.timer
}

make_config () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      get_port_no_count
      conf="
      RCLONE_RC_PORT=$count
      SOURCE_REMOTE=$name:
      DESTINATION_DIR=$MOUNT_DIR/$name/
      SA_PATH=$SA_PATH/
      ";
      echo "$conf" > "./sharedrives/$name.conf"
    done
}

# We want to make this check for and read an exisiting file and check if sharedtive [name] is already configured - if so maybe edit the existing config or maybe spit out warnings at the end about double config entries.
make_shmount.conf () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
  while read -r name driveid;do 
  get_sa_count
  echo "
[$name]
type = drive
scope = drive
server_side_across_configs = true
team_drive = $driveid
service_account_file = "$SA_PATH/$sacount.json"
service_account_file_path = $SA_PATH
">> "./config/smount.conf"
  done; }

# Move outputs to a scripts directory to clean up.
# We should make this check for an exisiting file - do we overwrite or append?
make_starter () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl enable ${MSTYLE}@$name.service && sudo systemctl enable ${MSTYLE}.primer@$name.service">>${MSTYLE}.starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}@$name.service">>${MSTYLE}.starter.sh
    done
}

# We should make this check for an exisiting file - do we overwrite or append?
make_restart () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl restart ${MSTYLE}@$name.service">>${MSTYLE}.restart.sh
    done
}

# We should make this check for an exisiting file - do we overwrite or append?
make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}.primer@$name.service">>${MSTYLE}.primer.sh
    done
}

# We should make this check for an exisiting file - do we overwrite or append?
make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl stop ${MSTYLE}@$name.service && sudo systemctl stop ${MSTYLE}.primer@$name.service">>${MSTYLE}.kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl disable ${MSTYLE}@$name.service && sudo systemctl disable ${MSTYLE}.primer@$name.service">>${MSTYLE}.kill.sh
    done
}



# Make Dirs
sudo mkdir -p /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output
sudo chown -R $USER:$GROUP /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output
sudo chmod -R 775 /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output

# rename existing starter and kill scripts if present
mv ${MSTYLE}.starter.sh ./backup/${MSTYLE}.starter`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1
mv ${MSTYLE}.primer.sh ./backup/${MSTYLE}.primer`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1
mv ${MSTYLE}.kill.sh ./backup/${MSTYLE}.kill`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1
mv ${MSTYLE}.restart.sh ./backup/${MSTYLE}.restart`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1

# enable new services TEST LATER if we can pull it out of the mount functions and condense to this
# sudo systemctl enable ${MSTYLE}@.service
# sudo systemctl enable ${MSTYLE}.primer@.service
# sudo systemctl enable ${MSTYLE}.primer@.timer

# Function calls # 
${MSTYLE} $1
make_shmount.conf $1
make_config $1
make_starter $1
make_primer $1
make_vfskill $1
make_restart $1

# daemon reload
sudo systemctl daemon-reload
# permissions
chmod +x ${MSTYLE}.starter.sh ${MSTYLE}.primer.sh ${MSTYLE}.kill.sh ${MSTYLE}.restart.sh
# fire the starter
./${MSTYLE}.starter.sh  
# fire the primer but hide it so we dont get bored waiting.
nohup sh ./${MSTYLE}.primer.sh &>/dev/null &
# consider echo ${WARNINGS} if present.
echo "${MSTYLE} mount script completed."
#eof
