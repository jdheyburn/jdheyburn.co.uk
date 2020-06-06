---
date: 2020-06-06
title: "Reverse Proxy Against Multiple Domains Using Caddy 2"
description: Enter description
type: posts
images:
    - images/jdheyburn_co_uk_card.png
draft: true
---

During lockdown, I've spent a bit of time improving our home network. The bigger picture of which I'll write about in a future post. But for now, I came across some challenges with running Caddy 2 as a reverse proxy for multiple domains used internally.

If you've stumbled across this looking for the end config file for [Caddy](https://caddyserver.com/), then skip there. TODO add URL.

## Background

A few months back I kitted out my home with some Ubiquiti UniFi gear to fix our crappy Wifi at home, following inspiration from [Troy Hunt](https://www.troyhunt.com/ubiquiti-all-the-things-how-i-finally-fixed-my-dodgy-wifi/) and [Scott Helme](https://scotthelme.co.uk/my-ubiquiti-home-network/). It's been a slow burner getting it to a state where I'm happy to share about it - that won't be today however. 

In order to administrate UniFi devices, you need the UniFi Cloud Key which runs the Controller software to do just that. Although if you have a spare Raspberry Pi lying around, you can download the software for free and run it on there.

I've also wanted to protect my home network with a self-hosted DNS server, such as PiHole. I won't go into depth about how that was done, but you can follow [Scott Helme's guide](https://scotthelme.co.uk/securing-dns-across-all-of-my-devices-with-pihole-dns-over-https-1-1-1-1/) on how you can set the same up.

Both of these services can be accessed through web browsers at the IP address and ports where they are being hosted, such as http://192.168.3.14:80/admin/. But having to remember the IP address and the port can be a pain. We can front these services with a rememberable domain name which points to these services - of which I've written about in a previous post. TODO link to custom domain

The web is evolving, and there is no reason why we should access services via insecure HTTP, so for HTTPS we need to have a certificate to encrypt the communications. 

Caddy is a web server similar to Apache, nginx, et al., but it is different in that it enables HTTPS by default and upgrading requests from HTTP to HTTPS. Managing certificates for HTTPS is a pain - so Caddy does that too. We can use Caddy in a reverse proxy mode, allowing us to access services at domains such as `pihole.domain.local` and forward them to the corresponding IP address hosting the service.


Plan:

- introduction to the background
- Caddy setup
    - Acquire domains
    - Build caddy
- Config for caddy
- Run it, verify the endpoints

## Building Our Caddy

Caddy 2 allows for extensions to be built into the binary depending on your use case.  comes with a bunch of extensions

## Configuration

The end result looks like this in it's entirety.

TODO add config



## Enabling Caddy Service

Since we're not using the standard Caddy installation method, we will need to specify a service unit file so that Caddy starts up at the same time as the host - which is what my services PiHole and UniFi are doing currently.

First check to see if there is a stale service there already.

```
$ ls -la /etc/systemd/system/caddy.service
lrwxrwxrwx 1 root root 9 Jun  4 09:14 /etc/systemd/system/caddy.service -> /dev/null
```

If you get the above then remove the symlink so that we can create a file there: `rm /etc/systemd/system/caddy.service`

Then populate the same file with the below, remembering the change the location of the Caddy config file to where it exists on your machine.

```
[Unit]
Description=Caddy Reverse Proxy
Wants=network-online.target
After=network.target network-online.target
 
[Service]
ExecStart=/usr/local/bin/caddy run --config /home/jdheyburn/homelab/caddy/config.json
Restart=on-abort
 
[Install]
WantedBy=multi-user.target
```

Finalise the new service with the two commands, enabling it on host startup and starting the service right now.

```bash
sudo systemctl enable caddy.service
sudo systemctl start caddy.service
```

## Conclusion

For now I have all the above running bare-metal on one Pi instance, which produces a huge single point of failure in my network. In the future I'd like to see how converting these to Docker containers and having them distributed on multiple Pis would increase the resiliency of these services.

Until then, these basic but essential services are being hosted at easy to remember domains, transported over an encrypted connection,  for me to easily administer the network for when it gets more complex over time.