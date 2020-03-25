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

Hugo has a few different ways you can organise your content, known as [Page Bundles](https://gohugo.io/content-management/page-bundles/). So far I've been adopting **Branch Bundles** where I have all my articles in named markdown files under the `content/posts` directory, and storing all images under the `static/images` - so the article at `content/posts/blog-bootstrap.md` will be available at `/posts/blog-bootstrap/`. As time has gone on, the images directory has gotten rather large and difficult to understand what images apply to what posts.

The alternative way to organise content is the **Leaf Bundle**. This is where at a branch level you have a directory with the name of the article you wish to publish, followed by an `index.md` file with the article content such as `content/posts/blog-bootstrap/index.md`. Any page resources defined in this directory can be referenced relatively in the markdown files within it, such that any images can be stored within `content/posts/blog-bootstrap/` and referred to in the markdown as `figure src="my-relative-img.png" ...` as opposed to `src="/images/my-not-relative-img.png" ...`. 

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

One other benefit of grouping all content together in a bundle is it allows you to use just one command to add your article content to the repository - no more will images in another directory be forgotten about!

```bash
git add content/blog/$articleName
```

### Script

We can script something that can do this for us easily enough.

{{<highlight bash "linenos=table" >}}
# in project root dir
posts=$(find content/posts -type f -name '*.md' -not -path '**/index.md' -not -path '**/_index.md')
echo "$posts" | while read p; do
    # Move to leaf bundle
    postFname=$(basename -- "$p")
    title="${postFname%.*}"
    leafBundleDir=content/posts/$title
    mkdir $leafBundleDir
    newPostLocation=$leafBundleDir/index.md
    git mv -v $p $newPostLocation

    # Move images referenced in the articles to new leaf bundle dir
    images=$(grep -oP 'images\/.*.(png|jpg|jpeg)' $newPostLocation | xargs -n1 | sort -u)
    echo "$images" | while read i; do
        [ -z "$i" ] && continue
        imgFname=$(basename -- "$i")
        git mv -v static/$i $leafBundleDir/$imgFname
    done

    # Change references to images in the article
    ## figure src="/images/namecheap-domain-purchase.png"
    sed -i 's/src="\/images\//src="/g' $newPostLocation
    ## images:
    ##   - images/namecheap_landing.png
    sed -i 's/- images\//- /g' $newPostLocation
    ## [blog_arch]: /images/blog-arch-cover.png
    sed -i 's/: \/images\//: /g' $newPostLocation
    git add $newPostLocation
done
{{</highlight >}}

Let's break down what's going on here. Firstly we are retrieving all posts that aren't already converted to a leaf bundle and looping over them, where lines 4-9 performs the conversion itself. 

Once that is done then we need to get all images that are referenced in that post and move them to the new leaf bundle for the post. This is done in lines 12-17.

Lastly, we then need to change the post content itself so that it references images in the location relative to the leaf bundle instead of under `static/images` - lines 21-26 accomplish this. Hugo allows you to define `img` blocks in several ways, and I probably need to have a uniform way of doing this. However for the time being, 3 `sed` commands will do the trick for me. 

> I'm sure that a few lines could be cut out with some better regex expressions - but I'm not an expert at them so I'd rather crack on with what I know :smiley:

## Move from posts to blog

A gripe I've had with my site is when you click on **Blog** in the site header it takes you to **Posts**. Similar to the previous section this is because of [Branch Bundles](https://gohugo.io/content-management/page-bundles/#branch-bundles) which are any directory that sits underneath the `content` directory. The bundle name here is what forms the URL and the parent page for those articles [as defined](https://gohugo.io/content-management/sections/).

Based on this information, migrating should be as easy as...

```bash
$ git mv content/posts/ content/blog/
```

However in doing that:

1. We lose the correct rendering for the article
1. Existing URL links are broken
1. Blog landing page is now **Blogs**??

{{< figure src="blogs-landing-page.png" alt="Screenshot of Blog landing page with incorrect Blogs title" >}}

### Fixing Article Rendering

In the previous section we just made our existing articles leaf bundles since they sit underneath the posts bundle, like so:

```bash
$ tree contents/posts -L 1
content/posts
├── blog-bootstrap
├── extending-gotests-for-strict-error-tests
├── on-becoming-an-open-source-software-contributor
├── three-ways-to-spice-up-your-python-code
├── who-goes-blogging-0-applying-cartography
├── who-goes-blogging-1-getting-started
├── who-goes-blogging-2-custom-domain
├── who-goes-blogging-3-1-deployment-methods-travisci
└── who-goes-blogging-3-2-deployment-methods-github-actions

9 directories, 0 files
```

However, the section of which your article sits underneath also tells Hugo how it should render the page - known as [Content Types](https://gohugo.io/content-management/types/#defining-a-content-type). Take the article blog-bootstrap which is under `posts`; Hugo will look in the theme for `layouts/posts` for `.html` to render* - this is how the articles go from a markdown file to rendered HTML.

> \* Hugo will [first look](https://gohugo.io/templates/lookup-order/) in your local project for any overriding files.

```bash
$ tree themes/hugo-coder/layouts/posts 
themes/hugo-coder/layouts/posts
├── li.html
├── list.html
└── single.html

0 directories, 3 files
```

When we change the section name the article sits in, Hugo will not know how to render it correctly and will resolve to the default rendering for the theme. This ends us with something like the below.

{{< figure src="posts-blog-rendering-error.png" alt="Screenshot of comparison of correct and incorrect rendering - publish date, minutes to read, and tags are missing" caption="Correct rendering on the left - notice publish date, minutes to read, and tags are missing" >}}

One way of fixing this would be to also change the `hugo-coder` theme from `layouts/posts` to `layouts/blog` - however a much simpler solution exists. We can use the `type` front-matter setting to tell Hugo what layout to use to render it.

{{<highlight yml "hl_lines=5" >}}
---
date: 2020-03-10
title: "Who Goes Blogging 3.2: Deployment Methods - GitHub Actions"
description: Migrating to GitHub Actions as our CI tool
type: posts
# ...
---
{{</highlight>}}

Having to define this in every new article can become repetitive. We can make this easier for ourselves by using [archetypes](https://gohugo.io/content-management/archetypes/); which are essentially templates that new content is templated from. 

In your project root directory, create the `archetypes/blog` directory and in there a file called `index.md`, and populate it with the below:

```yml
---
draft: true
type: posts
# ...           Add in other defaults as you see fit
---
```

You can then create new content from this template like so:

```bash
$ hugo new --kind blog blog/blog-post 
/home/jdheyburn/projects/jdheyburn.co.uk/content/blog/blog-post created
 
$ tree content/blog/blog-post         
content/blog/blog-post
└── index.md

0 directories, 1 file

$ cat content/blog/blog-post/index.md 
---
draft: true
type: posts
# ...
---
```

### Fix Existing URLs

Changing the section the article is in affects the URL too; meaning articles will appear at `https://jdheyburn.co.uk/blog/blog-bootstrap/` instead of `https://jdheyburn.co.uk/posts/blog-bootstrap/` - which means existing hyperlinks pointing to these articles will break. Unlike earlier when we changed image paths, we can make use of the `aliases` front-matter setting to define this for us.

{{<highlight yml "hl_lines=6-7" >}}
---
date: 2020-03-10
title: "Who Goes Blogging 3.2: Deployment Methods - GitHub Actions"
description: Migrating to GitHub Actions as our CI tool
type: posts
aliases:
    - /posts/who-goes-blogging-3-2-deployment-methods-github-actions/
# ...
---
{{</highlight>}}



From what we've just found, there are a couple of steps for us to achieve this:

1. Rename `content/posts` to `content/blog`
    - Introduce `_index.md` to correctly set the page title
1. Set the `type` front-matter property on articles to `posts`
1. Redirect `/posts/` and `/posts/<ARTICLE>/` to their new correct respective locations.
1. Point **Blog** in the header to the correct location

