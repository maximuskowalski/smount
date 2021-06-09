# NEW DEFAUL BRANCH - WIKI is yet to be reworked, follow these instructions below only.

# shmount

_An interactive rclone union mount installer._

## summary

You still need to read and understand a few things but this script is basically a thing you run and answer a few questions as you go. Ideal for those who don't like to do stuff themselves, or having trouble understanding the documentation they have most definitely read through at least twice

If you are here I am assuming you know what service accounts, share-drives and such are. To use this script you will need service account files on the machine you wish to use. Probably the easiest way to explain is just to demonstrate.

After running the script you will (probably) have an rclone union mount serving your remote files from a directory mounted on the system. Rclone will be installed and updated, or not if you prefer.

Your rclone configuration file and a system service file will be created, as will the required mount directories.

The file `/etc/fuse.conf` will be checked and edited to include `user_allow_other` if needed.

A log file for the mount will be created at `~/logs/shmount.log`

## requirements

**You will need:-**

- A Debian based Linux OS, Debian, Ubuntu, Pop!OS etcetera.

- Password-less sudo,

- A least one service account in a directory on the server

- At least one share-drive that the service account(s) can access

## example use

_Instructions for accessing script to come._ Git clone

Run the script , answer the questions.

```assembly
➜  shmount git:(main) ✗ ./shmount.sh

Would you like to install or update rclone? [Y/N] : y

rclone will be installed

Do you want rclone beta or stable?

1) Beta
2) Stable
3) No
#? 2
```

If you elect to install or update rclone the latest version will be installed, select beta **(1)** or stable **(2)** to choose your branch. The third option **(3)** is for a change of heart and leaving rclone as it currently is. For now just choose stable, the configuration of drives will fail on beta _(rclone v1.56.0-beta.5531.41f561bf2)_. The installer won't re-download if it is not needed.

The configuration will be generated without a proper share-drive ID if you have rclone beta installed. Rerunning the script using existing drive names will overwrite the configurations.

If you already have beta installed then choose stable and upgrade to beta again afterwards using :-

```assembly
curl https://rclone.org/install.sh | sudo bash -s beta
```

Universal configuration options are next.

```assembly
Please enter service account file path, for example /opt/sa/mounts :
/opt/sa/mounts

Please enter an existing service account filename, for example 123.json :
000001.json

Please enter name to use for rclone union mount, eg reunion.
reunion

Rclone mount will use vfs-cache-mode full, and use 200GB, do you want to change max cache size?
1) Yes
2) No
#? 1
Please enter cache max size +G (ex 50G)
10G

User is:          max
SA Path:          /opt/sa/mounts
SA file:          /opt/sa/mounts/000001.json
Cache size:       10G
Mount Name:       reunion
Mount Point:      /mnt/reunion
Continue with installation?
1) Continue
2) Exit
#? 1
```

Enter the universal options that will apply to the rclone union and all upstream drives we configure as part of it. Once all these are entered you will have a chance to check details before going ahead. If you have made a mistake you can choose option **(2)** and exit the script at this point to try again.

Using vfs-cache-mode full, whatever you choose for your maximum cache size **you will need to have the free space for**. A full drive is no fun so be careful, be sure. In this version of the script your cache will go to the default cache location with your user home directory. If you have partitioned your home directory separately **make sure you are checking the right location for free space**. I would suggest leaving a minimum of 50GB free. I will build in a fail safe check at some point but for now this is on you.

```assembly
Installing rclone stable

......... # installation of rclone ommitted from documentation

The latest version of rclone rclone v1.55.1 is already installed.
```

Rclone will be installed or updated with the branch you selected, in this example the latest stable version of rclone was already up to date.

The script calls the official installation script from https://rclone.org/install/ - **you may wish to review this prior to installation**, some people may be happy to take the risk of a curled script.

STABLE

```
curl https://rclone.org/install.sh | sudo bash
```

BETA

```
curl https://rclone.org/install.sh | sudo bash -s beta
```

The installer won't re-download if it is not needed.

Next we will be configuring all the drives we wish to be part of the union.

```assembly
Please enter Share Drive Name :
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
service_account_file = /opt/sa/mounts/000001.json
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
service_account_file = /opt/sa/mounts/000001.json
--------------------

Would you like to add another drive? [Y/N] : n
Drives added: my_nottv my_notmovies my_notmusic

lettuce build mounts
```

After each drive is added you have the option to add another drive until you are finished.

For each drive you will need to supply two pieces of information, the **name** you wish to use and the **drive ID**. The name doesnt matter too much you can call your drive Angus if you wish but the share drive ID is critical. I would suggest preparing a document to copy and paste all the information you will need as you run through the script.

```assembly
creating reunion rclone union config

Remote config
--------------------
[reunion]
type = union
upstreams = my_nottv: my_notmovies: my_notmusic:
--------------------
```

The configuration for the union remote is created and all that is left is to build the service files and start the mounts.

```assembly
Preparing shmount service
Created symlink /etc/systemd/system/default.target.wants/shmount.service → /etc/systemd/system/shmount.service.
starting the reunion service.

reunion mounts completed
```
