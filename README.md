# NEW DEFAULT BRANCH

### WIKI is yet to be reworked, follow these instructions below only.
### MASTER branch still exists.
### DEV branch still exists.

## smount

_An interactive rclone union share drive mount installer._

### summary

This script is basically a thing you run and answer a few questions as you go. Ideal for those who don't like to do stuff themselves.

You will need know what service accounts and share-drives are. To use this script you will need service account files created and available on the machine you wish to use. They should have at least read access to any drives you wish to include in the mount using this script.

After running the script you will (probably) have an rclone union mount serving your remote files from a directory mounted on the system. Rclone will be installed and updated, or not if you prefer. Your rclone configuration file and a systemd service file will be created, as will the required mount directories.

The file `/etc/fuse.conf` will be checked and edited to include `user_allow_other` if needed.

A log file for the mount will be created at `~/logs/smount.log`

Probably the easiest way to explain is just to demonstrate.

## requirements

**You will need:-**

- A Debian based Linux OS, Debian, Ubuntu, Pop!OS etcetera.

- Password-less sudo,

- A least one service account in a directory on the server

- At least one share-drive that these service account(s) can access

## example use

Get the file however you choose, for example:-

Using wget to download, set as executable and run.

```assembly
wget https://raw.githubusercontent.com/maximuskowalski/smount/main/shmount.sh
chmod +x shmount.sh
```
Run the script , answer the questions.

```assembly
./shmount.sh

Would you like to install or update rclone? [Y/N] : y

rclone will be installed

Do you want rclone beta or stable?

1) Beta
2) Stable
3) No
#? 2
```

If you elect to install or update rclone the latest version will be installed, select beta **(1)** or stable **(2)** to choose your branch. The third option **(3)** is for a change of heart and leaving rclone as it currently is. The installer won't re-download if it is not needed.

Universal configuration options are next.

```assembly
Please enter service account file path, for example /opt/sa/mounts :
/opt/sa/mounts

Please enter name to use for rclone union mount, eg reunion.
reunion

You currently have Avail
 183G,
DO NOT use all of this for cache.

Suggest using no more than 146G
____________________
Please enter cache max size +G (ex 50G)
--------------------
10G

--------------------
User is:          max
SA Path:          /opt/sa/mounts
SA file:          /opt/sa/mounts/000001.json
Cache size:       10G
Mount Name:       reunion
Mount Point:      /mnt/reunion
Continue with installation?
--------------------
1) Continue
2) Exit
#? 1
```

Enter the universal options that will apply to the rclone union and all upstream drives we configure as part of it. Once these are entered you will have a chance to check details before going ahead. If you have made a mistake you can choose option **(2)** and exit the script at this point to try again.

Using vfs-cache-mode full, whatever you choose for your maximum cache size **you will need to have the free space for**. A full drive is no fun so be careful, be sure. Your cache will go to the default cache location within your user home directory. I would suggest leaving a minimum of 50GB free. I will build in a fail safe check at some point but for now this is on you. Currently free space will be checked and a recomendation of 80% of this free space will be suggested as a maximum value.

```assembly
Installing rclone stable

......... # installation of rclone ommitted from documentation

The latest version of rclone rclone v1.55.1 is already installed.
```

Rclone will be installed or updated with the branch you selected, in this example the latest stable version of rclone was already up to date.

The script calls the official installation script from <https://rclone.org/install/> - **you may wish to review this prior to installation**, some people may be happy to take the risk of a curled script.

STABLE

```shell
curl https://rclone.org/install.sh | sudo bash
```

BETA

```shell
curl https://rclone.org/install.sh | sudo bash -s beta
```

The installer will not re-download rclone if it is already up to date.

Next we will be configuring all the drives we wish to be part of the union.

```assembly
add your first drive

Please enter a share drive name :
my_nottv

Please enter my_nottv Drive ID, for example 0A1xxxxxxxxxUk9PVA :
0A1xxxxxxxxxUk9PVA

creating rclone config for my_nottv with ID 0A1xxxxxxxxxUk9PVA

Remote config
--------------------
[my_nottv]
type = drive
scope = drive
server_side_across_configs = true
team_drive = 0A1xxxxxxxxxUk9PVA
service_account_file = /opt/sa/mounts/000001.json
--------------------

Would you like to add another drive? [Y/N] : y
adding more drives

Please enter Share Drive Name :
my_notmovies

Please enter my_notmovies Drive ID, for example 0A1xxxxxxxxxUk9PVA :
0A1yyyyyyyyyyyUk9PVA

creating rclone config for my_notmovies with ID 0A1yyyyyyyyyyyUk9PVA

Remote config
--------------------
[my_notmovies]
type = drive
scope = drive
server_side_across_configs = true
team_drive = 0A1yyyyyyyyyyyUk9PVA
service_account_file = /opt/sa/mounts/000901.json
--------------------

Would you like to add another drive? [Y/N] : y
adding more drives

Please enter Share Drive Name :
my_notmusic

Please enter my_notmusic Drive ID, for example 0A1xxxxxxxxxUk9PVA :
0A1zzzzzzzzzzzzUk9PVA

creating rclone config for my_notmusic with ID 0A1zzzzzzzzzzzzUk9PVA

Remote config
--------------------
[my_notmusic]
type = drive
scope = drive
server_side_across_configs = true
team_drive = 0A1zzzzzzzzzzzzUk9PVA
service_account_file = /opt/sa/mounts/000076.json
--------------------

Would you like to add another drive? [Y/N] : n
lettuce build mounts

Drives added: my_nottv my_notmovies my_notmusic
```

After each drive is added you have the option to add another drive until you are finished.

For each drive you will need to supply two pieces of information, the **name** you wish to use and the **drive ID**. The name doesnt matter too much, you can call your drive Angus if you wish but the share drive ID is critical.

```assembly
creating reunion rclone union config with the default policy options.
ACTION:  epall
CREATE:  epmfs
SEARCH:  ff

Remote config
--------------------
[reunion]
type = union
upstreams = my_nottv: my_notmovies: my_notmusic:
--------------------
```

The configuration for the union remote is created and all that is really left is to build the service files and start the mounts. An RC port will be selected for you by finding the first unused port equal to or greater than 5575.

```assembly
Is this a cloudbox install?  [Y/N] : y
mergerfs content line will be displayed after smounting has occured

checking if port 5575 is already in use
setting port to 5576
checking if port 5576 is already in use
port 5576 is available and will be used

Preparing smount service

starting the reunion service, be patient. If you have a big one this might take a while.

--------------------
in cloudbox installations the union can be included in mergerfs directory
/etc/systemd/system/mergerfs.service can be edited to include reunion eg:-

  /mnt/local=RW:/mnt/remote=NC:/mnt/reunion:NC /mnt/unionfs

--------------------

reunion mount complete

please consider reporting any issues
```

I would suggest preparing a document to copy and paste all the information you will need as you run through the script. An example might be:-

```assembly
# service accounts path, no trailing `/`
/opt/sa/mounts

# Mount Name:
reunion

# share drives
# name               ID

my_nottv             0A1vvvvvvvvvvvvUk9PVA

my_notmovies         0A1wwwwwwwwwwwwUk9PVA

my_misc              0A1xxxxxxxxxxxxUk9PVA

my_notebooks         0A1yyyyyyyyyyyyUk9PVA

my_notaudiobooks     0A1zzzzzzzzzzzzUk9PVA


```
