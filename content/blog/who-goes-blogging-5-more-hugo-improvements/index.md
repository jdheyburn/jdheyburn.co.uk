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

**`<center>` tags not rending correctly.**

I believe the new Hugo version broke this one, where images that were wrapped in `<center>` tags were simply disappearing. I had been wrapping `{{ figure ... }}` shortcodes in `<center>` tags in order to horizontally centre images - but it looks like the new version causes these images to appear completely. 

It looks like the `figure` shortcodes now support `center` as a `class` property. Therefore we go from...

`<center>{{ figure src="image-name.png" }}</center>`

To...

`{{ figure src="image-name.png" class="center" }}`

**Lists not rendering as before**

It turns out that my markdown for articles wasn't as watertight as I thought; Hugo is now a whole lot more strict in ensuring your syntax is correct. Check these two before and after for comparison.

{{< figure src="old-render-list.png" caption="" alt="Screenshot showing old, proper list render" >}}

{{< figure src="new-render-list.png" caption="" alt="Screenshot showing new, incorrect list render" >}}

For this I just needed to fix the markdown by adding another indent to the list item. 

{{< figure src="git-diff-list.png" caption="" alt="Screenshot showing git diff between old and new list" >}}

I saw several cases of this, and including a [markdown linter](https://github.com/igorshubovych/markdownlint-cli) in the CI/CD pipeline would help to prevent this. This is something I'll look to include in the near future.

## Adding New Features

The whole reason to upgrade both Hugo and the theme was to explore some of the new features that come in both of them, so let's get adding them.

## Adding Series Links in Content Footer

The hugo-coder theme now has better support for series, articles that directly follow on from one another, such as this Who Goes Blogging one. Series are nothing new to Hugo and we could have done them with the version we upgraded from, only in [this commit for hugo-coder](https://github.com/luizdepra/hugo-coder/commit/27e83b1e5a9d8b7bbd42d202bd5ef57adcce659b) has it added a layout for it to be rendered.

To create a series, we use the `series` front matter setting for articles. For the Who Goes Blogging articles, adding the front matter to them looks like this.

```yml {hl_lines=["5-6"]}
---
date: 2020-03-10
title: "Who Goes Blogging 3.2: Deployment Methods - GitHub Actions"
#...
series:
- Who Goes Blogging
tags:
#...
---
```

Once this is done for all pages, hugo-coder will render the **See also in ...** section at the article footer.

{{< figure src="series-footer-section.png" caption="" alt="Screenshot showing series rendered in the page footer" >}}

## Adding Table of Contents

### Template Lookup Order Primer

Okay this one isn't exactly a new feature of the theme, but since we're playing around with the theme we may as well make use of this opportunity. Table of contents (TOC) aren't included by default in the `hugo-coder` theme, so we need to add it in ourselves. 

There is some [documentation](https://gohugo.io/content-management/toc/) on how to add TOC to your articles. Before we do that we need to revisit how layouts are organised as discussed briefly in [a previous post](/blog/who-goes-blogging-4-content-structure-and-refactoring/#fixing-article-rendering).

The type of a markdown file (defined by the front matter setting `type`) tells Hugo where to look for in the `layouts/` directory of your project. The Hugo theme you're using will already have these all defined, hence why they are predefined themes! Before Hugo looks for these layout HTML files in your theme, it will check for them in your projects `layouts/` directory first.

In other words, the order of presedence (or hierarchy) for HTML files is anything in the project `layouts/` directory takes a higher priority than that in your theme - as described in Hugo's [documentation for template lookup order](https://gohugo.io/templates/lookup-order/).

See below for a directory tree explaning this - a lot of content has been removed for brevity.

```bash
$ tree layouts                                          
layouts
├── posts
│   └── single.html					# Hugo will use this file to render your HTML
└── themes
    └── hugo-coder
	    └── layouts
			└── posts
			    └── single.html     # hugo will ignore this one in the themes directory
```

### Implementation

The primer above gives a hint as to what file we need to modify. The [`single.html`](https://github.com/luizdepra/hugo-coder/blob/master/layouts/posts/single.html) file is in charge of how articles are rendered. Since we want everything else to remain the same about this file, we can take a copy of the file as it currently stands and place it into our project root.

```bash
mkdir layouts/posts
cp -v themes/hugo-coder/layouts/posts/single.html layouts/posts
```

> I won't go into the details here, I'll leave that to you to make changes to see how they affect the rendering of the page.

I want the TOC to appear before the main content, but after the featured image for the article (if there is any). Based on this the files is going to need the highlighted change below.

```html {linenos=table,hl_lines=["33"],linenostart=29}
      <div>
        {{ if .Params.featured_image }}
          <img src='{{ .Params.featured_image }}' alt="Featured image"/>
        {{ end }}
        {{ partial "toc.html" . }}
        {{ .Content }}
      </div>
```

We're not done there. We're referencing a [partial template file](https://gohugo.io/templates/partials/) here. These allow us to reuse HTML files in multiple places, or to break up a large HTML file into smaller, more easier to manage chunks. 

Partial templates are found under the `layouts/partials` directory and follow the same principle as defined in the primer for template lookups, and are referenced back as `{{ partial "<partial_name>.html" . }}`.

Let's go ahead and create the `layouts/partials/toc.html` file and populate it as below.

```html
{{ if and (gt .WordCount 400 ) (.Site.Params.toc) }}
<aside>
    {{.TableOfContents}}
</aside>
{{ end }}
```

This is similar to [Hugo's example](https://gohugo.io/content-management/toc/#template-example-toc-partial) but just tweaked a bit. I'm not looking to do anything too fancy with it just yet, but maybe later on.

Previewing it by `hugo serve` we should get something that appears as below.

{{< figure src="completed-toc.png" caption="" alt="Screenshot showing rendered Table of Contents" >}}

### Nuances Along The Way

As the heading suggests, there were a few extra things I needed to change before releasing it into the wild.

**Fix improper headings**

Per [Table of Contents Usage documentation](https://gohugo.io/content-management/toc/#usage), Hugo will render from `<h2>` headings, which are defined as `##` in markdown. So `# Introduction` would not be included in the TOC, but `## Introduction` will.

This is a problem for some of my articles since I've been writing headings liberally at the wrong level. 

{{< figure src="improper-toc-headings.png" caption="Notice the *Applying Cartography* heading doesn't appear in the TOC" alt="Screenshot showing table of contents not including all headings for a post" >}}

The given example above shows what happens when we use `# Heading Name` instead of `## Heading Name`. To fix this I just need to go through each TODO finish


TODO 

- Fix emojis too (use the correct format and add the fix for them in headings too if not done already)
