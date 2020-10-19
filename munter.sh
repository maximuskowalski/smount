#!/bin/bash
USER=max
GROUP=max
KEY=abcd
SECRET=1234
ENDPOINT1=https://foo1.bar
ENDPOINT2=https://foo2.bar
ENDPOINT3=https://foo3.bar
MNT1=remote01
MNT2=remote02
MNT3=remote03
RUNION=reunion
MNTPOINT=/mnt/reunion

# remotes
rmk01() {
  rclone config create ${MNT1} s3 provider Minio access_key_id ${KEY} secret_access_key ${SECRET} region us-east-1 endpoint ${ENDPOINT1} chunk_size 90M upload_concurrency 16 disable_http2 true
}

rmk02() {
  rclone config create ${MNT2} s3 provider Minio access_key_id ${KEY} secret_access_key ${SECRET} region us-east-1 endpoint ${ENDPOINT2} chunk_size 90M upload_concurrency 16 disable_http2 true
}

rmk03() {
  rclone config create ${MNT3} s3 provider Minio access_key_id ${KEY} secret_access_key ${SECRET} region us-east-1 endpoint ${ENDPOINT3} chunk_size 90M upload_concurrency 16 disable_http2 true
}

mkreunion() {
  rclone config create ${RUNION} union upstreams "${MNT1}: ${MNT2}: ${MNT3}:"
}

# mountpoints
mkmounce() {
  sudo mkdir ${MNTPOINT} && sudo chown ${USER}:${GROUP} ${MNTPOINT}
}

# servicemaker
sysdmaker() {
  sudo bash -c 'cat > /etc/systemd/system/munter.service' <<EOF
# /etc/systemd/system/munter.service
[Unit]
Description=Munter Mount
After=network-online.target

[Service]
User=${USER}
Group=${GROUP}
Type=notify
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/rclone mount \\
          --config=/home/${USER}/.config/rclone/rclone.conf \\
          --allow-other \\
          --allow-non-empty \\
          --rc \\
          --rc-addr=localhost:5573 \\
          --vfs-read-ahead=128M \\
          --vfs-read-chunk-size=64M \\
          --vfs-read-chunk-size-limit=2G \\
          --vfs-cache-mode=full \\
          --vfs-cache-max-age=24h \\
          --vfs-cache-max-size=200G \\
          --fast-list \\
          --buffer-size=64M \\
          --dir-cache-time=1h \\
          --timeout=10m \\
          --umask=002 \\
          --syslog \\
          -v \\
          ${RUNION}: ${MNTPOINT}
ExecStop=/bin/fusermount -uz ${MNTPOINT}
Restart=on-abort
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=default.target
EOF
}

# primaker
primaker() {
  sudo bash -c 'cat > /etc/systemd/system/munter_primer.service' <<EOF
# /etc/systemd/system/munter_primer.service
[Unit]
Description=Munter Primer - Service
Requires=munter.service
After=munter.service

[Service]
User=${USER}
Group=${GROUP}
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/rclone rc vfs/refresh \\
          recursive=true \\
          --config=/home/${USER}/.config/rclone/rclone.conf \\
          --timeout=1h \\
          --rc-addr=localhost:5573 \\
          -vvv \\

[Install]
WantedBy=default.target
EOF
}

# primetimer
primtaker() {
  sudo bash -c 'cat > /etc/systemd/system/munter_primer.timer' <<EOF
# /etc/systemd/system/munter_primer.timer
[Unit]
Description=Munter Primer - Timer

[Timer]
OnUnitInactiveSec=167h

[Install]
WantedBy=timers.target
EOF
}

enabler() {
  sudo systemctl enable munter.service
  sudo systemctl enable munter_primer.service
}

rmk01
rmk02
rmk03
mkreunion
mkmounce
sysdmaker
primaker
primtaker
sudo systemctl daemon-reload
enabler
sudo systemctl start munter.service
nohup sh sudo systemctl start munter_primer.service &>/dev/null &
echo "${RUNION} mounts completed."
