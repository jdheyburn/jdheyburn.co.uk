---
date: 2021-04-28
title: "Backup to Backblaze B2 using restic and rclone"
description: 
type: posts
series: []
tags:
  - backup
  - restic
  - rclone
---



Over the last lockdown I spent some time making sure backups for my music files were all 

## Backup tools

Restic is a snapshot tool that given a set of directories to backup to a repostory, it will split the data into chunks and ensure that there are no duplicated files within your backup respostory. You can specify your backup policy to it too, where it will manage what daily, weekly, or monthly snapshots to keep.

Rclone is a cloud file transfer tool that allows you to synchronise, copy, etc., any data across a huge library of cloud backends.

Both of these are open source projects that are free to use.

Backups should be automated without us having to think of them (at least until you need to restore!), so for this I'll be using systemd unit services with timers.

## Backup contents and policy

I have restic set up to backup to two respositories:

1. small-files
  - PiHole configuration
  - UniFi backups
  - Logitech Media Server (LMS) backups
1. media
  - all music files
  - beets databases

Reason being why these are split into two repositories is so that I can define a separate backup policy for each of them.

For example, small-files contains what you'd expect it to be, which is small files! You can see from the list above that these are just configuration files or even backups of files themselves. Since config files are important, I would like the option to go back to a particular setting from weeks or maybe months ago. 

This is why I have a policy to keep 30 daily snapshots, 5 weekly snapshots, 12 monthly snapshots, and 3 yearly snapshots. It might be a bit overkill, but I can always reduce that number and restic will prune the snapshots.

Whereas for media, these files tend to be much larger and so that will reflect in the repository size too. Especially since for music files, they're not really going to change over time - all I'm looking for is a way or reverting back to a state I had recently. Based on this I only need to keep 30 daily snapshots.

Being included in the media repository are beets databases. I'll expand on how I have this set up in a future post, but for now think of it as a database containing the metadata for your music collection. It's useful to include this with my music files so that I can reflect on the state of my collection at a particular point in time.

## Backup procedure

I have a 2TB USB hard drive connected to a Pi (dee) which is configured to be the NFS server for my network, along with PiHole for DNS, and a UniFi controller too. Dee holds all of the files that we want to back up with the exception of the LMS backups.

LMS is something I'll also expand on in future, but for now all you need to know is its a music server which sits on a different machine to dee, and so we'll need to retrieve those backup files before we invoke restic.

