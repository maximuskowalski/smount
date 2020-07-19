# Temporary install instructions
_This is an alpha release and it will change completely.  Perhaps reconsider installing this for anything other than a test, as you may lose stuff. You have been warned._

### Recommended
Grab the latest rclone_gclone from l3uddz: https://transfer.cloudbox.media/nnVvn/rclone_gclone_v1.52-DEV  
Be sure to make it executable: `chmod +x rclone_gclone`

### Install 
1) Change to your install dir and git clone:
`cd /opt`
`git clone https://github.com/maximuskowalski/smount.git --branch alpha && cd smount`

2) Make the `shmount.sh` file executable:
`chmod +x shmount.sh`  

3) Open the file and set your variables 
`nano shmount.sh`

```
# VARIABLES

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

```

It does not use rclone.conf but builds a config on the fly. This file will be added to only at present, not replaced or edited by the script so if you run the same set because of error you will end up with double ups of mounts. Auth is only by the service account oyou have in the config file. 

### Make Setfiles
Copy the sample set before editing: 
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/aio.set`
and/or
`cp /opt/smount/sets/sets/aiosample.set /opt/smount/sets/csd.set`
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/strm.set`
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/ezekiel.set`

Edit your sets using nano or however you prefer and save.
`nano ~/smount/sets/ezekiel.set`

### Run
Run the script with the set for your mountstyle.

`./mount.sh aio.set`

If you want to add a cloudseed mount or a strm only mount edit variable MSTYLE for those and run again with set for new mounts.

`./mount.sh csd.set`

Mergerfs will be created in ./output but will not be installed, use as example for your own editing pleasures.

```
#######################
AIO MOUNT SETIINGS
#######################
--allow-other \
 --drive-skip-gdocs \
 --fast-list \
 --rc \
 --rc-no-auth \
 --use-mmap \
 --rc-addr=localhost:\${RCLONE_RC_PORT} \
 --dir-cache-time=168h \
 --timeout=10m \

#######################
STRM MOUNT SETIINGS
#######################
--allow-other \
 --drive-skip-gdocs \
 --fast-list \
 --rc \
 --rc-no-auth \
 --use-mmap \
 --rc-addr=localhost:\${RCLONE_RC_PORT} \
 --dir-cache-time=168h \
 --timeout=10m \
 --vfs-cache-max-age=24h \
 --vfs-cache-mode=writes \
 --vfs-cache-max-size=200G \

#######################
CSD MOUNT SETIINGS
#######################
--allow-other \
 --drive-skip-gdocs \
 --fast-list \
 --rc \
 --rc-no-auth \
 --rc-addr=localhost:\${RCLONE_RC_PORT} \
 --dir-cache-time=36h \
 --poll-interval=60s \
 --timeout=30m \
 --vfs-cache-max-age=36h \
 --vfs-cache-mode=full \
 --vfs-cache-poll-interval=30s \
 --vfs-read-chunk-size=8M \
 --vfs-read-chunk-size-limit=512M \
 --vfs-cache-max-size=50G \
 --tpslimit-burst=50 \
 --transfers=16 \
 --checkers=12 \
 --async-read=true \
 --no-checksum \
 --no-modtime \

#######################
CST MOUNT SETIINGS
#######################
Choose your own
Edit ./input cst@.service with your preferred settings.
You  could make as many different custom mount setups as your system can cope with by running successively with different settings.
```
