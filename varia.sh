#!/bin/bash
set -e

# VARIABLES
USER=max
GROUP=max
SET_DIR="./sets/"
SA_PATH=/opt/sa/mounts
MOUNT_DIR=/mnt/sharedrives
MSTYLE=aio
BINARY=/usr/bin/rclone
RW_MDIR='/mnt/local'
RO_MDIR='/mnt/sharedrives/sd*'
SECNDRO_MDIR='/mnt/sharedrives/td*'
MDIR='/mnt/mergerfs'
MERGERSERVICE=shmerger
CNAME=shmount
MPORT=5575
CPORT=1

# FUNCTIONS

check_firstrun () {
  ( [ -e "sa.count" ] || echo ${CPORT} > "sa.count" )
  ( [ -e "port_no.count" ] || echo ${MPORT} > "port_no.count" )
}

export_vars () {
  export myuser=${USER} mygroup=${GROUP} mysapath=${SA_PATH} mystyle=${MSTYLE} mycname=${CNAME} mybinary=${BINARY} myrwmdir=${RW_MDIR} myromdir=${RO_MDIR} mymdir=${MDIR} mymergerservice=${MERGERSERVICE}
}

get_port_no_count () {
  read count < port_no.count
  echo $(( count + 1 )) > port_no.count
}

get_sa_count () {
  read sacount < sa.count
  echo $(( sacount + 1 )) > sa.count
}

aio () {
  envsubst '${myuser},${mygroup},${mysapath},${mybinary}' <./input/aio@.service >./output/aio@.service
  envsubst '${myuser},${mygroup}' <./input/primer@.service >./output/aio.primer@.service
  envsubst '${myuser},${mygroup},${MSTYLE}' <./input/primer@.timer >./output/aio.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir}' <./input/smerger.service >./output/aio.merger.service
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
  # create
  envsubst '${myuser},${mygroup},${my_sa_path},${mybinary}' <./input/cst@.service >./output/${CNAME}@.service
  envsubst '${myuser},${mygroup}' <./input/primer@.service >./output/${CNAME}.primer@.service
  envsubst '${myuser},${mygroup},${MSTYLE}' <./input/primer@.timer >./output/${CNAME}.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir}' <./input/smerger.service >./output/${CNAME}.merger.service
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
      RCLONE_RC_PORT=${count}
      SOURCE_REMOTE=${name}:
      DESTINATION_DIR=$MOUNT_DIR/${name}/
      SA_PATH=${SA_PATH}/
      ";
      echo "${conf}" > "./sharedrives/${name}.conf"
    done
}

make_shmount.conf () {
  sed '/^\s*#.*$/d' ${SET_DIR}/$1|\
  while read -r name driveid;do 
  get_sa_count
  echo "
[${name}]
type = drive
scope = drive
server_side_across_configs = true
team_drive = ${driveid}
service_account_file = "${SA_PATH}/${sacount}.json"
service_account_file_path = ${SA_PATH}
">> "./config/smount.conf"
  done; 
}

make_starter () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl enable ${MSTYLE}@${name}.service && sudo systemctl enable ${MSTYLE}.primer@${name}.service">>${MSTYLE}.starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}@${name}.service">>${MSTYLE}.starter.sh
    done
}

make_restart () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl restart ${MSTYLE}@${name}.service">>${MSTYLE}.restart.sh
    done
}

make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}.primer@${name}.service">>${MSTYLE}.primer.sh
    done
}

make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl stop ${MSTYLE}@${name}.service && sudo systemctl stop ${MSTYLE}.primer@${name}.service">>${MSTYLE}.kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl disable ${MSTYLE}@${name}.service && sudo systemctl disable ${MSTYLE}.primer@${name}.service">>${MSTYLE}.kill.sh
    done
}

# Make Dirs
sudo mkdir -p /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output
sudo chown -R ${USER}:${GROUP} /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output
sudo chmod -R 775 /opt/smount/sharedrives /opt/smount/backup /opt/smount/scripts /opt/smount/config /opt/smount/output

# rename existing starter and kill scripts if present can we make CNAME = MSTYLE for making scripts and moving?
#   ( [ -e "sa.count" ] || echo ${CPORT} > "sa.count" )
make_backups () {
( [ -e "${MSTYLE}.starter.sh" ] && mv ${MSTYLE}.starter.sh ./backup/${MSTYLE}.starter`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1 )
( [ -e "${MSTYLE}.primer.sh" ] && mv ${MSTYLE}.primer.sh ./backup/${MSTYLE}.primer`date +%Y%m%d%H%M%S`.sh )
( [ -e "${MSTYLE}.kill.sh" ] && mv ${MSTYLE}.kill.sh ./backup/${MSTYLE}.kill`date +%Y%m%d%H%M%S`.sh )
( [ -e "${MSTYLE}.restart.sh" ] && mv ${MSTYLE}.restart.sh ./backup/${MSTYLE}.restart`date +%Y%m%d%H%M%S`.sh )
}
# enable new services TEST LATER if we can pull it out of the mount functions and condense to this
# sudo systemctl enable ${MSTYLE}@.service
# sudo systemctl enable ${MSTYLE}.primer@.service
# sudo systemctl enable ${MSTYLE}.primer@.timer

# Function calls # 
check_firstrun
make_backups
export_vars
${MSTYLE} $1
make_shmount.conf $1
make_config $1
make_starter $1
make_primer $1
make_vfskill $1
make_restart $1

# daemon reload
#sudo systemctl daemon-reload
# permissions
#chmod +x ${MSTYLE}.starter.sh ${MSTYLE}.primer.sh ${MSTYLE}.kill.sh ${MSTYLE}.restart.sh
# fire the starter
#./${MSTYLE}.starter.sh  
# fire the primer but hide it so we dont get bored waiting.
#nohup sh ./${MSTYLE}.primer.sh &>/dev/null &
# consider echo ${WARNINGS} if present.
echo "${MSTYLE} mount script completed."
#eof
