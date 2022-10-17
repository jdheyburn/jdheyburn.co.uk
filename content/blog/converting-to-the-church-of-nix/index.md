---
title: Converting to the Church of Nix
description: Migrating self-hosted services to NixOS
type: posts
date: 2022-10-17
---
  

I've [written in the past](/blog/reverse-proxy-multiple-domains-using-caddy-2/) about some services I host at home which were running on a Raspberry Pi 3 with Raspbian. Making changes to the host was done ad-hoc with no configuration management tool like Ansible, so should anything happen to the host and it dies, I won't have a way to reproduce what I had working before.

Naturally last December, the Pi SD card got corrupted and lost everything that was on there.

Rather than rebuilding things how they were in the same way as before, I wanted to look into a better way to ensure I could reproduce services installed and manage configurations on a host to mitigate this in the future.

NixOS came to mind as it solves these problems and more, I had tried to get it working on the Pi and on my Dell XPS 9360 laptop in the past with unsuccessful results. This time round there is much greater support for NixOS on Pi, and coupled with some more motivation, I decided to make the switch.

In this series I'll be writing about my setup, how I deploy modules, onboarding flakes, and problems I came across along the way. The series will be more NixOS config management orientated, while being referred back to in other posts where I'll talk about some of the services I'm running via NixOS. This post kicks off with a quick introduction with some more in-depth posts to come.

## Why NixOS

For a quick 411, there are 3 components that fall under the "Nix" umbrella:

- Nix / Nixlang
    - The functional, declarative language that is used to build, manipulate, packages, files, configurations, within the ecosystem
