---
date: 2019-12-12
title: "Who Goes Blogging 2: Custom Domain"
description: Make your portfolio site professional by applying a custom domain to it
images:
- images/namecheap_landing.png
tags:
- architecture
- cdn
- cloudflare
- portfolio-site
- github-pages
aliases:
  - /posts/who-goes-blogging-2-custom-domain/
---

In the [previous post](/posts/who-goes-blogging-1-getting-started/), we got ourselves up and running with a website generated by Hugo, deployed to GitHub, and hosted by GitHub Pages.

Now, we're going to add a custom domain to our website so that we hide the `<username>.github.io` domain that GitHub Pages is kindly hosting for us for free. 

At the same time, we're going to make our website blazingly fast for users by adding a caching layer with a content distribution network (CDN). 

Lastly, I'm going to throw in a bonus guide on how to redirect from multiple top-level domains (TLDs) to one (e.g. `<your-domain>.com` redirects to `<your-domain>.co.uk`).

# Pre-requisites

There's not much more to add from the last post. I talk a lot about domains and domain name system (DNS), which is the address-finder of the Internet, and an entirely huge beast in its own right. 

Again - I won't try to replicate already great guides out there on the topic. So if you'd like to find out more, see below for some helpful guides.

- https://www.digitalocean.com/community/tutorials/an-introduction-to-dns-terminology-components-and-concepts
- https://opensource.com/article/17/4/introduction-domain-name-system-dns

