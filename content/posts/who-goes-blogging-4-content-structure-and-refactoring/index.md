---
date: 2020-03-24
title: "Who Goes Blogging 4: Content Structure & Refactoring"
description: Performing refactoring and reorganising how my Hugo website is structured
images:
  - images/github-actions-build.png
tags:

draft: true
---

So far in this series we've been looking at the infrastructure behind the Hugo website, but I haven't looked into improving the content layout of the site.

Some of the improvements to make:

1. Moving from a flat structure to a leaf bundle
1. Move posts to be under blog
1. Adding table of contents

## Moving from a flat structure to a leaf bundle

Hugo has a few different ways you can organise your content, known as [Page Bundles](https://gohugo.io/content-management/page-bundles/). So far I've been adopting the **Branch Bundle** where I have all my articles in named markdown files under the `content/posts` directory, and storing all images under the `static/images` - so the article at `content/posts/blog-bootstrap.md` will be available at `/posts/blog-bootstrap/`. As time has gone on, the images directory has gotten rather large and difficult to understand what images apply to what posts.


The alternative way to organise content is the **Leaf Bundle**. This is where at a branch level you have a directory with the name of the article you wish to publish, followed by an `index.md` file with the article content such as `content/posts/blog-bootstrap/index.md`. Any page resources defined in this directory can be referenced relatively in the markdown files within it, such that any images can be stored within `content/posts/blog-bootstrap/` and referred to in the markdown as `{{< figure src="my-relative-img.png" ...` as opposed to `{{< figure src="/images/my-not-relative-img.png" ...`. 

This allows me to organise content much more effectively such that we will be going from this structure:

```bash
$ tree content/posts 
content/posts
├── blog-bootstrap.md
├── extending-gotests-for-strict-error-tests.md
├── on-becoming-an-open-source-software-contributor.md
├── three-ways-to-spice-up-your-python-code.md
├── who-goes-blogging-0-applying-cartography.md
├── who-goes-blogging-1-getting-started.md
├── who-goes-blogging-2-custom-domain.md
├── who-goes-blogging-3-1-deployment-methods-travisci.md
└── who-goes-blogging-3-2-deployment-methods-github-actions.md

0 directories, 9 files
```

```bash
$ tree static/images 
static/images
├── analytics_example.png
├── ...                     # Everything stored in a flat hierarchy
└── type_hinting.png

0 directories, 57 files
```

To this:

```bash
$ tree content/posts
content/posts
├── blog-bootstrap
│   └── index.md
├── extending-gotests-for-strict-error-tests
│   └── index.md
├── on-becoming-an-open-source-software-contributor
│   ├── card.png
│   ├── elephant-cartoon.png
│   └── index.md
├── ...                     
└── who-goes-blogging-3-2-deployment-methods-github-actions
    ├── gha-deploy-key.png
    ├── gha-secrets-key.png
    ├── github-actions-build.png
    ├── index.md
    └── travis-disable-build.png

9 directories, 45 files
```

### Script

This is something we can script pretty easily. Firstly to add new leaves to our branch at `content/posts` we can use the below:

```bash
posts=$(find content/posts -type f -name '*.md' -not -path '**/index.md' -not -path '**/_index.md')
echo "$posts" | while read p; do
    filename=$(basename -- "$p")
    title="${filename%.*}"
    mkdir content/posts/$title
    git mv -v $p content/posts/$title/index.md
done
```

For a quick breakdown of the above; we are getting all markdown files in the existing branch, extracting the article name, creating a new directory with that name, then move the article to `index.md` in that directory.




