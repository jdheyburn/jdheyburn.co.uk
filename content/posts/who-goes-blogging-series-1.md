---
date: 2019-09-11
title: Hugo's Blogging
description:
tags:
  - architecture
  - cdn
  - cloudflare
  - portfolio-site
  - github-pages
---

I've done a lot of talking about how it is currently, but let's talk about how you can get set up with the same as I have done here. Let's recap exactly what that is:

1. A GitHub repo with the site source code
1. Another GitHub project with the rendered site
1. Hosted on GitHub Pages
1. Fronted by a custom domain
1. Globally cached by a CDN 

# Hugo Static Site Builder

There are many website building platforms out there for your static sites. There is no one platform to rule them all, you should decide on which one works best for you. For myself, I wanted to explore further into the realm of Golang as a learning opportunity with the goal of creating my own Hugo template at some point. Additional, Hugo is completely open source, so you can [check out](https://github.com/gohugoio/hugo) how it works too!

> While Hugo itself is free, there are fancier and more feature-rich themes available to purchase from designers which may have a cost attached to them.

I won't aim to reproduce a complete list of comparisons against other platforms, other people have already made the comparisons much better than I could! But nevertheless, some that I am aware of off the top of my head are [Jekyll](https://jekyllrb.com/), [Ghost](https://ghost.org/), and the infamous [WordPress](https://wordpress.com/).

# Git Set Up

I mentioned before I split my website into two repos:
- jdheyburn.co.uk holds all the source code
- jdheyburn.github.io holds the rendered website 

For the first repo, it doesn't really matter what you call it - you can call it your destined domain name, or `blog-source`, or `dogs-are-great`. It's the second one which you will need to think about, where it must end in `.github.io`. The prefix before that will become part of the domain used to access the website, so having a repo named `dogs-lovers-unite.github.io` will make the contents ultimately available at `https://dog-lovers-unite.github.io`. 

Create two [empty Github repos now](https://github.com/new) before you move on, check out an example below.

{{< figure src="/images/github_repo_creation.jpg" caption="Creating empty repos is the easy part..." alt="Screenshot depicting Github repo creation" >}}

TODO finish off Github creation and getting the project set up


# Blog Bootstrapping

Firstly you would need to create your Hugo template. You can do this from either executing `hugo new <site|theme>` and building up from there - or do what I did which was to browse the [Hugo themes](https://themes.gohugo.io/) and git clone the example site that was displayed and then make your changes around that. It may entirely depend on your learning approach which way works best for you.

In my case, I wanted to get up and running in the smallest time possible (isn't that the point of static site generators?). However when I come to producing my own Hugo theme, I will most likely build it from the ground up so that I have greater contextual knowledge of each component.

## Serves* Up!

> \* Pun fully intended

The theme this blog uses as of publication is [hugo-coder](https://themes.gohugo.io/hugo-coder/), written by [Luiz de Prá](https://luizdepra.dev/). You may wish to use it, or something else. It's entirely up to you! Let's get started by laying down the foundations and cloning the theme.

```
mkdir ~/projects
cd projects
git clone https://github.com/luizdepra/hugo-coder.git
cp -r hugo-coder/exampleSite blog-template
mkdir blog-template/themes
ln -s ~/projects/hugo-coder blog-template/themes/hugo-coder
cd blog-template
hugo serve
```

That last command will locally serve the example site, so that you can view it at `http://localhost:1313/`.

{{< figure src="/images/local_example_site.jpg" caption="Success!" alt="Screenshot depicting the locally run example site" >}}

Once you have the site up, feel free to make as many changes as you like to gain an understanding of how everything plugs together. 

The `blog-template/config.toml` file will contain the majority of configurations that are used to generate the site. Go ahead and even comment out some config and see what affect that has. You can even [be nosey at my config file](https://github.com/jdheyburn/jdheyburn.co.uk/blob/master/config.toml) if you're looking for some inspiration! The `hugo serve` command will rebuild your site with any changes you make.

The Hugo config file will be a source of many informations, and the [documentation for it is very thorough](https://gohugo.io/getting-started/configuration/). While we're on the subject, the rest of the Hugo documentation is great, so check the rest of it out if you haven't done so already.

Once you're happy playing around with it locally, why not get the rest of the world to take a look at it?

# Deploy

So far we have only been playing with the `hugo serve` command, which is great for local development but not for production. There is a more appropriate command for building, `hugo` - pretty simple right? 

```
hugo
```

This renders the HTML and CSS files from your config and markdown for the theme and places them in the `public/` directory. In theory once you've executed this command you can host a webserver at that address and everything would operate as normal. Why not give it a try?

```
cd public/
python -m SimpleHTTPServer 8080
```

We're currently committing to one git repo, however we want Gthub pages to host it for us. As mentioned earlier (did I?) GP can only host from projects as github.io, so we need to get our built website into that repo.

Now the original way I did this was through a simple bash script. I mean you can't go wrong with a bit of DIY hard core scripting?! I've since moved over onto a CI/CD platform which I will discuss in a future post. In the meantime, let's press ahead.

TALK ABOUT THE SCRIPT AND WHAT IT'S DOING

From here we can then see the final result in the desired repo. But unfortunately there's a little bit more we need to do to get this to work.

(is there config needed on gp side? Talk about it)

Huzzah! We can now go to github.io and see the website hosted there! We've achieved the following diagram! Alright I'm sure we didn't even need a diagram for it, but you've come this far now - let's finish it off by placing a custom domain in front of it.

CUSTOM DOMAIN
You'll need to make sure you own a domain first before you go ahead, so have a look at a few providers and see which works best for you (take a look at the list below) . I bought mine from namecheap just because of the price and WhoIS guard features. There may be other providers that have the same features, so make sure to do a comparison!

"" In the case of Co.uk, because it is a UK domain that resides in the EU (for now) the WhoIS lookup is disabled by default - which is a huge win for privacy

Once you've purchased your domain it won't be doing much. We need to point it to somewhere. Why not our new website that github is kindly hosting for us?!

LOOK UP DNS SERVERS FOR GITHUB TO POINT To.

Taking a look at our diagram, I think we can add to it now.

Now for the final piece of the puzzle, adding in a CDN layer. I briefly spoke about the benefits in part 0, but here is a good resource if you'd like to do more reading.

"" Obviously like with anything, a CDN has some drawbacks, such as making your service now dependent on a third party for which you have no control over. Namely cloud flare in particular has had some high profile outages of recent date. Given this information I believe you can make your own mind up on what is best for yourself. For me, I the benefits far outweigh the downsides.