> N.B. the configuration for restic was largely inspired from a post on [Fedora Magazine](https://fedoramagazine.org/automate-backups-with-restic-and-systemd/).

Once the snapshot is done we'll need to upload the backups to the cloud. In this case this is Backblaze B2.


1. restic-all.sh
  - script that systemd will call to invoke the backup process
1. restic-all.service
  - systemd unit file to allow the script to be automated
1. restic-all.timer
  - systemd timer file to automate the corresponding unit
1. rclone-all.sh

### retrieving backups from remote servers

As described above, dee acts as the backup server and so we'll need to retrieve files we want to backup from any remote servers.

For now I only need to retrieve LMS backups from PiCorePlayer - for which there is a handy command to help with that: `pcp bu`.

```bash
#!/usr/bin/env bash

# Invoke and pull backups from remote servers and place them on USB

function pcp() {

    local fpath="/mnt/mmcblk0p2/tce"
    local fname="mydata"
    local ext="tgz"
    local now=$(date -u +"%Y-%m-%dT%H%M%S")
    local dstPath="/mnt/usb/Backup/lms/*.${ext}"

    echo "removing previous backups..."
    rm -rf $dstPath

    local sourceFile="${fpath}/${fname}.${ext}"
    local dstFile="/mnt/usb/Backup/lms/${fname}_${now}.${ext}"

    echo "starting pcp backup"
    ssh -i /home/jdheyburn/.ssh/pcp tc@pcp.joannet.casa -C 'pcp bu'

    echo "copying $sourceFile on remote to $dstFile"
    scp -i /home/jdheyburn/.ssh/pcp "tc@pcp.joannet.casa:${sourceFile}" $dstFile
}

function main() {
    echo "entered $0"
    pcp
}

main $@
```

This takes the backup created on the remote at `/mnt/mmcblk0p2/tce/mydata.tgz` and places it locally at `/mnt/usb/Backup/lms/mydata_DATETIME.tgz`. This `lms` directory can then be used as a backup path for restic.

Should I need to retrieve backups from any other servers, I'll write a new function here and append it to `main`.

### restic invoke scripts

```bash
# restic-all.sh

#!/usr/bin/env bash

# Master script for backing up anything to do with restic

function do_restic() {
    local mode=$1
    local target=$2

    if [ $mode == "backup" ]; then
        echo "Backing up $target"
        restic backup --verbose --tag systemd.timer $BACKUP_EXCLUDES $BACKUP_PATHS
        echo "Forgetting old $target"
        restic forget --verbose --tag systemd.timer --group-by "paths,tags" --keep-daily $RETENTION_DAYS --keep-weekly $RETENTION_WEEKS --keep-monthly $RETENTION_MONTHS --keep-yearly $RETENTION_YEARS
    elif [ $mode == "prune" ]; then
        echo "pruning $target"
        restic --verbose prune
    fi
}

function small_files() {
    export BACKUP_PATHS="/var/lib/unifi/backup/autobackup /etc/pihole /mnt/usb/Backup/lms"
    export BACKUP_EXCLUDES=""
    export RETENTION_DAYS="7"
    export RETENTION_WEEKS="5"
    export RETENTION_MONTHS="12"
    export RETENTION_YEARS="3"
    export RESTIC_REPOSITORY="/mnt/usb/Backup/restic/small-files"
    export RESTIC_PASSWORD_FILE="/home/restic/.resticpw"

    local mode=$1

    do_restic $mode "small files"
}

function media() {
    export BACKUP_PATHS="/mnt/usb/Backup/media/beets-db /mnt/usb/Backup/media/lossless /mnt/usb/Backup/media/music /mnt/usb/Backup/media/vinyl"
    export BACKUP_EXCLUDES=""
    export RETENTION_DAYS="30"
    export RETENTION_WEEKS="0"
    export RETENTION_MONTHS="0"
    export RETENTION_YEARS="0"
    export RESTIC_REPOSITORY="/mnt/usb/Backup/restic/media"
    export RESTIC_PASSWORD_FILE="/home/restic/.resticmediapw"

    local mode=$1

    do_restic $mode "media"
}

function main() {

    mode=$1

    if [ $mode == "backup" ]; then
        /home/jdheyburn/dotfiles/restic/pull-backups.sh
    fi

    small_files $mode
    media $mode
}

main $@
```

This script is a bit messy, but it gets the job done. It supports a parameter which can be either `backup` or `prune`, depending on what job needs to be ran.

If the mode is `backup` then it will invoke the `pull-backups.sh` script so that restic has the latest files to backup.

Once the script is defined we can have systemd invoke it.

```systemd
# /etc/systemd/system/restic-all.service

[Unit]
Description=Restic backup everything service
OnFailure=unit-status-mail@%n.service

[Service]
Type=oneshot
ExecStart=/home/jdheyburn/dotfiles/restic/restic-all.sh backup

[Install]
WantedBy=multi-user.target
```

You can see that we're passing in the mode to the script at `ExecStart`.

In order to then have this systemd unit invoked on a regular occurrence, we need to define a `timer` for this unit.

```systemd
# /etc/systemd/system/restic-all.timer

[Unit]
Description=Backup with restic daily

[Timer]
OnCalendar=*-*-* 2:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

This will ensure the backup script is invoked at 2am every day.

## rclone

Restic has now created snapshots and stored them in their respective respositories on the USB drive. But this isn't really a safe place to keep backups since the USB drive could crap out at any moment. We can use rclone to offload the repositories to B2.

For this I'm going to use the same pattern as before for restic; a shell script invoked by systemd.

### rclone scripts

```bash
# rclone-all.sh

#!/usr/bin/env bash

# Master script for backing up all rclone stuff to various clouds

RCLONE_CONFIG=/home/jdheyburn/.config/rclone/rclone.conf

function main() {

    echo "rcloning beets-db -> gdrive:media/beets-db"
    rclone -v sync /mnt/usb/Backup/media/beets-db gdrive:media/beets-db --config=${RCLONE_CONFIG}

    echo "rcloning music -> gdrive:media/music"
    rclone -v sync /mnt/usb/Backup/media/music gdrive:media/music --config=${RCLONE_CONFIG}

    echo "rcloning lossless -> gdrive:media/lossless"
    rclone -v sync /mnt/usb/Backup/media/lossless gdrive:media/lossless --config=${RCLONE_CONFIG}

    echo "rcloning vinyl -> gdrive:media/vinyl"
    rclone -v sync /mnt/usb/Backup/media/vinyl gdrive:media/vinyl --config=${RCLONE_CONFIG}

    echo "rcloning restic -> b2:restic"
    rclone -v sync /mnt/usb/Backup/restic b2:iifu8Noi-backups/restic/ --config=${RCLONE_CONFIG}

    echo "Done rcloning"
}

main $@
```



## restic prune




## TODO

- why b2? how can people get set up on it?
- handle failures
  - https://northernlightlabs.se/2014-07-05/systemd-status-mail-on-unit-failure.html
- better backup method?