---
date: 2020-03-24
title: "Who Goes Blogging 4: Content Structure & Refactoring"
description: Performing refactoring and reorganising how my Hugo website is structured
type: posts
images:
  - images/github-actions-build.png
tags:

draft: true
---

So far in this series we've been looking at the infrastructure behind the Hugo website, but I haven't looked into improving the content layout of the site. Some of the improvements I want to make are:

1. Moving content articles from a flat structure to a leaf bundle
1. Rename content section to **blog** from **posts**
1. Adding table of contents to articles

## Content Article Reorganising

Hugo has a few different ways you can organise your content, known as [Page Bundles](https://gohugo.io/content-management/page-bundles/). Up to now  I've adopted [Branch Bundles](https://gohugo.io/content-management/page-bundles/#branch-bundles) where I have all my articles in named markdown files under the `content/posts` directory - acting as the branch bundle, and storing all images under `static/images` - so the article at `content/posts/blog-bootstrap.md` will be available at `/posts/blog-bootstrap/`. As time has gone on, the images directory has gotten rather large and difficult to understand what images apply to what posts.

The alternative way to organise content is the [Leaf Bundle](https://gohugo.io/content-management/page-bundles/#leaf-bundles). This is where at a branch level you have a directory with the name of the article you wish to publish, followed by an `index.md` file with the article content - such as `content/posts/blog-bootstrap/index.md`. 

Any page resources defined in this directory can be referenced relatively in the markdown files within it, such that any images can be stored within `content/posts/blog-bootstrap/` and referred to in the markdown as `figure src="my-relative-img.png" ...` as opposed to `src="/images/my-not-relative-img.png" ...`. 

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

### Transformation Script

As opposed to doing the transformation manually, I've written a script which will move and alter the files for us.

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

Breaking down the script, firstly we are retrieving all posts that aren't already converted to a leaf bundle and looping over them, where lines 4-9 performs the conversion itself. 

Once that is done then we need to get all images that are referenced in that post and move them to the new leaf bundle for the post. This is done in lines 12-17.

Lastly, we then need to change the post content itself so that it references images in the location relative to the leaf bundle instead of under `static/images` - lines 21-26 accomplish this. 

Hugo allows you to define `img` blocks in several ways, where I'm currently using 3 of these methods. I ~~probably~~ should replace these with one approach - for the time being 3 `sed` commands will do the trick for me. 

> I'm sure that a few lines could be cut out with some better regex expressions - but I'm not an expert at them so I'd rather crack on with what I know :smiley:

## Renaming Content Section

A gripe I've had with my site is when you click on **Blog** in the site header it takes you to **Posts**. Similar to the previous section this is because of [Branch Bundles](https://gohugo.io/content-management/page-bundles/#branch-bundles) which are any directory that sits underneath the `content` directory. The bundle name here is what forms the URL and the parent page for those articles [as defined](https://gohugo.io/content-management/sections/).

Based on this information, migrating should be as easy as...

```bash
$ git mv content/posts/ content/blog/
```

Despite doing this, we come across some problems...

1. We lose the correct rendering for the article
    - Hugo doesn't know how to render content with type `blog`
1. Existing URL links are broken
    - All hyperlinks both internal and external are referring to articles at `/posts/`
1. Blog landing page is now **Blogs**?? (see below)

{{< figure src="blogs-landing-page.png" alt="Screenshot of Blog landing page with incorrect Blogs title" >}}

Let's walk through them one by one.

### Fixing Article Rendering

We just made our existing articles leaf bundles that sat under `content/posts`, but now this is renamed to `content/blog`:

```bash
$ tree contents/blog -L 1
content/blog
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

The section of which your article sits underneath also tells Hugo how it should render the page - known as [Content Types](https://gohugo.io/content-management/types/#defining-a-content-type). Take the article blog-bootstrap which is under `posts`; Hugo will look in the theme for `layouts/posts` for `html` files to render it against* - this is how the articles go from a markdown file to rendered HTML.

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

One way of fixing this would be to also change the `hugo-coder` theme from `layouts/posts` to `layouts/blog` - however a much simpler solution exists. We can use the `type` front matter setting to tell Hugo what layout to use to render it.

{{<highlight yml "hl_lines=5" >}}
---
date: 2020-03-10
title: "Who Goes Blogging 3.2: Deployment Methods - GitHub Actions"
description: Migrating to GitHub Actions as our CI tool
type: posts
# ...
---
{{</highlight>}}

> Hugo [front matter](https://gohugo.io/content-management/front-matter) are content parameter settings you place into the heading of the content - an example of this is right above!

Having to define this in every new article can become repetitive. We can make this easier for ourselves by using [archetypes](https://gohugo.io/content-management/archetypes/); which are essentially templates that new content is templated from. 

In your project root directory, create the `archetypes/blog` directory and in there a file called `index.md`, and populate it with the below:

```yml
---
draft: true
type: posts
# ...       Add in other defaults as you see fit
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

### Fixing Existing URLs

Changing the section the article is in affects the URL too; meaning articles will appear at `https://jdheyburn.co.uk/blog/blog-bootstrap/` instead of `https://jdheyburn.co.uk/posts/blog-bootstrap/`. Therefore existing hyperlinks pointing to these articles will break. 

Tnere is another quick fix available for us through the front matter setting `aliases`.

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

You can read more about how `aliases` does its operations [here](https://gohugo.io/content-management/urls/#aliases).


### From Blogs to Blog

Earlier on, we came across this weird bug...

{{< figure src="blogs-landing-page.png" alt="Screenshot of Blog landing page with incorrect Blogs title" >}}

This is occuring because of the translation feature of Hugo (sourced from [i18n](https://gohugo.io/functions/i18n/)) which converts singular word titles to plural on content section landing pages, since Hugo is listing them out. This made sense when our previous section name was posts, but now we'd rather it have say blog.

Remembering that `content/blog` is a [branch bundle](https://gohugo.io/content-management/page-bundles/#branch-bundles), we can override the inferred title with a `_index.md` file at that directory.

```bash
# content/blog/_index.md
---
title: Blog
type: posts
---
```

We have another `type: posts` setting here because similar to above, we want Hugo to render the landing page the same as we did for posts.

### Heading to Blog

Lastly and most easily, the **Blog** shortcut at the top-right corner of the page still directs us to `/posts` - we need to change that in the top-level `config.toml` to point to `/blog`.

