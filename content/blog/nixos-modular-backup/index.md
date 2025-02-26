---
date: 2024-12-24
title: Modularising Restic backups in NixOS and monitoring with Healthchecks
description: 
type: posts
tags:
  - nix
  - restic
---

## tl;dr

- I've [written before](/blog/backup-to-backblaze-b2-using-restic-and-rclone/) about how I backup to Backblaze B2 with restic and rclone
- That set up was from before I migrated to NixOS
- After migrating I had a pretty messy way of configuring backups
- Seeking inspiration from when I [Caddy config refactor](/blog/caddy-nix-config-refactor/), I can do something similar with restic backups too
- That was done in these PRs:
  - https://github.com/jdheyburn/nixos-configs/pull/77/files
  https://github.com/jdheyburn/nixos-configs/pull/80/files

## Another gentle reminder

Tis the season to make my NixOS configs a lot simpler. I made great headway doing this for [Caddy](/blog/caddy-nix-config-refactor/) and so I wanted to do the same for configuring restic configs too.

The way I had been configuring restic to backup directories in NixOS was defining a backup module for the target restic repository (small-files), and having a bunch of conditionals in the host configuration to check if a module is enabled, then including that directory to backup.

```nix
let
  backupPaths = with lib;
    (optional config.services.unifi.enable
      "/var/lib/unifi/data/backup/autobackup")
    ++ (optionals config.services.adguardhome.enable [
      "/var/lib/AdGuardHome/"
      "/var/lib/private/AdGuardHome"
    ]) ++ (optionals config.services.plex.enable
      [ ''"/var/lib/plex/Plex Media Server"'' ]);

  backupExcludePaths = with lib;
    concatStrings [
      "--exclude="
      (concatStringsSep " " (optionals config.services.plex.enable
        [ ''"/var/lib/plex/Plex Media Server/Cache"'' ]))
    ];
in {
  modules.backupSF = {
    enable = true;
    passwordFile = config.age.secrets."restic-small-files-password".path;
    paths = backupPaths;
    extraBackupArgs = [ backupExcludePaths ];
    prune = true;
    healthcheck =
      "https://healthchecks.svc.joannet.casa/ping/2d062a25-b297-45c0-a2b3-cdb188802fb8";
  };
}
```

This is very complicated, and means that if I were to enable a module on a host, I'd have to also include the conditional in the host configuration to backup that location if it's enabled.

## Simplicity

A much simpler approach is to have a declaration within the module of the backup directory in restic. 

```nix
services.restic.backups.BACKUP_NAME = {
  paths = [
    "/path/to/backup"
  ];
};
```

