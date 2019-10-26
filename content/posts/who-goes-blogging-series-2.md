---
date: 2019-11-01
title: Hugo's Blogging
description:
tags:
  - architecture
  - cdn
  - cloudflare
  - portfolio-site
  - github-pages
draft: true
---

# Custom Domain
Let's add a degree of professionalism to our site by having a custom domain apply to it. You'll need to make sure you own a domain first before you go ahead, so have a look at a few providers and see which works best for you [from a comparison list](https://www.techradar.com/uk/news/best-domain-registrars-in-2019). I bought mine from [namecheap](https://www.namecheap.com/) just because of the price and WhoIS guard features. There may be other providers that have the same features, so make sure to make your own comparison!

> In the case of `.co.uk` domains, because it is a UK domain that resides in the EU (for now), the WhoIS lookup is disabled by default - which is a huge win for privacy.

Once you've purchased your domain we'll need to create a file in our `blog-source` repo called `CNAME` and populate it with the domain we purchased. In my case, mine looks like this:

{{< highlight bash >}}
# CNAME
jdheyburn.co.uk
{{< / highlight >}}

You might have noticed in the previous section in our `deploy.sh` script it made a reference to this CNAME file. This tells GitHub Pages to redirect any calls made to the `.github.io` domain to our custom one. This is why we added line 9 in the script, so that it winds up in the rendered repo.

With our custom domain created, we need to tell the registrar to point to the DNS servers where our site is being hosted from. GitHub has [this documented well too](https://help.github.com/en/github/working-with-github-pages/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain), so you can see the latest IP addresses from there. You will need to consult your registrar on how set this. If you followed my footsteps to set this up using namecheap, search on [this page](https://www.namecheap.com/support/knowledgebase/article.aspx/767/10/how-to-change-dns-for-a-domain) for **Custom DNS** on how to change it.

Once we've made the change, it may take a while for the update to reflect across the DNS ecosystem. Once propagated, your website should be accessible at your domain!

# CDN-all-the-things

Now for the final piece of the puzzle, adding in a CDN layer. I briefly spoke about the benefits in [part 0](/posts/applying-cartography/), but [here](https://blog.webnames.ca/advantages-and-disadvantages-of-a-content-delivery-network/) is a good resource if you'd like to do more reading.

> Like with any introduction of an architectural component, a CDN has some drawbacks, such as making your service now dependent on a third party for which you have no control over. Namely CloudFlare in particular has had some high profile outages of recent date, but has been extremely reliable in my previous experiences with them.

>Given this information I believe you can make your own mind up on what is best for yourself. For me, I the benefits far outweigh the downsides.

For this website I am using CloudFlare as the CDN, given it is free and the one I have most experience with. 

# Bonus: Adding more top-level domains for redirection
