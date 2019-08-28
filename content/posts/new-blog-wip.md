---
draft: true
date: 2019-08-25
title: Blog Architecture
description: I describe some simple methods to improve on your Python codes integrity and durability
tags:
- python
- testing
- typing
---

# Working title

With my academic background focused in infrastructure, I love seeing diagrams of topologies - they're a pretty damn useful way of understanding architecture of an application flow amongst other things. Let's take a look at how this my blog post is architected out. 

As I mentioned in my first blog post (LINK) - I've got several ideas on how I can improve on the architecture of this site. But what good is evaluating what you've changed and for what good if you don't start documenting what the current system is? As such the aim of this post (series of posts?) will be to explain how this website is architected, so that we may improve it step by step.

Because we all love an architecture diagram, let's slap one in now.


Wow. That's really not much at all. Apologies if you were expecting something a whole lot beefier!

In a way, I shouldn't be sorry, because one of the core priniciples in programming is KISS (Keep It Simple Stupid!). Although this setup is just an advantage of how I decided the first implementation of my website to be:
1. Easy to implement
1. Easy to maintain (there is none required!)

I'm a firm believer that you're best off getting a minimum viable product out there ASAP and then work to perfect it. What I hope to document as time goes on is the various enhancements and changes that I intend on making to the website so that yourselves can follow along too with you own site.

Back to the diagram, you can see that my static site is hosted via Github Pages. Essentially this is Github's platform for hosting public repositories with the static resources contained within them. This then presents the assets at a domain of your choosing, followed by `.github.io` - in my case it is at `jdheyburn.github.io`. Github Pages only hosts your site via HTTPS and takes care of your TLS certificates so you don't need to worry about renewing them! 

> You might be wondering why you would need to serve a static site over HTTPS when you aren't handling anything confidential. I'll turn you to Troy Hunt's excellent article Here's Why Your Static Website Needs HTTPS https://www.troyhunt.com/heres-why-your-static-website-needs-https/ 

Now that the website is hosted at Github - I stuck a CDN (content delivery network) in front of Github for a multiple of reasons, some of which are:
- Fast end-user response times
    - Closer to the user, etc
    - What better way to show your prospective readers that you care about their experience, etc
- Security
- Analytics
- Custom domain
    - This means you can access your site on something other than `<my_site>.github.io` - which is great for when you move off Github Pages to another platform
    - It also gives your site that extra polish and professionalism about it - wouldn't you agree? 
- And many more (link to an article here)

My CDN of choice is Cloudflare, for no reason more than is it completely FREE to use! That's not bad at all - however I very much doubt my site is causing too much load on their end nodes, until then I imagine it will remain free (verify).  

That means that the running cost of a site like this is exactly ZILCH (nada, etc.), which again is another great reason to get set up on a platform like this.

> Okay well there is a charge for the custom domains (notice how `jdheyburn.com` redirects to `jdheyburn.co.uk`?) but that is in the very low Â10s 

So if you're interested in having a setup like this, then over the next few posts I'll document how the same can


I've done a lot of talking about how it is currently, but let's talk about how you can get set up with the same as I have done here.

# Domain Name (Pt. 1)

Now

