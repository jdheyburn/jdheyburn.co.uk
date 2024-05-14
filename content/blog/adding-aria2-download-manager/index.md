---
date: 2024-05-13
title: Adding aria2 download manager to my NixOS homelab
description: I add aria2 as a download manager to a NixOS server to help bundle my Bandcamp downloads together
type: posts
tags:
  - aria2
  - bandcamp
  - caddy
  - nix
  - selfhosted
---

In this blog post I talk about how I host aria2 on a NixOS server. If you're coming here for the first time you can see [other posts related to nix](/tags/nix/).

## aria2 introduction

[aria2](https://aria2.github.io/) is command-line download tool that can support a wide variety of protocols - that can be ran as a server to allow remote invocation of downloads. Their home page describes it as:

> aria2 is a lightweight multi-protocol & multi-source command-line download utility. It supports HTTP/HTTPS, FTP, SFTP, BitTorrent and Metalink. aria2 can be manipulated via built-in JSON-RPC and XML-RPC interfaces.

Working in the command line is cool and definitely how I prefer doing things, however sometimes its nice to work with a UI for when you don't have a terminal ready. Additionally you would need to remember the commands to be able to get aria2 to download the files.

[AriaNg](https://github.com/mayswind/AriaNg) is a front-end that enables a UI for aria2. It's written in HTML and JavaScript so there is no complexity in getting it up and running. You tell a web server to host the files, and then configure AriaNg to connect to your aria2 instance!

{{< figure src="aria2-landing-page.png" link="aria2-landing-page.png" class="center" caption="" alt="Screenshot of the aria-ng web interface, showing two files are being downloaded" >}}

Also by fronting it with a service, any of the devices on my [Tailscale VPN](https://tailscale.com/) can access aria2 at a nice URL and download files in the background.

The primary use case this helps me solve is downloading music I've bought from Bandcamp. Since I download both the flac and mp3 zips, after a bulk purchase I download a load of files at once. My internet speed at home isn't great so this can take a while. Having a service where I can dump a list of files to download means I can set the download off, then come back to it another time.

{{< figure src="aria2-example-download.png" link="aria2-example-download.png" class="center" caption="" alt="Starting new downloads in aria-ng, showing a text box accepting multiple URLS for download" >}}

## Deploying with NixOS

Now that I'm all-in on NixOS for managing my services at home, let's get together the config for deploying this set up.

Firstly I'll need to deploy aria2 as a headless daemon, which is available in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/2057814051972fa1453ddfb0d98badbea9b83c06/nixos/modules/services/networking/aria2.nix).

```nix
services.aria2 = {
    enable = true;
    rpcSecretFile = config.age.secrets."aria2-password".path;
};

users.users.jdheyburn.extraGroups = [ "aria2" ];
```

`rpcSecretFile` expects a file path containing a string of the password which should be set for aria2. I manage my secrets with [agenix](https://github.com/ryantm/agenix), but explaining how it works is beyond the scope of this blog post. If you're trying it out I suggest just creating a temporary file containing the password to use.

I'm also adding my user to the `aria2` group so that I have permissions to modify the files after they've been downloaded.

After that I need to deploy the frontend, [AriaNg](https://github.com/mayswind/AriaNg). This is available in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/2057814051972fa1453ddfb0d98badbea9b83c06/pkgs/servers/ariang/default.nix) too, but only as a package and not as a service. Or rather, the package in nixpkgs only contains the HTML and JavaScript files for the frontend. We would need to roll our own web server to be able to host it.

Now I've mentioned [Caddy](https://caddyserver.com/) on my blog [before](/tags/caddy/) where I'm using it to reverse proxy my services at home. But here I can use it as a very simple web server - hosting files from a location!

```nix
services.caddy.virtualHosts."aria2.svc.joannet.casa" = {
    # Routing config inspired from below:
    # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
    extraConfig = ''
        file_server {
            root ${pkgs.ariang}/share/ariang
        }
        tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy /jsonrpc localhost:${toString config.services.aria2.rpcListenPort}
    '';
};
```

A big thanks to [LinuxServer.io](https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample) through which the [Caddy config](https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample) was inspired from.

In that config I'm using the [file_server directive](https://caddyserver.com/docs/caddyfile/directives/file_server) to specify that the root of the server should be served from the resulting directory that builds the AriaNg package as defined in [nixpkgs](https://github.com/NixOS/nixpkgs/blob/2057814051972fa1453ddfb0d98badbea9b83c06/pkgs/servers/ariang/default.nix). You can see that [this line in particular](https://github.com/NixOS/nixpkgs/blob/2057814051972fa1453ddfb0d98badbea9b83c06/pkgs/servers/ariang/default.nix#L27) is what copies the compiled AriaNg package to the directory. Once this config is built, the directive looks like this:

```caddyfile
file_server {
    root /nix/store/i8ln23gyx6icjmv78lfg7pn9nnibrnzp-ariang-1.3.7/share/ariang
}
```

After `file_server` we have the `tls` directive which instructs Caddy how to authenticate that the domain is owned by me - I've introduced this in a [previous blog post](/blog/reverse-proxy-multiple-domains-using-caddy-2/#proving-domain-ownership).

Lastly we have a `reverse_proxy` that will route any calls made to `https://aria2.svc.joannet.casa/jsonrpc` to the port `6800`, which is the port that the aria2 headless service is listening on for remote download invocations. You'll see us config AriaNg to use this endpoint later.

Once these configs are defined, you can have NixOS deploy out the changes:

```bash
nixos-rebuild switch
```

## Configuring AriaNg

Remember when I said that AriaNg was just a bunch of HTML and JavaScript? Well it doesn't hold any state on the server-side, that is all managed by [local storage in your browser](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage). This includes configurations such as authentication, appearance, and even where AriaNg should look for aria2. So if we were to load up the frontend after the install, it won't be able to connect.

{{< figure src="aria2-unconfigured.png" link="aria2-unconfigured.png" class="center" caption="" alt="Landing page for aria-ng immediately after setup. The aria2 status is labelled as disconnected" >}}

Looking at dev tools we can see why it's failing.

{{< figure src="aria2-fresh-install-failures.png" link="aria2-fresh-install-failures.png" class="center" caption="" alt="Dev tools console output for aria-ng after setup. There are failed requests going to the default aria2 URL" >}}

By default AriaNg is trying to connect to aria2 at `https://aria2.svc.joannet.casa:6800/jsonrpc`, and failing. This is expected because we configured the reverse proxy for aria2 at `https://aria2.svc.joannet.casa:443/jsonrpc` - with port `443` being the port that HTTPS runs on (i.e. our Caddy server).

AriaNg has an [API](https://ariang.mayswind.net/command-api.html) for configuring the aria2 RPC (remote procedure call). We take the endpoint that AriaNg is available at and configure it using path parameters in this format:

```text
/#!/settings/rpc/set/${protocol}/${rpcHost}/${rpcPort}/${rpcInterface}/${secret}
```

Populating with what we have configured previously, we end up with:

```text
https://aria2.svc.joannet.casa/#!/settings/rpc/set/https/aria2.svc.joannet.casa/443/jsonrpc/REPLACE_WITH_ENCODED_PASSWORD
```

`REPLACE_WITH_ENCODED_PASSWORD` is the password for aria2 that we set in the password file located at `rpcSecretFile`, but base64 encoded. You can use the below command to find out what that would be.

```bash
# the -n flag will remove the newline from the echo command
echo -n "PASSWORD" | base64
```

Once we navigate to that URL in our browser, it authenticates us and creates that all important local storage to cache the settings for next time.

## Creating an aria2 NixOS module

NixOS is great for packaging all of this together into a module. In my repo I have an [aria2 module](https://github.com/jdheyburn/nixos-configs/tree/main/modules/aria2) which contains this:

```nix
{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.aria2;

in {

  options.modules.aria2 = { enable = mkEnableOption "enable aria2 with a web client for managing downloads"; };

  config = mkIf cfg.enable {

    services.caddy.virtualHosts."aria2.svc.joannet.casa" = {
      # Routing config inspired from below:
      # https://github.com/linuxserver/reverse-proxy-confs/blob/20c5dbdcff92442262ed8907385e477935ea9336/aria2-with-webui.subdomain.conf.sample
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        reverse_proxy /jsonrpc localhost:${toString config.services.aria2.rpcListenPort}
        file_server {
          root ${pkgs.ariang}/share/ariang
        }
      '';
    };

    # TODO retrieve primary user programatically
    # Needed so that I can modify downloaded files
    users.users.jdheyburn.extraGroups = [ "aria2" ];

    age.secrets."aria2-password".file =
      ../../secrets/aria2-password.age;

    services.aria2 = {
      enable = true;
      rpcSecretFile = config.age.secrets."aria2-password".path;
    };
  };
}
```

Any modules defined in this directory are [automatically loaded](https://github.com/jdheyburn/nixos-configs/blob/f59b9cdfb1bb1557343841e139c4a3ba9108e370/flake.nix#L50-L55) into each host. For a host to deploy the module, I simply need to add this line.

```nix
modules.aria2.enable = true;
```

## Fin

If you're in the market for a download manager then definitely check out aria2 + AriaNg to see if they fit the bill. I'm not sure if it's something I'll stick with forever, but it's simplicity is a pull factor for me.

The only downside to it is the manual step to get AriaNg configured with the backend. If you have any tips on how that could be improved then feel free to [reach out](/contact/) to me!
