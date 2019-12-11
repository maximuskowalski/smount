#!/bin/bash
echo -e "Starting mountup.sh"

# REQUIRED VARIABLES
USER=max # user name goes here
GROUP=max # group name goes here
SET_DIR=~/smount/sets # set file dir
MOUNT_DIR=/mnt/sharedrives # where you want your sharedrives mounted

# OPTIONAL MergerFS Variables 
# for sample mergerfs service file. 
# NOT INSTALLED. PLACED in OUTPUT DIR as example only
RW_LOCAL=/mnt/local # read write local dir for merger service
UMOUNT_DIR=/mnt/sharedrives/td_* # if common prefix used like `td_aerobics_vids', 'td_jazz', then wildcard is possible (td_*)
MERGER_DIR=/mnt/unionfs # if this is a non empty dir or already in use by another merger service a reboot is recommended.

# Make Work Dirs
sudo mkdir -p /opt/sharedrives
sudo chown -R $USER:$GROUP /opt/sharedrives
sudo chmod -R 775 /opt/sharedrives

# Create and place service files
export user=$USER group=$GROUP rw_local=$RW_LOCAL umount_dir=$UMOUNT_DIR merger_dir=$MERGER_DIR 
envsubst '$user,$group' <./input/teamdrive@.service >./output/teamdrive@.service
envsubst '$user,$group' <./input/teamdrive_primer@.service >./output/teamdrive_primer@.service
envsubst '$user,$group' <./input/teamdrive_primer@.timer >./output/teamdrive_primer@.timer
envsubst '$rw_local,$umount_dir,$merger_dir' <./input/smerger.service >./output/smerger.service

#copynewfiles
sudo bash -c 'cp ./output/teamdrive@.service /etc/systemd/system/teamdrive@.service'
sudo bash -c 'cp ./output/teamdrive_primer@.service /etc/systemd/system/teamdrive_primer@.service'
sudo bash -c 'cp ./output/teamdrive_primer@.timer /etc/systemd/system/teamdrive_primer@.timer'
#uncomment to copy smerger to /etc/systemd/system
#sudo bash -c 'cp ./output/smerger.service /etc/systemd/system/smerger.service'

# enable new services
sudo systemctl enable teamdrive@.service
sudo systemctl enable teamdrive_primer@.service
sudo systemctl enable teamdrive_primer@.timer

#rename existing starter and kill scripts if present
mv vfs_starter.sh vfs_starter_`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1
mv vfs_primer.sh vfs_primer_`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1
mv vfs_kill.sh vfs_kill_`date +%Y%m%d%H%M%S`.sh > /dev/null 2>&1

# Note that port default starting number=5575
# Read the current port no to be used then increment by +1
get_port_no_count () {
  read count < port_no.count
  echo $(($count+1)) > port_no.count
}

# config files
make_config () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      get_port_no_count
      conf="
      RCLONE_RC_PORT=$count
      SOURCE_REMOTE=$name:
      DESTINATION_DIR=$MOUNT_DIR/$name/
      ";
      echo "$conf" > /opt/sharedrives/$name.conf
    done
}

make_starter () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl enable teamdrive@$name.service && sudo systemctl enable teamdrive_primer@$name.service">>vfs_starter.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start teamdrive@$name.service">>vfs_starter.sh
    done
}

make_primer () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl start teamdrive_primer@$name.service">>vfs_primer.sh
    done
}

make_vfskill () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl stop teamdrive@$name.service && sudo systemctl stop teamdrive_primer@$name.service">>vfs_kill.sh
    done
    sed '/^\s*#.*$/d' $SET_DIR/$1|\
    while read -r name other;do
      echo "sudo systemctl disable teamdrive@$name.service && sudo systemctl disable teamdrive_primer@$name.service">>vfs_kill.sh
    done
}

make_config $1
make_starter $1
make_primer $1
# daemon reload
sudo systemctl daemon-reload
make_vfskill $1
chmod +x vfs_starter.sh vfs_primer.sh vfs_kill.sh
./vfs_starter.sh  #fire the starter
nohup sh ./vfs_primer.sh &>/dev/null &

# uncomment below line to enable and start smerger.service
#sudo systemctl enable smerger.service && sudo systemctl start smerger.service

echo "sharedrive vfs mount script complete, it may take time for files to fully populate"
#eof