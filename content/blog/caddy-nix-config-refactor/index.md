---
date: 2024-03-07
title: Simplifying Caddy Nix Config
description: I refactor my Caddy configs from the unnecessarily complex method to something a whole lot more simpler
type: posts
tags:
  - caddy
  - nixos
---

## tl;dr

- My Caddy configs before were [bloody awfully](/blog/automating-service-configurations-with-nixos/#caddy-config) complicated
- I scrapped that way of doing it and made it simpler in [this pull request](https://github.com/jdheyburn/nixos-configs/pull/66)

## A gentle reminder

I've written before about how I use Caddy to [reverse proxy](/blog/reverse-proxy-multiple-domains-using-caddy-2/) my internal services. Since then I've migrated to NixOS and am using that to [automatically generate](/blog/automating-service-configurations-with-nixos/#caddy-config) the Caddy config.

However the approach I used was extremely over-engineered and unnecessarily complicates one of the benefits of Caddy, which is the simplicity of its [Caddyfile DSL](https://caddyserver.com/docs/caddyfile). It was interesting to see how I could generate configs from Nix attribute sets, which served as a learning exercise and the basis for the [Nix cheat sheet](blog/nix-cheat-sheet/).

NixOS allows you to [specify Caddy config](https://github.com/NixOS/nixpkgs/blob/abde03c6b3d19be0a69c57e5a1f475b03a09dd71/nixos/modules/services/web-servers/caddy/default.nix#L11-L48) in a way that allows you to modularise it. Migrating to this structure will provide cleaner code for future iterations.

Previously I had created the [module for Caddy](https://github.com/jdheyburn/nixos-configs/blob/5175593745a27de7afc5249bc130a2f1c5edb64c/modules/caddy/default.nix) in such a way that it would discover what services required a reverse proxy fronting it on said host. This snippet from the previous config would look up from the catalog for any services that were due to be hosted on this machine, then build the Caddy config from there.

```nix
host_services = attrValues (filterAttrs (svc_name: svc_def:
  svc_def ? "host" && svc_def.host.hostName == config.networking.hostName
  && svc_def.caddify.enable) catalog.services);
```

## I have seen the light

Instead of doing all the building of the Caddy JSON config by hand, I can declare a block in each service module _that requires it_ which will ensure Caddy will create a reverse proxy for it. This means a module now encapsulates everything that is required for this service to function properly.

Such a module would then look like the below, with some lines removed for brevity. You can see it in full in [GitHub](https://github.com/jdheyburn/nixos-configs/blob/46eca0686b735ff74a19867c625e7ecca2d9034a/modules/plex/default.nix).

```nix
{ config, pkgs, lib, ... }:

with lib;

let cfg = config.modules.plex;
in {

  options.modules.plex = { enable = mkEnableOption "Deploy plex"; };

  config = mkIf cfg.enable {

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

This is a lot simpler, and it meant that I was able to remove a **lot** of complicated Nix code in the [pull request](https://github.com/jdheyburn/nixos-configs/pull/66) to achieve the same thing. The end result is a solution that is much easier to understand and pragmatic.

I'm still using a [similar method](https://github.com/jdheyburn/nixos-configs/blob/46eca0686b735ff74a19867c625e7ecca2d9034a/modules/dns/default.nix#L8-L31) for when writing the AdGuardHome DNS config, but I changed the functions to more appropriate names. You can [revisit the previous blog post](/blog/automating-service-configurations-with-nixos/#dns-rewrites) where I walk through that.

This refactoring to more complete modules isn't ground-breaking by any means, but I wanted to share this win I gained :thumbs_up:.