Continuing on from the [Plex example from my previous blog post](/blog/caddy-nix-config-refactor/#i-have-seen-the-light).

```nix
{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.plex;
in {
  options.modules.plex = { enable = mkEnableOption "Deploy plex"; };

  config = mkIf cfg.enable {

    services.restic.backups.small-files = {
      paths = [
        config.services.plex.dataDir
      ];
      exclude = [ "/var/lib/plex/Plex Media Server/Cache" ];
    };

    services.caddy.virtualHosts."plex.svc.joannet.casa".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      reverse_proxy localhost:32400
    '';

    services.plex = {
      enable = true;
      openFirewall = true;
    };
  };
}
```

Note that this doesn't enable the backup, it just adds the configuration which will only be read if the backup module is enabled.

For that I have a separate module to manage the backup definition:

```nix
{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.modules.backup.small-files;
in
{

  options.modules.backup.small-files = {
    enable =
      mkEnableOption "Enable backup of defined paths to small-files repo";

    repository = mkOption {
      type = types.str;
      default = "rclone:b2:iifu8Noi-backups/restic/small-files";
    };

    passwordFile = mkOption { type = types.path; };

    rcloneConfigFile = mkOption { type = types.path; };

    backupTime = mkOption {
      type = types.str;
      default = "*-*-* 02:00:00";
    };
  };

  config = mkIf cfg.enable {
    services.restic.backups.small-files = {
      repository = cfg.repository;
      rcloneConfigFile = cfg.rcloneConfigFile;
      passwordFile = cfg.passwordFile;
      timerConfig = { OnCalendar = cfg.backupTime; };
    };
  };
}
```

There's a lot going on there, but really this backup module declares the "small-files" restic backup should it be enabled - which gets enabled in the host configuration file:

```nix
modules.backup.small-files = {
  enable = true;
  rcloneConfigFile = config.age.secrets."rclone.conf".path;
  passwordFile = config.age.secrets."restic-small-files-password".path;
};
```

The end configuration looks like this:

- Define the backup repository at `rclone:b2:iifu8Noi-backups/restic/small-files`
- Because this restic repository is backed by rclone, use the rclone config file path location defined by agenix
- The password for the restic repository can be found at the path location also defined by agenix
- Execute the backup at 2am server time

TODO refactor agenix to be in the backup module?

The paths to backup are then loaded in from anywhere that `services.restic.backups.small-files.paths` is defined. When defining options as lists, they are all coalesced together into a single list, as opposed to overwriting one another.

## Managing backup lifecycles with pruning

One of the nuances with restic is maintaining the lifetime of snapshots (the backups themselves) via pruning. This is where you specify how long to keep snapshots around for, while removing any data that is no longer referenced in snapshots. While restic backups can be executed against the same repository concurrently, this is not the case for pruning, where pruning requires exclusive access for the duration of its run. It achieves that by obtaining a lock on the restic repository. So restic backups can be done on any host at the same time, but only one host should be the "pruner".

Pruning in the NixOS module is [enabled](https://github.com/NixOS/nixpkgs/blob/799ba5bffed04ced7067a91798353d360788b30d/nixos/modules/services/backup/restic.nix#L354-L356) when you set [pruneOpts](https://github.com/NixOS/nixpkgs/blob/799ba5bffed04ced7067a91798353d360788b30d/nixos/modules/services/backup/restic.nix#L221-L236) in the restic service. For this I declare another 

The backup module takes additional options to declare this. You'll notice the prune time is 30 minutes after `backupTime`, which would be enough time for all the backups to complete.

```nix
    prune = mkOption {
      type = types.bool;
      default = false;
    };

    pruneTime = mkOption {
      type = types.str;
      default = "Tue *-*-* 02:30:00";
    };
```

In the config, I now add a conditional to only create the prune service when `cfg.prune` is enabled. We can reuse the other options we already declared to interact with the repository.

```nix
  config = mkIf cfg.enable (mkMerge [
    {
      services.restic.backups.small-files = {
        # ... removed for brevity
      };
    }

    (mkIf cfg.prune {
      services.restic.backups.small-files-prune = {
        repository = cfg.repository;
        rcloneConfigFile = cfg.rcloneConfigFile;
        passwordFile = cfg.passwordFile;
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 3"
        ];
        timerConfig = { OnCalendar = cfg.pruneTime; };
      };
    })
  ]);
```

The restic module will only create snapshots if `paths` is [defined](https://github.com/NixOS/nixpkgs/blob/799ba5bffed04ced7067a91798353d360788b30d/nixos/modules/services/backup/restic.nix#L353). Our modules that require backups are defining the paths at `services.restic.backups.small-files.paths`, and not `services.restic.backups.small-files-prune.paths`, so this prune service will only be pruning and not creating snapshots. The systemd ExecStart for this service looks like this:

```bash
/nix/store/5265q4gb7cybk7cjj0b4nyk2wigihbxf-restic-0.17.3/bin/restic forget --prune --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 3
```

I enable it on one host configuration file, while leaving it disabled for any others.

```nix
modules.backup.small-files = {
  enable = true;
  rcloneConfigFile = config.age.secrets."rclone.conf".path;
  passwordFile = config.age.secrets."restic-small-files-password".path;
  # Prune should only be executed on one host
  prune = true;
};
```

## Monitoring backups with Healthchecks

For monitoring the backup jobs to ensure they're running, I use [Healthchecks.io](https://healthchecks.io/) which is a great tool for monitoring cron jobs. I [selfhost](https://github.com/jdheyburn/nixos-configs/blob/4cb8e26732db1507ea25e8f0dbc9d2b20e177aad/modules/healthchecks/default.nix) it in NixOS, but I'll probably cover that in some more detail in a future post.

{{< figure src="healthchecks-overview.png" link="healthchecks-overview.png" class="center" caption="" alt="Landing page for healthchecks once set up and logged in, there are a multitude of checks that are OK, and failing" >}}

It works by operating as a dead man's switch, expecting check-ins on a cadence that you define. If a check-in does not happen, then the health check fails and the notification methods are informed - email in my case. Healthchecks has some extra features too; such as allowing you to specify when the cron job has started to view the job duration on completion, and submitting a failure with a non-zero exit status.

Once you've got Healthchecks up and running, you can add a check for a new backup.

{{< figure src="healthchecks-add-check.png" link="healthchecks-add-check.png" class="center" caption="" alt="Healthcheck page for creating a new healthcheck" >}}

{{< figure src="healthchecks-check-overview.png" link="healthchecks-check-overview.png" class="center" caption="" alt="An overview page for a healthcheck, there is a section that provides the endpoint to use to submit health checks against" >}}

You'll be given a URL which is the endpoint used for the dead man's switch. This needs to be plugged into the service that is running our backups. Going back to the module I use for backups, I expose this as an option.

```nix
healthcheck = mkOption {
  type = types.str;
};
```

The restic module has a `backupPrepareCommand` option for allowing us to execute a hook prior to the backup taking place, which is a great place for us to ping the health check start endpoint. It's added to the `ExecStartPre` command of the systemd service for the backup job.

```nix
backupPrepareCommand = "${pkgs.curl}/bin/curl ${cfg.healthcheck}/start";
```

While the module also has a `backupCleanupCommand` option for executing a hook post backup, and is added to the `ExecStartPost` command of the service. This is always executed, regardless of the success or failure of the pre-hook and main execution commands. So for us to determine the exit status of the backup execution so that we can forward it onto Healthchecks, we need to set a small script to help with that:

```bash
preStartExitStatus=$(systemctl show restic-backups-small-files --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
echo "preStartExitStatus=$preStartExitStatus"
echo "EXIT_STATUS=$EXIT_STATUS"
[ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
${pkgs.curl}/bin/curl ${cfg.healthcheck}/$returnStatus
```

The first line aims to retrieve the exit status of the pre-hook and make it accessible at the variable `preStartExitStatus`. Systemd already exposes the exit status of the main backup command at `EXIT_STATUS`. We then fire off a curl request to the health check endpoint using the pre-hook exit status if it is non-zero, else we will use the main backup command instead.

Bringing those two options into our restic service now looks like this:

```nix
services.restic.backups.small-files = {
  repository = cfg.repository;
  rcloneConfigFile = cfg.rcloneConfigFile;
  passwordFile = cfg.passwordFile;
  timerConfig = { OnCalendar = cfg.backupTime; };
  backupPrepareCommand = "${pkgs.curl}/bin/curl ${cfg.healthcheck}/start";
  backupCleanupCommand = ''
    preStartExitStatus=$(systemctl show restic-backups-small-files --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
    echo "preStartExitStatus=$preStartExitStatus"
    echo "EXIT_STATUS=$EXIT_STATUS"
    [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
    ${pkgs.curl}/bin/curl ${cfg.healthcheck}/$returnStatus
  '';
};
```

The prune job has a health check endpoint too, but given this operates as a singleton (only should be executed on one host) I declare a variable for it and reference that in the scripts.

```nix
# Prune would only be executed on one host, so it has a static healthcheck
healthcheckPrune = "https://healthchecks.${catalog.domain.service}/ping/fea7ebdd-b6dc-4eb5-b577-39aff3966ad4";

# ...

services.restic.backups.small-files-prune = {
  repository = cfg.repository;
  rcloneConfigFile = cfg.rcloneConfigFile;
  passwordFile = cfg.passwordFile;
  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
    "--keep-yearly 3"
  ];
  timerConfig = { OnCalendar = cfg.pruneTime; };
  backupPrepareCommand = "${pkgs.curl}/bin/curl ${healthcheckPrune}/start";
  backupCleanupCommand = ''
    preStartExitStatus=$(systemctl show restic-backups-small-files-prune --property=ExecStartPre | grep -oEi 'status=([[:digit:]]+)' | cut -d '=' -f2)
    echo "preStartExitStatus=$preStartExitStatus"
    echo "EXIT_STATUS=$EXIT_STATUS"
    [ $preStartExitStatus -ne 0 ] && returnStatus=$preStartExitStatus || returnStatus=$EXIT_STATUS
    ${pkgs.curl}/bin/curl ${healthcheckPrune}/$returnStatus
  '';
};
```

One of the common reason for backups failing is that pruning can't obtain a lock on the repository. A stale lock can happen if the host crashed for whatever reason (a frequent issue on my Raspberry Pi). The failure on the next iteration traverses up to Healthchecks nicely with the status code of the failure.

{{< figure src="healthchecks-failing-check.png" link="healthchecks-failing-check.png" class="center" caption="" alt="Failing checks in Healthchecks, the status is green up until a backup fails to finish, when the status is marked down. On the next invocation, it fails for Status 11" >}}

## Backup strategy

Talk about my backup strategy, or remind readers of it
- small-files
- media


