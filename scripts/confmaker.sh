#!/bin/bash
# VARIABLES
SET_DIR=/mnt/c/Users/matt/Documents/GitHub/smount/sets/ # set file dir [ REMOVE VARIABLE ]
SA_PATH=/opt/smount/sa # sharedrive mounting service accounts [ NO TRAILING SLASH ]
#n=1

# get_sa_count () {
#   read sacount < sa.count
#   echo $(($sacount+1)) > sa.count
# }

get_sa_count () {
  for (( n=1; n++ ))
do
    echo "$n"
done
}


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
service_account_file = "$SA_PATH/$n.json"
service_account_file_path = $SA_PATH
">> /mnt/c/Users/matt/Documents/GitHub/smount/config.conf
  done; }

# Function calls
make_shmount.conf $1

#eof
