#!/usr/bin/env bash
set -e

USER=max
GROUP=max
INSPTH=/opt/smount
SET_DIR=/opt/smountsets/
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
  envsubst '${myuser},${mygroup},${mysapath},${mybinary},${myinspth}' <${INSPTH}/input/aio@.service >${INSPTH}/output/aio@.service
  envsubst '${myuser},${mygroup},${mybinary},${mystyle},${myinspth}' <${INSPTH}/input/primer@.service >${INSPTH}/output/aio.primer@.service
  envsubst '${myuser},${mygroup},${mystyle}' <${INSPTH}/input/primer@.timer >${INSPTH}/output/aio.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir},${myscndromdir}' <${INSPTH}/input/smerger.service >${INSPTH}/output/aio.merger.service
  # place
  sudo bash -c 'cp ${INSPTH}/output/aio@.service /etc/systemd/system/aio@.service'
  sudo bash -c 'cp ${INSPTH}/output/aio.primer@.service /etc/systemd/system/aio.primer@.service'
  sudo bash -c 'cp ${INSPTH}/output/aio.primer@.timer /etc/systemd/system/aio.primer@.timer'
  # enable
  sudo systemctl enable aio@.service
  sudo systemctl enable aio.primer@.service
  sudo systemctl enable aio.primer@.timer
}

cst () {
   export MSTYLE=${CNAME},mystyle=${CNAME}
  # create
  envsubst '${myuser},${mygroup},${mysapath},${mybinary},${myinspth},${mycname}' <${INSPTH}/input/cst@.service >${INSPTH}/output/${CNAME}@.service
  envsubst '${myuser},${mygroup},${mybinary},${mystyle},${myinspth},${mycname}' <${INSPTH}/input/cst.primer@.service >${INSPTH}/output/${CNAME}.primer@.service
  envsubst '${myuser},${mygroup}' <${INSPTH}/input/primer@.timer >${INSPTH}/output/${CNAME}.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir},${myscndromdir}' <${INSPTH}/input/smerger.service >${INSPTH}/output/${CNAME}.merger.service
  # place
  sudo bash -c 'cp ${INSPTH}/output/${CNAME}@.service /etc/systemd/system/${CNAME}@.service'
  sudo bash -c 'cp ${INSPTH}/output/${CNAME}.primer@.service@.service /etc/systemd/system/${CNAME}.primer@.service'
  sudo bash -c 'cp ${INSPTH}/output/${CNAME}.primer@.timer /etc/systemd/system/${CNAME}.primer@.timer'
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
      echo "${conf}" > "${INSPTH}/sharedrives/${name}.conf"
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
">> "${INSPTH}/config/smount.conf"
  done; 
}

make_starter () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl enable ${MSTYLE}@${name}.service && sudo systemctl enable ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}@${name}.service">>${INSPTH}/scripts/${MSTYLE}.starter.sh
    done
}

make_restart () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl restart ${MSTYLE}@${name}.service">>${INSPTH}/scripts/${MSTYLE}.restart.sh
    done
}

make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.primer.sh
    done
}

make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl stop ${MSTYLE}@${name}.service && sudo systemctl stop ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl disable ${MSTYLE}@${name}.service && sudo systemctl disable ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.kill.sh
    done
}

# Make Dirs and permissions
sudo mkdir -p ${INSPTH}/{sharedrives,backup,scripts,config,output}
sudo chown -R ${USER}:${GROUP} ${INSPTH}/{sharedrives,backup,scripts,config,output}
sudo chmod -R 775 ${INSPTH}/{sharedrives,backup,scripts,config,output}

# rename existing starter and kill scripts if present can we make CNAME = MSTYLE for making scripts and moving?
make_backups () {
( [ -e "${INSPTH}/scripts/${MSTYLE}.starter.sh" ] && mv "${INSPTH}/scripts/${MSTYLE}.starter.sh" ${INSPTH}/backup/${MSTYLE}.starter`date +%Y%m%d%H%M%S`.sh )
( [ -e "${INSPTH}/scripts/${MSTYLE}.primer.sh" ] && mv "${INSPTH}/scripts/${MSTYLE}.primer.sh" ${INSPTH}/backup/${MSTYLE}.primer`date +%Y%m%d%H%M%S`.sh )
( [ -e "${INSPTH}/scripts/${MSTYLE}.kill.sh" ] && mv "${INSPTH}/scripts/${MSTYLE}.kill.sh" ${INSPTH}/backup/${MSTYLE}.kill`date +%Y%m%d%H%M%S`.sh )
( [ -e "${INSPTH}/scripts/${MSTYLE}.restart.sh" ] && mv "${INSPTH}/scripts/${MSTYLE}.restart.sh" ${INSPTH}/backup/${MSTYLE}.restart`date +%Y%m%d%H%M%S`.sh )
( [ -e "${INSPTH}/config/smount.conf" ] && cp "${INSPTH}/config/smount.conf" ${INSPTH}/backup/smount`date +%Y%m%d%H%M%S`.conf )
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
chmod +x ${INSPTH}/scripts/*.sh
# fire the starter
#${INSPTH}/scripts/${MSTYLE}.starter.sh  
# fire the primer but hide it so we dont get bored waiting.
#nohup sh ${INSPTH}/scripts/${MSTYLE}.primer.sh &>/dev/null &
# consider echo ${WARNINGS} if present.
echo "${MSTYLE} mount script completed."
#eof
