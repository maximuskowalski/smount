#!/bin/bash
SET_DIR=~/smount/sets
client_id=somebody.apps.googleusercontent.com
client_secret=eleventyseven
sadir="/opt/sa"
token={"access_token":"ya"}

get_sa_count () {
  read count < sa.count
  echo $(($count+1)) > sa.count
}

make_rc_sa_config () {
  for set_file in $@; do echo Set file is $set_file
    column -t $SET_DIR/$set_file|sed '/^\s*#.*$/d'|\
    while IFS=' ' read -r name driveid;do
      get_sa_count
rcsaconf="
[$name]
type = drive
scope = drive
server_side_across_configs = true
team_drive = $driveid
service_account_file = "$sadir"/$count.json
";
      echo "$rcsaconf" >>rc_sa.config
    done
  done
}

make_client_id_config () {
  for set_file in $@; do echo Set file is $set_file
    column -t $SET_DIR/$set_file|sed '/^\s*#.*$/d'|\
    while IFS=' ' read -r name driveid;do
      cidconf="
[$name]
type = drive
scope = drive
server_side_across_configs = true
team_drive = $driveid
client_id = $client_id
client_secret = $client_secret
token = $token 
";
      echo "$cidconf" >>rc_cid.config
    done
  done
}

make_rc_sa_config $@
make_client_id_config $@
