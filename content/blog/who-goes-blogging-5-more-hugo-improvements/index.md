---
date: 2020-04-05
title: "Who Goes Blogging 5: More Hugo Improvements"
description: TODO
type: posts
images:
- namecheap_landing.png
tags:

draft: true
---

## Intro

In this article we're going to continue making some improvements to our Hugo website. Some of the things going to be covered are:

1. Upgrading our Hugo theme
1. Upgrading the Hugo version
1. Adding table of contents

So far since this website has launched we haven't upgraded either the Hugo version used to build our website, alongside the theme being used. Hugo is a very active project with new features and bug fixes being added all the time. 

By not upgrading Hugo, we are missing out on enhancements that we can make to the site - I'll cover such examples of these later on. As for upgrading the theme, improvements in the styling or even making use of said new features in Hugo can be added as part of the theme. Remember when you execute a `hugo` command which turns the website from markdown to rendered HTML files, that the theme chosen will be used to render those files. 



## Upgrading Hugo

This varies depending on what OS you are running on, but it is pretty much identical as the steps taken to install Hugo in the first place. Even the [documentation for upgrading](https://gohugo.io/getting-started/installing/#upgrade-hugo) is a one-liner:

> Upgrading Hugo is as easy as downloading and replacing the executable you’ve placed in your `PATH` or run `brew upgrade hugo` if using Homebrew.

A quick execute of `hugo version` tells us what we're currently running. We can then have a look at the [Hugo release page](https://github.com/gohugoio/hugo/releases/) to find the latest one - which at the time of writing is [0.68.3](https://github.com/gohugoio/hugo/releases/tag/v0.68.3).

```bash
$ hugo version
Hugo Static Site Generator v0.58.3-4AAC02D4/extended linux/amd64 BuildDate: 2019-09-19T15:34:54Z
```

I run Linux so I would need to replace the executable on my `PATH`. This can be done with a handy script to pull the archive and install it for us.

```bash
HUGO_VERSION="0.68.3"
wget "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz"
tar -zxvf "hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz" hugo
sudo mv -v hugo /usr/local/bin
hugo version
rm "hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz"
```

Remember that the hugo-coder theme requires the extended version of Hugo in order for it to render files correctly.

> You can see where `hugo` is currently installed on your system with the command `which hugo`, given it is in your `PATH`.

Executing `hugo version` one more time confirms if the upgrade took place.

```bash
$ hugo version
Hugo Static Site Generator v0.68.3-157669A0/extended linux/amd64 BuildDate: 2020-03-24T12:13:38Z
```

### Testing For Any Issues

At this point I would advise you do some testing with the new version to determine if your site is not only rendering as expected but functioning too. You can do this with the good old `hugo serve` command as you would have used before when writing out articles, and fixing anything that looks out of place.

However, since I'm going to be upgrading the hugo theme too, I'll do my testing in one hit then.

### Updating Hugo in CI/CD

We've only upgrading Hugo on our machines, but we also need to upgrade it in our CI/CD pipeline to ensure it deploys with the correct rendering too. We set this up in parts [3.1](/blog/who-goes-blogging-3-1-deployment-methods-travisci/) and [3.2](/blog/who-goes-blogging-3-2-deployment-methods-github-actions/).

I'm using GitHub Actions for my CI/CD pipeline, so I need to head to `.github/workflows/deploy.yml` and change `hugo-version: "0.58.3"` to `hugo-version: "0.68.3"`. t's as easy as that!

## Upgrading Hugo Theme

### A git submodules recap

As mentioned before, I'm using hugo-coder as the theme for my Hugo website. One of the cool things about `git submodules` is I don't need to have a copy of the source code for the theme in my project. I can just reference the codebase at a particular point in time - or a commit, and `git` will pull in the resources for which then my Hugo website can utilise it.

We already defined this back in the [first post of this series](/blog/who-goes-blogging-1-getting-started/), in our root directory we created a file called `.gitmodules` with the following contents:

```bash
[submodule "themes/hugo-coder"]
	path = themes/hugo-coder
	url = https://github.com/luizdepra/hugo-coder.git
```

Line by line, we are giving the submodule a name, telling `git` where to check out the module to, and lastly where `git` can find the repository for the module when we checkout our project.

When we pull in the submodule for the first time, it creates a tree in our projects `.git/modules` filled with metadata about the submodule.

```bash
$ tree .git/modules/themes/hugo-coder -L 1
.git/modules/themes/hugo-coder
├── branches
├── config
├── description
├── HEAD
├── hooks
├── index
├── info
├── logs
├── objects
├── packed-refs
└── refs
```

> The `.git/` directory contains all the metadata about your repository so that `git` knows where to pull/push to/from the repository, [amongst other things](https://githowto.com/git_internals_git_directory). It has a near identical directory structure to the one shown above.

One of the files in this directory is called `HEAD`, and it contains the commit of which `git` should checkout the submodule

```bash
$ cat .git/modules/themes/hugo-coder/HEAD
e66c1740611b15eee0069811d10b5a22b0dc4332
```

We can even view this commit in the repository at https://github.com/luizdepra/hugo-coder/commit/e66c1740611b15eee0069811d10b5a22b0dc4332.

### Upgrading Submodules

To upgrade submodules in your project, you simply need to execute `git submodule update --recursive --remote`. We can then check the value in `.git/modules/themes/hugo-coder/HEAD` and see what this is updated to.

```bash
$ cat .git/modules/themes/hugo-coder/HEAD
acb4bf6f2dcce51a27dc0e1f1008afb369d378d8
```

Nice - this has changed from the previous value. We can jump over to GitHub to verify this is indeed the latest version.

{{< figure src="hugo-coder-commit.png" caption="Verify at the GitHub repo page https://github.com/luizdepra/hugo-coder/commit/master" alt="Screenshot showing latest hugo-coder version in GitHub" >}}

## Validation and Testing

Now comes the testing part, ensuring that everything is working as intended with both the new Hugo version and the latest hugo-coder submodule. Some of the issues I came across were:


## New Features Available

