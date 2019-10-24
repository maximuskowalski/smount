# smount
A sharedrive mounter.

Takes a list of sharedrives and creates rclone VFS mounts.

Rclone config files are generated top copy paste to your rclone config if needed.

This script requires rclone, sudo, and passwordless sudo.

Requires `./etc/fuse.conf` to have

`# Allow non-root users to specify the allow_other or allow_root mount options.`

`user_allow_other`

**Install**

```
git clone https://github.com/maximuskowalski/smount.git

cd smount
```
Edit or create your set file - see below for examples.

Config rclone so all mount points are authed and named. You can generate an rclone compatible text file if required using the rgen tool. See below.

Edit mountup.sh to include your variables. You will need to add your USER and GROUP. If you wish to place your set dir elsewhere you can add the path too.
```
USER=max #user name goes here
GROUP=max #group name goes here
SET_DIR=./smount/sets
```
Edit permisions for mountup.sh
```
chmod +x mountup.sh
```
And run the file with a referenced setfile, eg:-
```
./mountup.sh set.mount
```
Wait a few mins and your vfs mounts will be populated at /mnt/sharedrives/

You can then edit your mergerfs / unionfs set up if needed.

**SETS**

An example set file is included in `/smount/sets` the format is

```
# 1name          2sharedriveID
td_anime         teamdriveID1
td_audiobooks    teamdriveID2
td_ebooks        teamdriveID3
td_movies        teamdriveID4
td_tv            teamdriveID5
```

The name corresponds exactly to the name of a remote listed in in your rclone config file. The sharedrive ID can be found by viewing the sharedrive in the google drive GUI and copy the last part of the URL when you are in the root of the drive. If you do not need to generate an rclone config file you can put any characters in here you like as a placeholder.

**RCLONE CONFIG**

An rclone config generator tool is included. To use it ;-

Edit the variables at the top of the script
```
SET_DIR=~/smount/sets
client_id=somebody.apps.googleusercontent.com
client_secret=eleventyseven
sadir="/opt/sa"
token={"access_token":"ya"}
```
If you already have a remote configured you can copy the details from there for a Client Secret Token auth method. Otherwise auth a single remote using `rclone config` and copy the details into the other remotes afterwards.

If you are using service files for your auth just leave the client_id, client_secret, and token as is, you won't need them. Just make sure the path to the service files you wish to use is correct. Service files are expected to be named `1.json`, `2.json`...`57.json` etc. 1 json file will be used for each remote. If you have already used a number of these for existing remotes you may simply edit the `sa.count` file to begin at any number you wish. Each service account can download a maximum of 10 TB per 24 hours so even using the same service account file for each mount is unlikely to be a problem.

```
chmod +x rgen.sh
```
Then run the generator with a referenced setfile, eg:-.
```
./rgen.sh set.mount
```
Two files will be produced, `rc_sa.config` and `rc_cid.config`. You can use those to copy paste into your existing rclone config file. If you use the Client ID / Secret method you will need to add a valid token to each remote. Once in place you can run through `rclone config` and reauth a remote to get a token.

You can use checkrcmount https://github.com/88lex/checkrcmount to make sure your remotes are all authed if needed.

A simple
```
$rclone lsd remote:
```
Will list directories in a single remote to enable auth verification.
