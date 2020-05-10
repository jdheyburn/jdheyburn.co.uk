---
date: 2020-04-27
title: "Who Goes Blogging 6: Fixing RSS"
description: Spending time to ensure that posts are rendered nicely for RSS feeds, along with other minor enhancements
type: posts
series:
    - Who Goes Blogging
images:
    - images/jdheyburn_co_uk_card.png
draft: true
---

## What is RSS?

[RSS](https://en.wikipedia.org/wiki/RSS) is a great way to "subscribe" to websites to ensure that you don't miss content from them. The standard for how it is generated has been the same for decades now - however its still the best supported and most accepted way to receive updates. The format for these are usually defined from an XML file which would contain the content for your posts and then be consumed on an RSS aggregator or reader, for which there are many to choose from (RIP [Google Reader](https://en.wikipedia.org/wiki/Google_Reader)).

TODO talk about how it is a text copy with some basic formatting usually

TODO include screenshot of inoreader - mention I'll be using this in my examples

Hugo [generates RSS XML](https://gohugo.io/templates/rss/) files from a template that will loop over your content and expose this at an endpoint for RSS aggregators to subscribe to and periodically check for updates against. Hugo generates a bunch of XML files at different sections of the website, allowing consumers to decide what most interests them - you can even subscribe to tags if that XML is being generated! Ususally there is site top-level available at `/index.xml` - in the case of my site that would be https://jdheyburn.co.uk/index.xml. The source code for the template file Hugo uses to generate this is embedded in Hugo at [this location](https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml).

## The Problem

Some (but not all) websites only include the first paragraph of their post in an RSS update, along with a message after it asking the reader to visit the site in a browser to view the rest of the content. This is a common feature of WordPress blogs - and it is done to have you load the full website and along with it, all the code for providing the owner with user analytics, and advertising - if they have it. So really they're getting the benefit of being able to publish updates via a standardised approach (RSS), to then lure you onto the website.

TODO include screenshot for show further content

Hugo *kind of* does this through the highlighted line in the [templated RSS XML file](https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml):

```xml
<description>{{ .Summary | html }}</description>
```

`.Summary` will do what was just described, print out the first paragraph of your post. However unlike WordPress, it doesn't actually say if there is more content - so users may not load your full website.

TODO screenshot of Hugo doing thi

I'm not against the practice of previewing the post, if a blog provides revenue somehow then you will need to force readers to view your website. Although this goes against the initial purpose of RSS - to provide subscribers a pure text version of your content. At the end of the day, I believe it should be the user who decides how they want to view my content - and they accept the limitations that come from RSS.

So now, I'll be making several changes to the Hugo template RSS XML file to produce the full site content, along with some other enhancements.

## Rendering Full Site Content

Before we start editing files, we need to produce our own copy of the template RSS XML file. As mentioned before, this is embedded directly within Hugo itself and not packaged in with your theme.

> There's every chance your theme is generating one for you. Run the below command to see if there is anything for you to copy from.
>
> ```bash
> find themes/ -type f -name '*.xml'
> ```

As described in [previous posts](/blog/who-goes-blogging-5-updates-galore/#template-lookup-order-primer) - you can overwrite the default of any file used in generating the website by placing it in your local project root. 

```bash
wget https://raw.githubusercontent.com/gohugoio/hugo/master/tpl/tplimpl/embedded/templates/_default/rss.xml -O layouts/_default/rss.xml
```

## Showing Images Properly in Posts

## Adding cards for posts

