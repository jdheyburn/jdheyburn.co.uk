---
date: 2021-05-04
title: "Backup to Backblaze B2 using restic and rclone"
description: I use the holy trinity of restic, rclone, and B2 together with systemd to automate backups at home
type: posts
series: []
tags:
  - backup
  - backblaze
  - beets
  - lms
  - rclone
  - restic
  - systemd
---

Over the last UK lockdown I spent some time making sure I had backups of my music collection after I had organised them using [beets](https://beets.readthedocs.io/en/stable/). I used this as a good opportunity to ensure I had other backups in place for some other critical files at home too.

## Backup tools

[Restic](https://restic.net/) is a backup snapshot tool that given a set of directories, it will split the data into chunks and de-duplicate these chunks to a specified backup repository. You can specify your backup policy to a repository, where it will manage what daily, weekly, or monthly snapshots to keep.

[Rclone](https://rclone.org/) is a cloud file transfer tool that allows you to synchronise, copy, etc., any data across a huge library of cloud backends.

Both of these are open source tools that are free to use. Getting set up on them is beyond the scope of this post.

Backups should be automated without us having to think of them (at least until you need to restore!), so for this I'll be using systemd unit services with timers.

Restic is storing the snapshots in repositories on my local NFS server. I'm then using [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) to store these in the cloud. At the time of writing they charge $0.005 GB/month for storage, and $0.01 per GB downloaded. So it costs more to download from B2, but since this is a disaster recovery backup I don't anticipate downloading all that much. Being able to store it cheap over a long term is most important.

There are a load of other storage services too; here's a list below taken from [Backblaze's website](https://www.backblaze.com/b2/cloud-storage.html). The other one I was contending with was [Wasabi](https://wasabi.com/cloud-storage-pricing/#three-info); they're only marginally more expensive than B2 for storage ($0.0059 GB/month), but they don't charge for downloads.

{{< figure src="cloud-storage-price-comparison.png" link="cloud-storage-price-comparison.png" class="center" caption="Cloud storage cost comparisons" alt="A table showing the cost comparison of B2 versus S3, Azure, and Google Cloud Platform - B2 is the cheapest." >}}

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

For example, small-files contains... small files. You can see from the list above that these are just configuration files or even backups of files themselves. Since config files are important, I'd like the option to go back to a particular setting from weeks or maybe months ago. So the snapshots I want to keep for this repository is 30 daily snapshots, 5 weekly snapshots, 12 monthly snapshots, and 3 yearly snapshots. It might be a bit overkill, but I can always reduce that number and restic will remove them.

Whereas for media, these files tend to be much larger which will be reflected in the repository size. Especially since music files don't tend to change over time - all I'm looking for is a way of reverting back to a state I had recently in case I did some reorganising with beets. Based on this I only need to keep 30 daily snapshots.

Also in the media repository are the beets databases. I'll expand on how I have this set up in a future post, but for now think of it as a database containing the metadata for your music collection. It's useful to include this with my music files so that I can reflect on the state of my collection at a particular point in time.

## Backup procedure

I have a 2TB USB hard drive connected to a Pi (dee) which is configured to be the NFS server for my network, along with PiHole for DNS, and a UniFi controller too. The drive holds my music collection and the restic local repositories.

LMS sits on a different machine to dee so we'll need to retrieve the files first before we perform a snapshot.

Once restic has taken snapshots and stored them on the USB drive, we'll need to upload the backups to B2 with rclone.

> N.B. the configuration to automate restic with systemd was largely inspired from a post on [Fedora Magazine](https://fedoramagazine.org/automate-backups-with-restic-and-systemd/).

You can view the code for all these scripts and systemd unit files at my [GitHub repository](https://github.com/jdheyburn/dotfiles/tree/master/restic).

### Retrieving backups from remote servers

I'll have the restic backup script call another script, `pull-backups.sh` to retrieve remote files that I want to back up.

For now I only need to retrieve LMS backups from [PiCorePlayer](https://www.picoreplayer.org/) - for which there is a handy command to help with that: `pcp bu`. Don't get too invested in the file path locations, these are specific to PiCorePlayer.

```bash
# pull-backups.sh

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

### Restic backup

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

This script is a bit messy, but it gets the job done. It takes in an argument which can be either `backup` or `prune`, depending on what task needs to run. If the mode is `backup` then it will invoke the `pull-backups.sh` prior to snapshotting so that it has the latest files to backup. I cover the `prune` function [later](#restic-prune).

Both restic repositories will be kept under `/mnt/usb/Backup/restic`.

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

You can see that we're passing in the mode as an argument at `ExecStart`.

We can perform a test to make sure everything is defined correctly by running `systemctl start restic-all.service`, and viewing the logs back at `journalctl -u restic-all.service -f`.

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

This will invoke the service at 2am every day once we enable it with `systemctl enable restic-all.timer`.

We can have a look at the resulting snapshots with the below command.

```bash
$ restic -r /mnt/usb/Backup/restic/small-files/ snapshots
repository 79dbc9b6 opened successfully, password is correct
found 1 old cache directories in /root/.cache/restic, run `restic cache --cleanup` to remove them
ID        Time                 Host        Tags           Paths
------------------------------------------------------------------------------------------
d93573f4  2020-06-30 02:00:01  dee         systemd.timer  /etc/pihole
                                                          /var/lib/unifi/backup/autobackup

96ecf97e  2020-07-31 02:00:35  dee         systemd.timer  /etc/pihole
                                                          /var/lib/unifi/backup/autobackup

d2b0a78e  2020-08-31 02:00:21  dee         systemd.timer  /etc/pihole
                                                          /var/lib/unifi/backup/autobackup

... # removed for brevity

ec6fd77e  2021-05-03 02:00:34  dee         systemd.timer  /etc/pihole
                                                          /mnt/usb/Backup/lms
                                                          /var/lib/unifi/backup/autobackup

722fcbbf  2021-05-04 02:00:34  dee         systemd.timer  /etc/pihole
                                                          /mnt/usb/Backup/lms
                                                          /var/lib/unifi/backup/autobackup
------------------------------------------------------------------------------------------
39 snapshots
```

## Syncing to B2 with rclone

Restic has now created snapshots and stored them in their respective repositories on the USB drive - but this isn't really a safe place to keep backups since the USB drive could crap out at any moment. We can use rclone to offload the repositories to B2.

For this I'm going to use the same pattern as before for restic; a shell script invoked by systemd.

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

In addition to the restic repository directory, I'm also backing up the beets databases and music files. These are going to my Google Drive storage in case I want to hook it up to some other apps that can pull from there.

Like `restic-all.sh` above, this script is also invoked by systemd.

```systemd
# /etc/systemd/system/rclone-all.service

# This should be invoked after restic has done doing the daily backup

[Unit]
Description=Rclone backup everything service
After=restic-all.service
OnFailure=unit-status-mail@%n.service

[Service]
Type=oneshot
ExecStart=/home/jdheyburn/dotfiles/restic/rclone-all.sh

[Install]
WantedBy=restic-all.service
```

We can test it with `systemctl start rclone-all.service`.

Since we want to have rclone invoked after restic has done its thing, we need to specify `After=restic-all.service` and `WantedBy=restic-all.service`. Note that this'll run even if `restic-all.service` failed - but that's not really an issue for me since rclone is uploading more than just restic respositories.

We don't need to specify a systemd `.timer` file for this unit file since we're using the completion of `restic-all.service` as our invocation point, so we can start that service in order to test it'll run afterward.

```bash
systemctl start restic-all.service
```

## Handling service failures

> N.B. big thanks to [Laeffe](https://northernlightlabs.se/) for their [excellent guide](https://northernlightlabs.se/2014-07-05/systemd-status-mail-on-unit-failure.html) on this.

Automated backups are very useful for setting and forgetting, but when something goes wrong and backups haven't occurred, we need to be made aware of it.

We can configure each of the systemd files to invoke a script on failure which can then send us an email when this happens.

You'll notice that each of the systemd unit files have `OnFailure=unit-status-mail@%n.service` defined in them. This is an additional unit file where if the scripts fail, this service will be invoked.

```systemd
# /etc/systemd/system/unit-status-mail@.service

[Unit]
Description=Unit Status Mailer Service
After=network.target

[Service]
Type=simple
ExecStart=/home/jdheyburn/dotfiles/restic/systemd/unit-status-mail.sh %I "Hostname: %H" "Machine ID: %m" "Boot ID: %b"
```

The `@` symbol in the filename is a special case within systemd that [enables special functionality](https://superuser.com/a/393429). In our case when we invoked it at `OnFailure=unit-status-mail@%n.service` the calling unit file will pass its name via `%n` to allow the receiving unit file to access it at `%I`. So when the `restic-all` service fails, this value ends up in `unit-status-mail@.service` at `%I`.

This `%I` variable is then being passed as an argument to the script `unit-status-mail.sh`. The contents of the script are below:

```bash
# unit-status-mail.sh

#!/bin/bash

# From https://northernlightlabs.se/2014-07-05/systemd-status-mail-on-unit-failure.html

MAILTO="ADD_EMAIL_HERE"
MAILFROM="unit-status-mailer"
UNIT=$1

EXTRA=""
for e in "${@:2}"; do
  EXTRA+="$e"$'\n'
done

UNITSTATUS=$(systemctl status $UNIT)

sendmail $MAILTO <<EOF
From:$MAILFROM
To:$MAILTO
Subject:Status mail for unit: $UNIT

Status report for unit: $UNIT
$EXTRA

$UNITSTATUS
EOF

echo -e "Status mail sent to: $MAILTO for unit: $UNIT"
```

The name of the calling unit file is passed to `UNIT` where the status of it is received, and the output is sent in an email to `MAILTO`.

You'll need to make sure you have `sendmail` installed on the machine to do this.

```bash
sudo apt install sendmail -y
```

For me, the emails landed in the spam folder - but once you configure a rule on your email client to always forward them to your inbox, you'll always be notified if there's an error.

{{< figure src="status-email.png" link="status-email.png" class="center" caption="The resulting email" alt="A screenshot showing an example email highlighting there has been a failure in the restic-all service." >}}

## Removing aged restic snapshots

One last area to look at with restic is [pruning](https://restic.readthedocs.io/en/latest/060_forget.html), this is where restic will remove old data that has been "forgotten".

Back in `restic-all.sh` we are calling `restic forget` after each backup - this tells restic to clean up any old snapshots not required by our defined backup policy. The script has been written to accommodate for both `backup` and `prune` functionality, so in order to execute that portion of the script we need to set up another systemd unit file to invoke it.

```systemd
# /etc/systemd/system/restic-prune.service

[Unit]
Description=Restic backup service (data pruning)
OnFailure=unit-status-mail@%n.service

[Service]
Type=oneshot
ExecStart=/home/jdheyburn/dotfiles/restic/restic-all.sh prune
```

Since it is resource intensive to perform `prune` against your repository, its best to run this at a different interval to your backups. From the below unit file `OnCalendar=*-*-1 10:00:00` corresponds to the first day of the month at 10am.

```systemd
[Unit]
Description=Prune data from the restic repository monthly

[Timer]
OnCalendar=*-*-1 10:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

## Restoring a backup

Now the most important part - how to restore a restic snapshot. Let's start with how to restore from a local repository.

### Restore from local restic repository

Firstly we need to find the snapshot ID that we want to restore to - in this example I want the latest snapshot.

```bash
$ restic -r /mnt/usb/Backup/restic/small-files/ snapshots --last
repository 79dbc9b6 opened successfully, password is correct
found 1 old cache directories in /root/.cache/restic, run `restic cache --cleanup` to remove them
ID        Time                 Host        Tags           Paths
------------------------------------------------------------------------------------------
f7ef9c33  2021-04-17 02:00:51  dee         systemd.timer  /etc/pihole
                                                          /mnt/usb/Backup/media/beets-db
                                                          /var/lib/unifi/backup/autobackup

e2a73c00  2021-04-21 02:00:21  dee         systemd.timer  /etc/pihole
                                                          /var/lib/unifi/backup/autobackup

722fcbbf  2021-05-04 02:00:34  dee         systemd.timer  /etc/pihole
                                                          /mnt/usb/Backup/lms
                                                          /var/lib/unifi/backup/autobackup
------------------------------------------------------------------------------------------
3 snapshots
```

So the ID is `722fcbbf`, let's browse the contents to see if the file we want is in there.

```bash
$ restic -r /mnt/usb/Backup/restic/small-files/ ls 722fcbbf
repository 79dbc9b6 opened successfully, password is correct
found 1 old cache directories in /root/.cache/restic, run `restic cache --cleanup` to remove them
snapshot 722fcbbf of [/var/lib/unifi/backup/autobackup /etc/pihole /mnt/usb/Backup/lms] filtered by [] at 2021-05-04 02:00:34.383403601 +0100 BST):
/etc
/etc/pihole
/etc/pihole/GitHubVersions
/etc/pihole/adlists.list
# ... removed for brevity
```

Let's say we want to restore `/etc/pihole/adlists.list`, we can use the `--include` argument to specify just that. If we didn't use a filter argument then restic would default to restoring the entire contents of the snapshot.

```bash
$ restic -r /mnt/usb/Backup/restic/small-files/ restore 722fcbbf --target /tmp/restic-restore --include /etc/pihole/adlists.list
repository 79dbc9b6 opened successfully, password is correct
found 1 old cache directories in /root/.cache/restic, run `restic cache --cleanup` to remove them
restoring <Snapshot 722fcbbf of [/var/lib/unifi/backup/autobackup /etc/pihole /mnt/usb/Backup/lms] at 2021-05-04 02:00:34.383403601 +0100 BST by root@dee> to /tmp/restic-restore

$ tree /tmp/restic-restore/
/tmp/restic-restore/
└── etc
    └── pihole
        └── adlists.list
```

### Restore from B2 restic repository

We're storing the repositories on B2 too, and restic has B2 integration built into it. So in the scenario where the NFS server had died and we needed to restore a snapshot stored on B2, we can hit it directly without having to use rclone to pull down the entire repository for us to restore from. This'll be a cheaper approach as restic is only pulling down the files it needs to restore from, lowering B2 download costs.

We just need to configure some variables to permit restic to hit B2. If you're using rclone you can use the same ID and key here.

```bash
export B2_ACCOUNT_ID="ACCCOUNT_ID"
export B2_ACCOUNT_KEY="ACCCOUNT_KEY"
export RESTIC_PASSWORD_FILE="/path/to/passwordfile
restic -r b2:BUCKET_NAME:restic/small-files snapshots --last
```

From here you can then use the same commands as in the local repository to traverse the snapshots and restore.

## Conclusion

The process above is probably more complex than what it needs to be; having a separate process for backing up and restoring. Since I want to back up to the NFS locally first followed by B2, this approach made the most sense as it allows me to minimise download costs from B2 through targeting the local repository first.

What's most important is that backups are being made, and that I _can_ restore from them.
