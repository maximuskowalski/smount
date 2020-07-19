#!/usr/bin/env bash
set -euo pipefail
#set -xv
#
USER=max # user name
GROUP=max # group name
MSTYLE=aio # OPTIONS: aio,strm,csd,cst [ All-In-One | Streamer | Cloudseed | Custom ]
CNAME=shmount # name for your custom mount service
INSPTH=/opt/smount # install path
SET_DIR=/opt/smount/sets/ # set files location
SA_PATH=/opt/sa/mounts # service account file locations
MOUNT_DIR=/mnt/sharedrives # where to mount the VFS.
BINARY=/usr/bin/rclone # example /usr/bin/rclone or /opt/crop/rclone_gclone
MPORT=5575 # Starting port for VFS RC
CPORT=1  # Starting service account for smount.conf, independent of rclone.conf
#
#MERGER - example only created.
RW_MDIR='/mnt/local' # read write dir for merger
RO_MDIR='/mnt/sharedrives/sd*' # read only or NC dir for merger
SECNDRO_MDIR='/mnt/sharedrives/td*' # second read only or NC dir for merger
MDIR='/mnt/mergerfs' # merger location
MERGERSERVICE=shmerge # name of your merger service
#
# DO NOT CHANGE
NOW=`date +"%Y-%m-%d-%H-%M-%S"`

check_firstrun () {
  ( [ -e "sa.count" ] || echo ${CPORT} > "sa.count" )
  ( [ -e "port_no.count" ] || echo ${MPORT} > "port_no.count" )
  ( [ -d "${INSPTH}/{sharedrives,backup,scripts,config,output}" ] || make_dirper )
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

  sudo cp ${INSPTH}/output/aio@.service /etc/systemd/system/
  sudo cp ${INSPTH}/output/aio.primer@.service /etc/systemd/system/
  sudo cp ${INSPTH}/output/aio.primer@.timer /etc/systemd/system/
}

cst () {
  export MSTYLE=${CNAME}

  envsubst '${myuser},${mygroup},${mysapath},${mybinary},${myinspth},${mycname}' <${INSPTH}/input/cst@.service >${INSPTH}/output/${CNAME}@.service
  envsubst '${myuser},${mygroup},${mybinary},${mystyle},${myinspth},${mycname}' <${INSPTH}/input/cst.primer@.service >${INSPTH}/output/${CNAME}.primer@.service
  envsubst '${myuser},${mygroup}' <${INSPTH}/input/primer@.timer >${INSPTH}/output/${CNAME}.primer@.timer
  envsubst '${myrwmdir},${myromdir},${mymdir},${myscndromdir}' <${INSPTH}/input/smerger.service >${INSPTH}/output/${CNAME}.merger.service

  sudo cp ${INSPTH}/output/${CNAME}@.service /etc/systemd/system/
  sudo cp ${INSPTH}/output/${CNAME}.primer@.service /etc/systemd/system/
  sudo cp ${INSPTH}/output/${CNAME}.primer@.timer /etc/systemd/system/
}

make_config () {
  sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
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
  sed '/^\s*#.*$/d' ${SET_DIR}/"$1"|\
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
  sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl enable ${MSTYLE}@${name}.service && sudo systemctl enable ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}@${name}.service">>${INSPTH}/scripts/${MSTYLE}.starter.sh
    done
}

make_restart () {
  sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl restart ${MSTYLE}@${name}.service">>${INSPTH}/scripts/${MSTYLE}.restart.sh
    done
}

make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl start ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.primer.sh
    done
}

make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl stop ${MSTYLE}@${name}.service && sudo systemctl stop ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/"$1"|\
    while read -r name other;do
      echo "sudo systemctl disable ${MSTYLE}@${name}.service && sudo systemctl disable ${MSTYLE}.primer@${name}.service">>${INSPTH}/scripts/${MSTYLE}.kill.sh
    done
}

make_dirper () {
    sudo mkdir -p ${INSPTH}/{sharedrives,backup,scripts,config,output}
    sudo chown -R ${USER}:${GROUP} ${INSPTH}/{sharedrives,backup,scripts,config,output}
    sudo chmod -R 775 ${INSPTH}/{sharedrives,backup,scripts,config,output}
}

make_backups () {
    [ ! -f "${INSPTH}/scripts/${MSTYLE}.starter.sh" ] || mv "${INSPTH}/scripts/${MSTYLE}.starter.sh" "${INSPTH}/backup/${MSTYLE}.starter.$(NOW).sh"
    [ ! -f "${INSPTH}/scripts/${MSTYLE}.primer.sh" ] || mv "${INSPTH}/scripts/${MSTYLE}.primer.sh" "${INSPTH}/backup/${MSTYLE}.primer.$(NOW).sh"
    [ ! -f "${INSPTH}/scripts/${MSTYLE}.kill.sh" ] || mv "${INSPTH}/scripts/${MSTYLE}.kill.sh" "${INSPTH}/backup/${MSTYLE}.kill.$(NOW).sh"
    [ ! -f "${INSPTH}/scripts/${MSTYLE}.restart.sh" ] || mv "${INSPTH}/scripts/${MSTYLE}.restart.sh" "${INSPTH}/backup/${MSTYLE}.restart.$(NOW).sh"
    [ ! -f "${INSPTH}/config/smount.conf" ] || cp "${INSPTH}/config/smount.conf" "${INSPTH}/backup/smount.$(NOW).conf"
}

enabler () {
    sudo systemctl enable ${MSTYLE}@.service
    sudo systemctl enable ${MSTYLE}.primer@.service
    sudo systemctl enable ${MSTYLE}.primer@.timer
}

execer () {
    chmod +x ${INSPTH}/scripts/$MSTYLE.starter.sh ${INSPTH}/scripts/$MSTYLE.primer.sh ${INSPTH}/scripts/$MSTYLE.kill.sh ${INSPTH}/scripts/$MSTYLE.restart.sh
}


#####
check_firstrun
export_vars
echo "building"
${MSTYLE} "$1"
enabler
echo "enabled"
make_backups
echo "backup ok"
make_shmount.conf "$1"
make_config "$1"
echo "configured"
make_starter "$1"
make_primer "$1"
make_vfskill "$1"
make_restart "$1"
execer

#
sudo systemctl daemon-reload
${INSPTH}/scripts/${MSTYLE}.starter.sh  
nohup sh ${INSPTH}/scripts/${MSTYLE}.primer.sh &>/dev/null &
echo "${MSTYLE} mounts completed."
#eof
#
