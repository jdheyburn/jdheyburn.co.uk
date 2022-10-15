---
title: Converting to the Church of Nix
description: Enter description
type: posts
images:
  - images/jdheyburn_co_uk_card.png
draft: true
date: 2022-10-02
---

I've [written in the past](/blog/reverse-proxy-multiple-domains-using-caddy-2/) about some services I host at home which was running on a Raspberry Pi 3 using Raspbian as its OS. As a normal person I was making changes live on the box and not using a configuration management tool like Ansible. So should anything happen to the host and it dies, I won't have a way to reproduce what I had working before...

So naturally last December the Pi SD card got corrupted and so lost whatever was on there..!

Rather than rebuilding things how they were, knowing that I'd probably get something wrong along the way, I wanted to look into a better way to ensure I could reproduce services installed on a host to mitigate this in the future. NixOS came to mind as I had been aware of it over the last few years, and I actually had an attempt to get it working on the Pi and on my Dell XPS 9360 in the past with unsuccessful results. This time round there is much greater support for NixOS on Pi, and coupled with some more motivation I decided to make the switch.

In this series I'll be writing about my setup, how I deploy modules, onboarding flakes, and problems I came across along the way. The series will be more NixOS config management orientated, while being referred back to in other posts where I'll talk about some of the services I'm running via NixOS. This post kicks off with a quick introduction with some more in-depth posts to come.

## Why NixOS

This is something that's been discussed several times over, so I'll spare you and myself and instead list out some other posts by some very knowledgeable people which have already done the same.

## Setup

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

| Service                                    | Purpose                                                                                                                   |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| [Heimdall](https://heimdall.site/)         | Dashboard for services                                                                                                    |
| [Huginn](https://github.com/huginn/huginn) | Experiment with automation (such as [NHS vaccine alerts](/blog/alerting-on-nhs-coronavirus-vaccine-updates-with-huginn/)) |
| [Portainer](https://www.portainer.io/)     | UI for docker containers                                                                                                  |

### Today

Host frank is unchanged from above today, while here's what I have running elsewhere.

#### dee

Upgraded to a Raspberry Pi 4 (NixOS is RAM hungry!) in an Argon One case.

| Service                                                   | Purpose                                                   |
| --------------------------------------------------------- | --------------------------------------------------------- |
| [AdGuardHome](https://github.com/AdguardTeam/AdGuardHome) | For adblocking and local DNS resolution (replaces PiHole) |
| [Caddy](https://caddyserver.com/)                         | Reverse proxy for services _local to the host_            |
| [Healthchecks](https://healthchecks.io/)                  | Monitor cron jobs (primarily the backup jobs for now)     |
| [Minio](https://min.io/)                                  | S3 compatible storage                                     |
| NFS server                                                | Network wide storage, backed up to cloud storage          |
| [Plex](https://www.plex.tv/)                              | Music and video player                                    |
| UniFi Controller                                          | Control plane for UniFi devices                           |

#### dennis

New VM running NixOS on the Proxmox HV. I built this as I had some RAM issues on dee, which I subsequently fixed but ended up putting more services on there to experiment with multiple hosts.

| Service                                                                | Purpose                                                              |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [Caddy](https://caddyserver.com/)                                      | Reverse proxy for services _local to the host_                       |
| [Dashy](https://dashy.to/)                                             | Replaces Heimdall as a dashboard for services                        |
| [Grafana](https://grafana.com/)                                        | Metric and log visualisation                                         |
| [Loki](https://grafana.com/oss/loki/)                                  | Log collections                                                      |
| [Prometheus](https://prometheus.io/) with [Thanos](https://thanos.io/) | Metric scraping and long term storage                                |
| [Victoria Metrics](https://victoriametrics.com/)                       | Metric scraping (just testing as a potential Prometheus replacement) |

## Configurations

Since NixOS can be used to build packages and services, it can also be used to build configurations. I have defined a service "catalog" which acts as a source of truth for services, so that dependent services can refer back to this to build their own config. Some examples of this are generating configs used for:

- DNS rewrites to forward DNS names to the host hosting the service
- Reverse proxy the service to the port
- Dashy for the home dashboard
- Prometheus monitoring service endpoints
- TODO find more?

Each of these I'll write about in more detail in future posts - which I'll link back here once they're done.

You can explore the repo yourself in the meantime.
