#!/bin/bash
SET_DIR=~/smount/sets
client_id=somebody.apps.googleusercontent.com
client_secret=eleventyseven
sadir="/opt/mountsa"
token={"access_token":"ya"}

get_sa_count () {
  read count < sa.count
  echo $(($count+1)) > sa.count
}

make_rc_sa_config () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
  while read -r name driveid;do echo'
[$name]
type = drive
scope = drive
server_side_across_configs = true
team_drive = $driveid
service_account_file = "$sadir"/$count.json
'>>rc_sa.config
  done; }

make_client_id_config () {
  sed '/^\s*#.*$/d' $SET_DIR/$1|\
  while read -r name driveid;do echo'
[$name]
type = drive
scope = drive
server_side_across_configs = true
team_drive = $driveid
client_id = $client_id
client_secret = $client_secret
token = $token 
'>>rc_cid.config
  done; }

make_rc_sa_config $1
make_client_id_config $1
