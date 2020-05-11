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

As described in [previous posts](/blog/who-goes-blogging-5-updates-galore/#template-lookup-order-primer) - you can overwrite the default of any file used in generating the website by placing it in your local project root. We can start to make modifications to the `rss.xml` file by copying the default into the directory where Hugo will read it from.

```bash
# Assuming you are in project root
wget https://raw.githubusercontent.com/gohugoio/hugo/master/tpl/tplimpl/embedded/templates/_default/rss.xml -O layouts/_default/rss.xml
```

We know that line 35 containing `.Summary` is causing the issue here. All we need to do is change it to `.Content` - then Hugo will print out the entire content of your post. See the highlighted line below for the change.

```xml {linenos=table,hl_lines=[7],linenostart=29}
    <item>
      <title>{{ .Title }}</title>
      <link>{{ .Permalink }}</link>
      <pubDate>{{ .Date.Format "Mon, 02 Jan 2006 15:04:05 -0700" | safeHTML }}</pubDate>
      {{ with .Site.Author.email }}<author>{{.}}{{ with $.Site.Author.name }} ({{.}}){{end}}</author>{{end}}
      <guid>{{ .Permalink }}</guid>
      <description>{{ .Content | html }}</description>
    </item>
    {{ end }}
  </channel>
</rss>
```

Let's now view the changes in the RSS reader.

TODO screenshot of .Content

## Showing Images Properly in Posts

### Why it is breaking

In [part 4](/blog/who-goes-blogging-4-content-structure-and-refactoring/) of this series, we looked at placing resources for a post in the same directory as the content markdown file (also known as [leaf bundles](https://gohugo.io/content-management/page-bundles/#leaf-bundles)).

That means for a given directory tree structure:

```bash
$ tree content/blog
content/blog
└── some-blog-post
    ├── image-file-name.png
    └── index.md
```

We would use the following shortcode to generate the `<img>` block in `index.md`.

```go
{{</* figure src="image-file-name.png" alt="Here is an image!" */>}}
```

This produces the block:

```html
<figure>
    <img src="image-file-name.png" alt="Here is an image!">  
</figure>
```

Since this contains no preceding forward-slash `/` in `src`, this becomes a *relative path*. This means the webserver will look for the image at the path relative to the current page. So when we navigate to `blog/some-blog-post/` in our web browser (as dictated from the above tree structure), your browser will request the image at `blog/some-blog-post/image-file-name.png` for you.

So why is this relevant? This same `<img>` block is being rendered in the description of your RSS XML file, including the relative image location. RSS is very simple and renders only complete URLs (e.g. `https://jdheyburn.co.uk/blog/some-blog-post/image-file-name.png`) - so when we just specify the relative path, it cannot find the image and thus prints out the alternative (`alt`) text.

> If you're not already providing an `alt` field to your `<img>` blocks then **you absolutely need to**. They help boost accessibility to your website should the user have a text-to-voice application reading your website. They also provide a helpful description to your image in case it cannot load - which happens more often than you think!

TODO screenshot of image not rendering

> **Note:** if specify images from a complete path such as `/images/image-file-name.png` under `static/images`, then this is not an issue for you.

### Fix image rendering

The fix for this involves some Go magic. We need to prepend the permalink for the current post that's being printed out to anything that contains a relative path `<img>` block. We need to go back to the same line where we added `.Content` and change it to:

```xml
<description>{{ replaceRE "img src=\"(.*?)\"" (printf "%s%s%s" "img src=\"" .Permalink "$1\"") .Content | html }}</description>
```

This calls the Hugo function [replaceRE](https://gohugo.io/functions/replacere/) which enables us to perform a find-and-replace using [regular expressions (regex)](https://www.regular-expressions.info/tutorial.html), and it takes three inputs:

- `PATTERN` is the regex pattern used to find the text we want to remove
    - `"img src=\"(.*?)\""`
- `REPLACEMENT` is the text that we want to replace the `PATTERN` with
    - `(printf "%s%s%s" "img src=\"" .Permalink "$1\"")`
- `INPUT` is the string we want to perform the find-and-replace on
    - `.Content`

In the example above, we're placing a [capturing group](https://www.regular-expressions.info/brackets.html) in the `PATTERN` so that it will capture the contents inside `src` and save them so that we can refer to it in the `REPLACEMENT`, while removing `img src=""`.

`REPLACEMENT` is calling another Hugo function called [printf](https://gohugo.io/functions/printf/) to construct the replacement text. We're pretty much just injecting the page `.Permalink` prior to the captured text from the `PATTERN` - so that RSS can then display the complete URL

`INPUT` will be the page `.Content`, what we were printing out before

Once we've made the change, images are now rendered properly!

TODO screenshot of rendered image on RSS

## Adding cards for posts

