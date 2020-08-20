
A sharedrive mounter.

Takes a list of sharedrives and creates rclone VFS mounts.

# Develop Branch Install Instructions
_This is an ~~alpha~~ beta release and it will change.  Perhaps reconsider installing this for anything other than a test, as you may lose stuff. You have been warned._

Some of the current preset mount settings use VFS cache features requiring rclone beta 1.5.2 and above.

### Recommended
Grab the latest rclone_gclone from l3uddz: 

https://transfer.cloudbox.media/FjUqh/rclone_gclone_v1.52.3-DEV_1

Be sure to make it executable: `chmod +x rclone_gclone`

### Install 
1) Change to your install dir and git clone:  
`cd /opt`

`git clone https://github.com/maximuskowalski/smount.git --branch develop && cd smount`

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

#### Things to Note
1) It does not use rclone.conf but builds a config on the fly. And this special config will be added to every time you run this script -- it does not replace or edit the contents.  This means if you run the same set multiple times (perhaps because of error) you will end up with multiples of the same mount configs. 
2) Auth is only by the service account method for now. If you have only 10 service accounts and run this fifty times you might want to manually edit afterwards, there is not currently a stop for max .json in place. 

### Make Setfiles
Copy the sample set before editing:  
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/aio.set`  
and/or  
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/csd.set`  
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/strm.set`  
`cp /opt/smount/sets/aiosample.set /opt/smount/sets/ezekiel.set`  

Edit the set file to add in the drive names and TD IDs:  
`nano /opt/smount/sets/aio.set` 

### Run
Run the script with the set for your mountstyle.

`./shmount.sh aio.set`

If you want to add a cloudseed mount or a strm only mount edit variable MSTYLE `MSTYLE=csd` for those and run again with set for new mounts.

`./shmount.sh csd.set`

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
You  could make as many different custom mount setups as your system can cope with by running successively with different settings applied to `./input cst@.service` each time.
```

## Support on ~~Beerpay~~ Github Sponsors
Hey dude! Help me out for a couple of :beers:!

https://github.com/sponsors/maximuskowalski

[![Buy me a coffee][buymeacoffee-shield]][buymeacoffee]

[buymeacoffee-shield]: https://www.buymeacoffee.com/assets/img/guidelines/download-assets-sm-2.svg
[buymeacoffee]: https://github.com/sponsors/maximuskowalski