- Nixpkgs
    - A package manager that can be installed on a Linux machine, or on macOS via [nix-darwin](https://github.com/LnL7/nix-darwin)
    - Think an alternative to `apt`, `brew`, etc.
- NixOS
    - An operating system that uses Nixpkgs as its package manager, but also can configure OS-level configurations, hardware settings, services, via Nixlang

Nixpkgs are designed to be easily reproducible by defining explicit versions and hashes of software and its dependencies - and the same goes for NixOS which takes this same philisophy and applies it beyond software. Nix builds this software and stores it in the Nix store (appropriately named `/nix/store`), where a previous deployment of a configuration can be rolled back easily with a single command. This makes it useful for experiments or to rollback when shit hits the fan.

There are plenty of talented people who have written about it before, so I'll link them here:

- [NixOS manual introduction](https://nixos.org/manual/nix/stable/introduction.html)
- [How to Learn Nix, Part 1: What's all this about?](https://ianthehenry.com/posts/how-to-learn-nix/introduction/)

So the 3 components together allow for some pretty powerful stuff. Your NixOS configurations are written to a `.nix` suffixed file by default located at  `/etc/nixos/configuration.nix`, which can contain minimal config:

```nix
{ config, pkgs, ... }:

{
  networking.hostName = "my-hostname"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.my-user = {
    isNormalUser = true;
    home = "/home/my-user";
    extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
    password = "hunter2";
  };

  environment.systemPackages = with pkgs; [
    vim
  ];
}
```

Whenever we want to deploy the configuration to make it live, we can use the command `nixos-rebuild switch`, which will read this file and build the packages and configurations requested.

Should we want to have Firefox installed? We can just define it:

```nix
environment.systemPackages = with pkgs; [
  vim
  # add in the below
  firefox
];
```

If we want to enable SSH access to our hosts, it's easy to do that:

```nix
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = true;
  };
```

Services are usually defined with the syntax `services.SERVICE_NAME.enable`, however as shown above we can see `permitRootLogin` and `passwordAuthentication` attributes are defined. These inputs are read by the [service in nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/ssh/sshd.nix#L148) to then be [output as configuration](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/networking/ssh/sshd.nix#L533) for the service.

One last example, what if the service we just deployed requires a particular port opened? NixOS can do that too!

```nix
networking.firewall.allowedTCPPorts = [ 4040 ];
```

When you compare that against traditional package managers, you would first have to install the software *and then* configure it, probably by hand. On top of that, you would have to manage the versioning of the configuration using another tool. **NixOS does all of that for you** - provided that you're checking in your NixOS configuration files!

Just to cap off - if something broke during the `nixos-rebuild switch` command and you want to go back to the previous state, then we can do so with `nixos-rebuild switch --rollback`.

## Layout

Before going into the details of the setup I'm running I think it helps to have some context of where I was before the migration.

### Legacy

Prior to starting this, I had this setup across my network:

#### dee

My starting point for playing with self-hosting, it was a Raspberry Pi 3.  

| Service                           | Purpose                                          |
| --------------------------------- | ------------------------------------------------ |
| [Caddy](https://caddyserver.com/) | Reverse proxy for all services in the network    |
| NFS server                        | Network wide storage, backed up to cloud storage |
| [PiHole](https://pi-hole.net/)    | For adblocking and local DNS resolution          |
| UniFi Controller                  | Control plane for my UniFi devices at home       |

#### frank

A Ubuntu VM on a Proxmox hypervisor, built so that I could play with Proxmox and docker containers.

| Service | Purpose |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| [Heimdall](https://heimdall.site/) | Dashboard for services |
| [Huginn](https://github.com/huginn/huginn) | Experiment with automation (such as [NHS vaccine alerts](/blog/alerting-on-nhs-coronavirus-vaccine-updates-with-huginn/)) |
| [Portainer](https://www.portainer.io/) | UI for docker containers |

### Today

Host frank is unchanged from above today, while here's what I have running elsewhere.

#### dee
Upgraded to a Raspberry Pi 4 (NixOS is RAM hungry!) in an [Argon One case](https://thepihut.com/products/argon-one-m-2-raspberry-pi-4-case).  

| Service | Purpose |
| --------------------------------------------------------- | --------------------------------------------------------- |
| [AdGuardHome](https://github.com/AdguardTeam/AdGuardHome) | For adblocking and local DNS resolution (replaces PiHole) |
| [Caddy](https://caddyserver.com/) | Reverse proxy for services _local to the host_ |
| [Healthchecks](https://healthchecks.io/) | Monitor cron jobs (primarily the backup jobs for now) |
| [Minio](https://min.io/) | S3 compatible storage |
| NFS server | Network wide storage, backed up to cloud storage |
| [Plex](https://www.plex.tv/) | Music and video player |
| UniFi Controller | Control plane for UniFi devices |

#### dennis

New VM running NixOS on the Proxmox HV. I built this as I had some RAM issues on dee, which I subsequently fixed but ended up putting more services on there to experiment with multiple hosts.

| Service | Purpose |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [Caddy](https://caddyserver.com/) | Reverse proxy for services _local to the host_ |
| [Dashy](https://dashy.to/) | Replaces Heimdall as a dashboard for services |
| [Grafana](https://grafana.com/) | Metric and log visualisation |
| [Loki](https://grafana.com/oss/loki/) | Log collections |
| [Prometheus](https://prometheus.io/) with [Thanos](https://thanos.io/) | Metric scraping and long term storage |
| [Victoria Metrics](https://victoriametrics.com/) | Metric scraping (just testing as a potential Prometheus replacement) |

## Additional features

Besides NixOS itself, there are some extra features which I'm using in the stack:

- [nix flakes](https://xeiaso.net/blog/nix-flakes-1-2022-02-21)
    - Version pin dependencies
    - Allows for an additional layer of reproducibility
- [agenix](https://github.com/ryantm/agenix)
    - Encryption using [age](https://github.com/FiloSottile/age)
    - Allows for secrets to be safely checked in to Git repos so that they can be used in configurations
- [deploy-rs](https://github.com/serokell/deploy-rs)
    - Deploy NixOS configurations to hosts remotely
- [home-manager](https://github.com/nix-community/home-manager)
    - Allows configuration of user-level programs and settings
    - Typically used as a [dotfile](https://www.freecodecamp.org/news/dotfiles-what-is-a-dot-file-and-how-to-create-it-in-mac-and-linux/) manager, which can replace tools such as [chezmoi](https://www.chezmoi.io/)
    - Can be applied to non-NixOS machines
- [nixos-hardware](https://github.com/NixOS/nixos-hardware)
    - Crowdsourced configuration best practices to get NixOS running smoothly on particular hardware

## Configurations

Since NixOS can be used to build packages and services, it can also be used to build configurations. I have defined a service "catalog" which acts as a source of truth for services, so that dependent services can refer back to this to build their own config. Some examples of this are generating configs used for:

- DNS rewrites to forward DNS names to the host hosting the service
- Reverse proxy the service to the port
- Dashy for the home dashboard
- Prometheus monitoring service endpoints

The inspiration for having a centralised location for service catalog came from jhillyerd - where they [achieve the same thing](https://github.com/jhillyerd/homelab/blob/main/nixos/catalog.nix).

My NixOS configurations are stored in [GitHub](https://github.com/jdheyburn/nixos-configs), so you can have a browse through there. Subsequent posts will dive into what each of these is doing in more detail, but here's a high-level of the top-level directories.

`common/`
- Settings that are applied to all hosts

`home-manager/`
- User-level programs and settings

`hosts/`
- Configurations for individual hosts, along with their hardware configs via [nixos-hardware](https://github.com/NixOS/nixos-hardware)

`modules/`
- Where services and their dependencies are defined
- Rarely do I install software via just `services.SERVICE_NAME.enable = true`, there is usually extra properties to come with it - so having wrapping them in a custom module is usually easiest for me to maintain

`overlays/`
- Nix overlays allow you to overwrite packages and configurations pulled from a dependency
- In my case here, I'm using it to fix some bugs in one program, and add functionality to another

`secrets/`
- Where agenix secrets are stored

`catalog.nix`
- Contains information about the various services and where

`flake.nix`
- The main entry point into the configurations when deploying

## Conclusion

This is only a quick introduction into the series which introduces NixOS, what I'm using it for, and a high-level look into the configurations.
