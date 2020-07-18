#!/bin/bash
set -e

USER=max
GROUP=max
INSPTH=/opt/smount
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

check_firstrun () {
  ( [ -e "sa.count" ] || echo ${CPORT} > "sa.count" )
  ( [ -e "port_no.count" ] || echo ${MPORT} > "port_no.count" )
}

export_vars () {
  export myuser=${USER} mygroup=${GROUP} myinspth=${INSPTH} mysapath=${SA_PATH} mystyle=${MSTYLE} mycname=${CNAME} mybinary=${BINARY} myrwmdir=${RW_MDIR} myromdir=${RO_MDIR} myscndromdir=${SECNDRO_MDIR} mymdir=${MDIR} mymergerservice=${MERGERSERVICE}
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
  envsubst '${myuser},${mygroup},${mysapath},${mybinary},${myinspth}' <./input/aio@.service >./output/aio@.service
  envsubst '${myuser},${mygroup},${mybinary},${mystyle},${myinspth}' <./input/primer@.service >./output/aio.primer@.service
  envsubst '${myuser},${mygroup},${mystyle}' <./input/primer@.timer >./output/aio.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir},${myscndromdir}' <./input/smerger.service >./output/aio.merger.service
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
   export mystyle=${CNAME}
  # create
  envsubst '${myuser},${mygroup},${mysapath},${mybinary},${myinspth},${mycname}' <./input/cst@.service >./output/${CNAME}@.service
  envsubst '${myuser},${mygroup},${mybinary},${mystyle},${myinspth},${mycname}' <./input/cst.primer@.service >./output/${CNAME}.primer@.service
  envsubst '${myuser},${mygroup}' <./input/primer@.timer >./output/${CNAME}.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir},${myscndromdir}' <./input/smerger.service >./output/${CNAME}.merger.service
  # place
  sudo bash -c 'cp ./output/${CNAME}@.service /etc/systemd/system/${CNAME}@.service'
  sudo bash -c 'cp ./output/${CNAME}.primer@.service@.service /etc/systemd/system/${CNAME}.primer@.service'
  sudo bash -c 'cp ./output/${CNAME}.primer@.timer /etc/systemd/system/${CNAME}.primer@.timer'
  # enable
  sudo systemctl enable ${CNAME}@.service
  sudo systemctl enable ${CNAME}.primer@.service
  sudo systemctl enable ${CNAME}.primer@.timer
  # need to fix starters to cname not mstyle and backups.
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
      echo "sudo systemctl enable ${MSTYLE}@${name}.service && sudo systemctl enable ${MSTYLE}.primer@${name}.service">>./scripts/${MSTYLE}.starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}@${name}.service">>./scripts/${MSTYLE}.starter.sh
    done
}

make_restart () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl restart ${MSTYLE}@${name}.service">>./scripts/${MSTYLE}.restart.sh
    done
}

make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}.primer@${name}.service">>./scripts/${MSTYLE}.primer.sh
    done
}

make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl stop ${MSTYLE}@${name}.service && sudo systemctl stop ${MSTYLE}.primer@${name}.service">>./scripts/${MSTYLE}.kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl disable ${MSTYLE}@${name}.service && sudo systemctl disable ${MSTYLE}.primer@${name}.service">>./scripts/${MSTYLE}.kill.sh
    done
}

# Make Dirs
mkdir ./{sharedrives,backup,scripts,config,output}
sudo mkdir -p ./{sharedrives,backup,scripts,config,output}
sudo chown -R ${USER}:${GROUP} ./{sharedrives,backup,scripts,config,output}
sudo chmod -R 775 ./{sharedrives,backup,scripts,config,output}

# rename existing starter and kill scripts if present can we make CNAME = MSTYLE for making scripts and moving?
#   ( [ -e "sa.count" ] || echo ${CPORT} > "sa.count" )
make_backups () {
( [ -e "./scripts/${MSTYLE}.starter.sh" ] && mv "./scripts/${MSTYLE}.starter.sh" ./backup/${MSTYLE}.starter`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1 )
( [ -e "./scripts/${MSTYLE}.primer.sh" ] && mv "./scripts/${MSTYLE}.primer.sh" ./backup/${MSTYLE}.primer`date +%Y%m%d%H%M%S`.sh )
( [ -e "./scripts/${MSTYLE}.kill.sh" ] && mv "./scripts/${MSTYLE}.kill.sh" ./backup/${MSTYLE}.kill`date +%Y%m%d%H%M%S`.sh )
( [ -e "./scripts/${MSTYLE}.restart.sh" ] && mv "./scripts/${MSTYLE}.restart.sh" ./backup/${MSTYLE}.restart`date +%Y%m%d%H%M%S`.sh )
( [ -e "./config/smount.conf" ] && cp "./config/smount.conf" ./backup/smount`date +%Y%m%d%H%M%S`.conf )
}

# enable new services TEST LATER if we can pull it out of the mount functions and condense to this
# sudo systemctl enable ${MSTYLE}@.service
# sudo systemctl enable ${MSTYLE}.primer@.service
# sudo systemctl enable ${MSTYLE}.primer@.timer

# Function calls # 
check_firstrun
export_vars
${MSTYLE} $1
make_backups #after mstyle export
make_shmount.conf $1
make_config $1
make_starter $1
make_primer $1
make_vfskill $1
make_restart $1

# daemon reload
#sudo systemctl daemon-reload
# permissions
#chmod +x ./scripts/${MSTYLE}.starter.sh ./scripts/${MSTYLE}.primer.sh ./scripts/${MSTYLE}.kill.sh ./scripts/${MSTYLE}.restart.sh
# fire the starter
#./scripts/${MSTYLE}.starter.sh  
# fire the primer but hide it so we dont get bored waiting.
#nohup sh ./scripts/${MSTYLE}.primer.sh &>/dev/null &
# consider echo ${WARNINGS} if present.
echo "${MSTYLE} mount script completed."
#eof
