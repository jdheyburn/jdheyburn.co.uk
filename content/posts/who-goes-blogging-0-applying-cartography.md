---
date: 2019-09-11
title: "Who Goes Blogging Pt. 0: Applying Cartography"
description: Mapping out the architecture of my portfolio website
images:
- images/blog-arch.png
tags:
- architecture
- cdn
- cloudflare
- portfolio-site
- github-pages
# Redirect the old slug name to the new one
aliases:
  - /posts/applying-cartography/
---

# Applying Cartography

With my academic background focused in infrastructure, I love seeing diagrams of topologies - they're a pretty damn useful way of understanding architecture of an application flow amongst other things. Let's take a look at how my portfolio site is architected out.

As I mentioned in my [first blog post](/posts/blog-bootstrap/) - I've got several ideas on how I can improve on the architecture of this site. But what good is evaluating where you've come from if you don't document what you currently have? 

That's when you can make true comparisons in any system. As such the aim of this series of posts will be to explain how this website is architected, so that we may reference it in future posts. Later on, I'll also talk about how you're able to get yourself set up as well.

## The Setup

Because we all love an architecture diagram, let's slap one in now.

![An architecture diagram of my portfolio site][blog_arch]

Wow. That is... really not much at all. Apologies if you were expecting a lot more arrows and boxes!

In a way, I shouldn't be sorry, because one of the core priniciples in software development is KISS (Keep It Simple Stupid!) - and this setup is just an advantage of how I decided the first implementation of my website to be:

- Easy to implement
- Easy to maintain (there is none required!)

I'm a firm believer that you're best off getting a minimum viable product out there ASAP and then work to perfect it afterward. What I hope to document as time goes on are the various enhancements and changes that I intend on making to the website so that yourselves can follow along too with your own site. That goes not just for this site (how much can it really be improved?!) but for whatever projects I work on.

# So what does it all mean?

Back to the diagram, let's follow it from right-to-left and start talking about what's going on. 

## GitHub Pages - somewhere to call home
You can see that the site is hosted on GitHub Pages. Essentially this is GitHub's platform for hosting the static resources that are checked into the public repos. This then presents the assets at a domain prefix of your choosing, suffixed by `.github.io` - in my case it is at `jdheyburn.github.io`. GitHub Pages only hosts your site via HTTPS so you know your pages aren't being subject to a man-in-the-middle attack, and it takes care of your TLS certificates so you don't need to worry about renewing them!

> You might be wondering why you would need to serve a static site over HTTPS when you aren't handling anything confidential. I'll turn you to Troy Hunt's excellent article [Here's Why Your Static Website Needs HTTPS](https://www.troyhunt.com/heres-why-your-static-website-needs-https/).

## Supercharge your delivery!
Now that the website is hosted at GitHub - I stuck a content delivery network (CDN) in front of GitHub for a whole load of reasons, some of which are:

### Fast end-user response times
CDNs cache your content at edge locations dotted all over the globe, where the client is then served content from the one closest geographically (let me direct you to [latency numbers every programmer should know](https://people.eecs.berkeley.edu/~rcs/research/interactive_latency.html)).

### Security
The CDN acts as a proxy between the client and your servers - their requests don't actually hit you directly.

Not only that, a lot of CDNs provide DDoS protection to ensure excessive requests don't bring down your servers.

### Analytics
Because everyone loves graphs and numbers... right??... Alright just me then...

You'll be able to see how many requests are being served up, where requests originate from, amongst others. Take a look at an example below.

![A graph displaying total requests, and how many of them were cached][analytics_example]

### Custom domain
  - This means you can access your site on something other than `<my_site>.github.io`, which is great for when you move off GitHub Pages to another platform, you can just tell Cloudflare to source requests from another server
  - It also gives your site that extra polish and professionalism about it - wouldn't you agree?

My CDN of choice is [Cloudflare](https://www.cloudflare.com/), for no reason more than is it completely free to use and will most likely stay free until I decide I would benefit from the next [pricing step](https://www.cloudflare.com/en-gb/plans/). Did I mention the website is pretty damn easy to use as well?

That means that the operating cost of a site like this is exactly ZILCH (nada, et al.), which again is another great reason to get set up on a platform like this.

## Top-level domain fatigue? 
I'm from the UK - and I wanted my site to reflect that, so I purchased a domain with the top-level domain (TLD) `.co.uk`. However when users come to visit me on my site they may not always remember whether it was `.com`, `.dev`, `.tk` (remember those?). Therefore I also have `jdheyburn.com` set up in the same way as its `.co.uk` sibling to maximise that user experience.

Okay well that means there is a slight cost to maintain the site through purchasing and renewing the custom domains (notice how jdheyburn.com redirects to jdheyburn.co.uk?) but we're talking in the £10s per year for these two.

So if you're interested in having a setup like this, then over the next few posts I'll be detailing how you can do the same. 

\- jdheyburn

[blog_arch]: /images/blog-arch-cover.png
[analytics_example]: /images/analytics_example.png