# Applying a Custom Domain to GitHub Pages
Let's add a degree of professionalism to our site by having a custom domain apply to it. You'll need to make sure you own a domain first before you go ahead, so have a look at a few providers and see which works best for you [from a comparison list](https://www.techradar.com/uk/news/best-domain-registrars-in-2019). I bought mine from [namecheap](https://www.namecheap.com/) just because of the price and WhoisGuard features. There may be other providers that have the same features, so make sure to make your own comparison!

> In the case of `.co.uk` domains, because it is a UK domain that resides in the EU (for now), the WhoIS lookup is disabled by default - which is a huge win for privacy. WhoisGuard is available for non-EU domains and I highly recommend it.

GitHub has a [series of documentation](https://help.github.com/en/github/working-with-github-pages/configuring-a-custom-domain-for-your-github-pages-site) on applying a custom domain to GitHub Pages in much greater detail than what I am about to write out, should you wish to find out more information.

# Acquire a Domain

The rest of the post will depict a lot of Namecheap semantics, since that is the registrar I have access to. You can choose to follow the guide alongside a different registrar if you wish, at a high-level they will be pretty similar. For now, let's move on ahead with Namecheap and navigate through to the [domain purchase page](https://www.namecheap.com/).

{{< figure src="/images/namecheap_landing.png" caption="The hardest part is deciding on the domain name..." alt="Screenshot depicting the namecheap domain landing page" >}}

{{< figure src="/images/namecheap-domain-purchase.png" alt="Screenshot depicting the namecheap domain purchase page" >}}

Once you've set up an account and purchased your domain, your accounts domain landing page will look something like the below.

{{< figure src="/images/namecheap-domain-acquired.png" caption="Make sure you have auto-renew selected, otherwise you can kiss that domain goodbye when it expires!" alt="Screenshot depicting the namecheap domain landing page" >}}

When you purchase a domain from Namecheap, by default it will be pointing to their own domain name service (DNS) nameservers, as you can see from the picture above. 

This means when we type in our new domain into a browser, it will contact Namecheap for the IP address for that record. 

Currently Namecheap is none the wiser about these records, which isn't very exciting. Let's move on to adding the CDN for the website.

# Adding Our CDN Layer

As discussed in a [previous post](/posts/who-goes-blogging-0-applying-cartography/#supercharge-your-delivery), a CDN can provide us with many benefits. Go check out the page for a refresher of what those are and for why I selected Cloudflare. You can use whichever you like, however the remainder of this guide will focus on Cloudflare in particular - the concepts can still be applied at a high level to other CDNs. 

> Like with any introduction of an architectural component, a CDN has some drawbacks, such as making your service now dependent on a third party for which you have no control over. Namely Cloudflare in particular has had some high profile outages of recent date, but has been extremely reliable in my previous experiences with them.

> You can go [here](https://blog.webnames.ca/advantages-and-disadvantages-of-a-content-delivery-network/) for a list of pros and cons of CDNs. Given this information I believe you can make your own mind up on what is best for yourself. For me, I the benefits far outweigh the downsides.


## Cloudflare our Domain

Create an account with [Cloudflare](https://www.cloudflare.com/) if you haven't done so already. Once done you'll need to click **Add Site** at the top of the browser dashboard. Enter your newly purchased domain from the previous section.

{{< figure src="/images/cloudflare-add-domain.png" caption="Enter your newly purchased domain from the previous section" alt="Screenshot depicting the Cloudflare add domain page" >}}

Go ahead now and select the free plan, if you want to [go more advanced](https://www.cloudflare.com/en-gb/plans/) then you can do so. 

Once that's created you'll see Cloudflare scan the DNS records for this domain you've added - for now let's navigate back to the [Cloudflare Dashboard](https://dash.cloudflare.com/) and selecting the domain. You'll be presented with a page similar to below, minus all the activity!

{{< figure src="/images/cloudflare-domain-landing.png" caption="Name me a more iconic duo than numbers and graphs. I'll wait..." alt="Screenshot depicting the Cloudflare domain home page" >}}

## Update Cloudflare DNS Records

In order for Cloudflare to provide its benefits, it acts as the DNS server for your domain. This means that it will forward requests of our website to the IP addresses where our website is being hosted. It's place in the topology is like this:

```
1. Domain registrar ---> 2. DNS server and CDN provider ---> 3. Web server location
```

Translated to our architecture:
```
1. Namecheap ---> 2. Cloudflare ---> 3. GitHub Pages
```

What we need to do is instruct Cloudflare where to direct clients of the website. There are several ways of doing this, whether you want your website to be available at `www.<your-domain>.co.uk` (CNAME record), or `<your-domain>.co.uk` (APEX (A) record). Both of which are [well documented by GitHub](https://help.github.com/en/github/working-with-github-pages/managing-a-custom-domain-for-your-github-pages-site) already. For the purpose of this post, I'll guide you on my set up which is an ALIAS record.

Back to Cloudflare, you'll need to load up the dashboard for your domain and navigate to the DNS icon in the taskbar at the top. Clicking on **Add record** will allow you to add the A records that point to GitHub Pages's IP addresses. As of writing (and [documented](https://help.github.com/en/github/working-with-github-pages/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain)) they are:

```
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

Let's add these to the Cloudflare DNS page below.

{{< figure src="/images/cloudflare-dns-record.png" caption="Add in the GitHub IP addresses one by one" alt="Screenshot depicting adding DNS records to Cloudflare" >}}

Once done - your records will look something like this:

{{< figure src="/images/cloudflare-completed-records.png" caption="" alt="Screenshot depicting completed DNS management" >}}

You'll notice an additional CNAME record at the bottom for `www`. This will redirect any requests made to `www.jdheyburn.co.uk` to `jdheyburn.co.uk`. This could be something you'd want to replicate too if you wish.

One thing to note down before we move on is to capture the Cloudflare DNS Nameservers that have been assigned to our domain. You can find these on the same DNS management page we are on, but by just scrolling down we can see these nameservers.

{{< figure src="/images/cloudflare-nameservers.png" caption="Make a note of these nameservers for your domain" alt="Screenshot depicting completed Cloudflare DNS nameservers" >}}

## Direct Namecheap to Cloudflare

[Earlier in this post](/posts/who-goes-blogging-2-custom-domain/#acquire-a-domain), I mentioned that a newly created Namecheap domain will default to their own DNS nameservers. We want to change this to Cloudflares DNS nameservers from which we configured our DNS records.

Navigate to the [Namecheap management page](https://ap.www.namecheap.com/domains/list/) for your domain and enter the Cloudflare nameservers once you have selected **Custom DNS**.

<center>{{< figure src="/images/namecheap-nameservers.png" caption="Add in your Cloudflare domains from previously" alt="Screenshot depicting completed nameservers pointing to Cloudflare" >}}</center>

Once this is done you may need to wait a while for the DNS updates to propagate throughout the world. While we're waiting for that, there's one final piece of the puzzle which can keep us busy.

## GitHub Pages Configuration

The last place to configure is GitHub Pages. Currently it is hosting at our `.github.io` domain, but we need to instruct it to redirect to our custom domain. There are two methods for doing this:

1. Configure the repository settings
1. Use a `CNAME` file in your repository

### Configure the repository settings

This is the quicker of the two solutions, so I advise to follow this step to understand if you have everything in place correctly. Once done then you can lock-in your changes with step 2 above.

For this step, you need to navigate to the settings pages for your `.github.io` repo containing your rendered code.

```
https://github.com/<USERNAME>/<USERNAME>.github.io/settings
```

Now scroll down, keep going until you hit the **GitHub Pages** heading. Here you will see a form for entering a custom domain; do the honours and enter it in like below.

{{< figure src="/images/github_pages_setup.png" caption="Ignore my already published domain..." alt="Screenshot depicting GitHub Pages form for specifying a custom domain" >}}

Now again wait for DNS to propagate across the world. When GitHub is happy with the changes then you will see the green banner similar to the one in the screenshot above. This means everything is being served up! Why not give it a try ourselves? Head to your domain now and see if everything is working!

{{< figure src="/images/jdheyburn_co_uk_custom_domain.png" caption="You should end up with something like this!" alt="Screenshot depicting completed custom domain" >}}

### Solidying our changes with a CNAME file

We can use the above method to quickly try using GitHub repository settings to see if everything is working, however I'm a big fan of setting changes in code (Infrastructure-as-code anyone?). GitHub supports another method which is to use a file named `CNAME` in our generated `.github.io` repo that contains the domain name we wish to use. 

In my case, I would have the following...
{{< highlight bash >}}
# CNAME
jdheyburn.co.uk
{{< / highlight >}}

This then tells a repo that is enabled for GitHub Pages to use the domain in this file as our custom domain, effectively producing the steps in the previous section. Neato.

The change to implement this is fairly easy. I have to admit I picked it up from somewhere but I don't have the source to reference it to.

So back in your `blog-source` repo, you want to execute the below, replacing the template with your domain.
{{< highlight bash >}}
echo "<DOMAIN-NAME>" > CNAME
{{< / highlight >}}

#### Building into our deploy script

Once that is done, you will need to modify your `deploy.sh` script to copy over the file into your generated Hugo site, because Hugo won't do it for you! Don't have the deploy script or need a refresher? Head back to the [previous post](/posts/who-goes-blogging-1-getting-started/#bash-script-deploying).

You will want to copy it after Hugo has done its thing, take a look at the Gist below - line 9 is your friend.

{{< gist jdheyburn e84bab9176dc1753416637324a04603d >}}

What this is doing is taking the `CNAME` file that already exists in our `blog-source` repo and moving it to the generated `public/` directory which Hugo created for us. It is then this `public/` directory that gets committed to the GitHub Pages repo.

Then that's it! Take a look at my [finished repo](https://github.com/jdheyburn/jdheyburn.github.io) and you'll see where `CNAME` fits in.


# Bonus: TLD Redirection

Let me tell you a story. Your website is up and operational. You're super proud of it, and you give yourself a round of applause {{<emoji ":clap:" >}}

But you don't want to be the only person looking at it, you want the whole world to! You tell your parents, your significant other, the dog off the street - they all remember the name of your website, but *was it at `.com` or `.<insert snazzy TLD here>`*?

Of course, you domain isn't at `.com`, that's boring as hell! You just forked out $50 on a `.dev` TLD, and no one will see it!

Luckily there is a way...

You can buy additional domains at different TLDs and have them redirect to your *one-domain-to-rule-them-all* with little to no hassle! There is the cost of purchasing the domain and renewing it year after year, but with that being ~£10 or so per year - I'd call that a good insurance policy to ensure people land at your website!

In my case, I purchased `jdheyburn.com` and had it redirect to `jdheyburn.co.uk` - why not give it a try: [https://jdheyburn.com](https://jdheyburn.com)

The steps are already defined in this post. For a breakdown of what they are:

1. [Purchase a domain](#acquire-a-domain)
1. [Create a new website in Cloudflare](#cloudflare-our-domain)
1. [Create a DNS A record to redirect to your correct domain](#update-cloudflare-dns-records)
1. [Configure Namecheap to use Cloudflare's nameservers](#direct-namecheap-to-cloudflare)

Steps 1 and 2 are pretty easy to perform yourselves - so for this exercise I'll join in at step 3.

## Cloudflare Domain Redirection

Assuming that you've completed steps 1 and 2, we'll need to configure the redirection - but we don't do this via inserting a DNS record like we did previously, Cloudflare has a feature that handles that for us called **Page Rules**. 

On your Cloudflare website landing page, navigate to **Page Rules** in the toolbar at the top and then **Create Page Rule**.

{{< figure src="/images/cloudflare_page_rules.png" alt="Screenshot depicting how to access the Create Page Rule feature" >}}

In the next screen we're going to define the rule. Cloudflare have [documentation on Page Rules](https://support.cloudflare.com/hc/en-us/categories/200276257-Page-Rules), and even more [specifically on redirection](https://support.cloudflare.com/hc/en-us/articles/200172286-Configuring-URL-forwarding-or-redirects-with-Cloudflare-Page-Rules). 

From this screen you will want something that appears as below.

{{< figure src="/images/cloudflare_new_page_rule.png" alt="Screenshot depicting how to populate the Create Page Rule form" >}}

Let's break down what's happening here:

1. We define a pattern of `*jdheyburn.com/*`, indicating that the rule is active should a URL be queried to Cloudflare
  - This pattern will match any request at this domain
1. Next comes the rule action, which is:
  1. Set this URL as a forwarding URL - to reply back to the client with `301 Permanent Redirect` status code
  1. With the forwarded URL being `https://jdheyburn.co.uk/$2`

The `/$2` at the end of the rule is crucial here. This will carry across any URL path parameters or query parameters to the redirected URL. In fact `$2` refers to anything that matches the second asterisk (`*`) in the rule pattern (`*jdheyburn.com/*`). So `https://jdheyburn.com/contact` will redirect to `https://jdheyburn.co.uk/contact`.

> Having the forwarded URL set to the `https://` scheme will ensure that your users will receive your website encrypted, safe from man-in-the-middle attacks.

Lastly, click on **Save and Deploy** to finalise your changes; you'll have a view such as below.

{{< figure src="/images/cloudflare_completed_page_rule.png" alt="Screenshot depicting the newly created page rule" >}}

That's all you need - once again you will have to wait for DNS replication to trickle down. You can repeat this over again for other domains you may have.

# Conclusion

That it for this part, we covered quite a lot of things:

- Purchasing a custom domain
- Applying a CDN cache layer
- HTTPS redirection
- Redirect multiple domains to one location

Next up I'll document the various deployment methods I have used for the website.