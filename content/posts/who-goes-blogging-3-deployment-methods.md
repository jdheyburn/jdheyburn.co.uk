---
date: 2019-02-22
title: "Who Goes Blogging Pt. 3: Deployment Methods"
description: Apply DevOps practices by continuously deploying your website on any new changes
images:
- images/namecheap_landing.png
tags:
- ci/cd
- travisci
- github-actions
draft: true
---

# Recap

Since [part 1](/posts/who-goes-blogging-1-getting-started/), we have been using a simple bash script called `deploy.sh` to build our Hugo website and upload it to our GitHub Pages repo. In [part 2](/posts/who-goes-blogging-2-custom-domain/) we modified it slightly to include the `CNAME` file post-build to ensure GitHub Pages uses the custom domain we set up in that same part.

For this part, I will tell you about how I migrated from deploying via a script, to a CI/CD tool - namely [TravisCI](https://travis-ci.com/). Then I will document how I migrated from this, to the new [GitHub Actions](https://github.com/features/actions); GitHub's offering into the CI/CD space.

> `CI/CD` is an acronym for Continuous Integration / Continuous Deployment which is a very important concept in the DevOps culture.
> If you would like to find out more about that and DevOps culture, check out these resources {{<emoji ":point_down:" >}}
>
> - https://www.atlassian.com/devops
> - https://medium.com/faun/the-basics-of-continuous-integration-delivery-with-10-most-popular-tools-to-use-9514231533f0
> - https://www.redhat.com/en/topics/devops/what-is-ci-cd
> - https://www.atlassian.com/devops
> - https://www.amazon.co.uk/dp/B07B9F83WM

**Note**: if you're only interested in how to onboard GitHub Actions then [jump to that section below](#from-travisci-to-github-actions). Be wary that some of the content may refer to previous sections.

# Moving Away From deploy.sh

There's nothing necessarily wrong with using `deploy.sh` to push our code, however we want to get all the bells and whistles that Continuous Integration can provide to us such as checks to [verify the markdown](https://github.com/DavidAnson/markdownlint) - of which I hope to do a future blog post about.

Now there are many CI tools out there with the most well known likely to be [Jenkins](https://jenkins.io/), but there are also hosted solutions available which will take your code and perform your pipelines against them. 

One of those hosted solutions is [TravisCI](https://travis-ci.com/). They have several pricing options available, but for public open source projects, it is completely free! 

So it is a good idea to set your source code repository on GitHub to be public. TravisCI does include (at the time of writing) private projects in their free plan, but you are capped in some shape or form on how much the platform will do for you. 

{{< figure src="/images/travis-free.png" caption="Free is definitely a thing you love to see" alt="Screenshot of Travis free pricing plan" >}}

## TravisCI Account Setup

The TravisCI account setup for TravisCI is very streamlined - instead of creating *another* account for you to manage, it integrates in with GitHub, so this is the account you use to sign-up with. Head over to https://travis-ci.com/ and click on `Sign in with GitHub`.

{{< figure src="/images/travis-landing.png" caption="You can't resist a big green button..." alt="Screenshot of Travis landing page" >}}

GitHub will ask you if you *really* want to share some of your GitHub data with Travis. Travis seems like a nice person so why not?

<center>{{< figure src="/images/travis-github-authorise.png" caption="Another green button? Why not!" alt="Screenshot of GitHub authorising Travis" >}}</center>

Once you've done that, you'll be redirected to your new Travis Dashboard which... is looking rather lonely {{<emoji ":frowning:" >}} - let's fix that!

All we've done so far is allowed Travis to reach GitHub for creating an account for us - we now need to activate GitHub Apps integration to permit it to read and write to our repositories. The https://travis-ci.com/account/repositories page is what you need for that - then click on the `Activate` button.

{{< figure src="/images/travis-github-apps-integration.png" caption="...More green buttons?!" alt="Screenshot of GitHub Apps Integration" >}}

Now on the next screen you may or may not want the default selection of `All repositories` which will give Travis read and write access to all your repos. I completely trust Travis if I were to select this, however it is a best practice to follow the [*principle of least privilege*](https://en.wikipedia.org/wiki/Principle_of_least_privilege) (POLP); not just for users but for services too. 

For the scope of this effort we're only wanting Travis to read and manipulate against two repos, `jdheyburn.co.uk` and `jdheyburn.github.io` - it also gives you a cleaner Travis dashboard too.

<center>{{< figure src="/images/travis-github-repos-selection.png" caption="" alt="Screenshot of GitHub Travis Repository Authorisation" >}}</center>

### Back to GitHub

The next step is required to permit Travis to push the built project to our GitHub Pages repo. We need to generate a secret with the permissions that Travis requires and keep it aside for the Travis config file later.

Navigate to the [GitHub Personal Access Tokens](https://github.com/settings/tokens) page and click on `Generate new token`.

You'll come across a page asking for the name of the token being created. It doesn't matter what you call it, but it may be useful to link it back to what it is being used for. You're also going to want to select the `repo` checkbox as done so below. After this you don't need to provide any more permissions to the token. Scroll down to the end of the page and click `Generate token`.

<center>{{< figure src="/images/travis-github-pat.png" caption="" alt="Screenshot of GitHub Personal Access Token Creation - repos is checked" >}}</center>

The token's secret will display on the next screen. **Make sure you copy it** and place it somewhere you can refer back to it later such as a text editor like Notepad - we'll need it again in the next section.

<center>{{< figure src="/images/travis-github-pat-created.png" caption="" alt="Screenshot of GitHub Personal Access Token Creation - token complete" >}}</center>

## TravisCI Configuration

Once we have our Travis account set up, we need to add in a [configuration file](https://docs.travis-ci.com/user/tutorial/) that Travis will read from to determine what steps we'd like it to perform.

In our source code repository (`jdheyburn.co.uk` in my case) we want to create a file at the root directory and call it `.travis.yml`. See below for an example of how I configured mine.

{{< gist jdheyburn 073bd6d4cb9284774e7e7feee093d86f >}}

Let's break it down section by section.

### Build Environment

These settings here all refer to the build environment that we'd like our project to build on.

```yml
dist: xenial

git:
  depth: false

env:
  global:
    - HUGO_VERSION="0.58.3"
  matrix:
    secure: REDACTED
```

`dist` specifies what platform Travis should build the project on. In this case `xenial` refers to Ubuntu 16.04, which is a Linux distribution. There are [several others](https://docs.travis-ci.com/user/reference/overview/) to choose from and more likely than not you'll want the platform to be Linux. However if you had a Windows application written in `.NET` then you would likely want it built on a Windows Server since that is what supports it. 

`git.depth` tells Travis how many commits of your project to check out. This is passed directory to the `git` parameter `--depth` (more info on that [here](https://git-scm.com/docs/git-clone)). For our use case we're not interested in this option so we set it to `false` to disable the flag being passed to `git`.

`env.global` allows us to define what variables should be set in the environment. This is done in the form of an array of strings in the format `key=value`. So given the example, `HUGO_VERSION` will be set to `0.58.3`. We'll come back to this later.

`env.matrix` is the encrypted value that gets passed to the `GITHUB_TOKEN` environment variable which is used to allow Travis to commit the built project to our GitHub Pages repo. 
- You're going to want to take the personal access token generated from GitHub in the earlier step and encrypt it using [this method](https://docs.travis-ci.com/user/environment-variables#encrypting-environment-variables), then add it back to this setting

### External Dependencies

Once the build environment is defined, we can tell Travis to pull in some additional dependencies or files required for our project. Now remember this is a `hugo` project and we needed to install it on our local machines to run `deploy.sh`, we need to do the same for Travis too.

```yml
install:
- wget -q https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz
- tar xf hugo_extended_${HUGO_VERSION}_Linux-64bit.tar.gz
- mv hugo ~/bin/
```

Remember we defined `HUGO_VERSION` earlier? This is where it is called back again. In order, the steps we're performing are:

1. Downloading the archive containing the specified `hugo` version
1. Extracting all contents of the archive
1. Moving the `hugo` binary to the `~/bin/` directory
    - This directory is on the build servers `PATH`, which enables us to execute the binary using just the `hugo` command later

#### Previous Issues

In an older version of the Travis `xenial` distribution used to build the project, there was an additional dependency I needed to include. The `hugo-coder` requires to be built with Hugo Extended (notice how this is the version defined in the previous section) since it requires Sass/SCSS support. 

This required a library which was not included in the distribution in the past. On the plus side - Travis allows us to define some more steps which you can see below.

```yml
before_install:
  # This workaround is required to avoid libstdc++ errors while running "extended" hugo with SASS support.
 - wget -q -O libstdc++6 http://security.ubuntu.com/ubuntu/pool/main/g/gcc-5/libstdc++6_5.4.0-6ubuntu1~16.04.10_amd64.deb
 - sudo dpkg --force-all -i libstdc++6
```

This stage of the pipeline existed before the `install` config defined above. Simply put, all it is doing is pulling the required library and installing it on the build server.

You may not need this stage in your pipeline, I know my project no longer requires it. However this may come in handy later knowing that you have the option of specifying more pipeline steps if the build distribution you're using requires some additional dependencies.

### Build Script

Now onto the juicy stuff - building the project. This is pretty much where the `deploy.sh` starts from, since on our local machines we already had the `hugo` binary installed.

```yml
script:
- hugo version
- hugo --gc --minify
- cp CNAME public/
```

Not a lot is going on here, but to detail what each step is doing:

1. Print out the version of `hugo` being used
  - This is helpful for debugging the build. By printing out the version used we can try to replicate the bug locally for troubleshooting.

2. Build the project
    - We do this with two flags, `--gc` and `--minify`. These weren't defined in the `deploy.sh` script we used earlier so let's cover them here.
        - `--gc` tells `hugo` to cleanup some unused cache files after the build. This helps keep a tidy environment for the build server.
        - `--minify` performs [minification](https://en.wikipedia.org/wiki/Minification_(programming)) on your website to reduce the size of the generated content, enabling it to load faster on your users' devices
            - Coupled with a CDN like in the [previous part](/posts/who-goes-blogging-2-custom-domain/#adding-our-cdn-layer), your website will load almost instantly


3. Copy the `CNAME` file from the project root to the generated `public/` directory.

This ensures that the custom domain name we set up in the previous part continues to be set in the generated website code that gets pushed to our GitHub Pages repo. [See here](/posts/who-goes-blogging-2-custom-domain/#building-into-our-deploy-script) for a refresher.

> This section is effectively the 'CI' part of 'CI/CD'. We could stop here and just use Travis as a build server to determine whether the website is able to be built successfully. Any errors in the pipeline would have resulted in a failed build. 
>
> The next section details the Continuous Deployment, ensuring that on the successful build of a project we deploy it to our production environment. 

### Deploy to GitHub Pages

Once the project has been built, we need to push it to the GitHub Pages repository. Travis has [good documentation](https://docs.travis-ci.com/user/deployment/pages/) on this. My setup follows the below:

```yml
deploy:
  provider: pages
  skip-cleanup: true
  github-token: "$GITHUB_TOKEN"
  keep-history: true
  local-dir: public
  repo: jdheyburn/jdheyburn.github.io
  target-branch: master
  verbose: true
```

For the last time, let's talk about each setting here.

- `provider` tells Travis this is a GitHub Pages deployment
- `skip-cleanup` set to `true`, so that Travis does not delete the build before we've got the chance to upload it
- `github-token` is set to the environment variable `$GITHUB_TOKEN` which was set for us earlier on in the build environment
- `keep-history` performs an incremental commit against the project. Setting it to `true` allows us to view back the changes in the commit history such as [this one](https://github.com/jdheyburn/jdheyburn.github.io/commit/419da0cc71415d0253996b823d4ccf6844db4042)
- `local-dir` specifies the directory that should be pushed to the target repo. We set it to `public` because that is the name of the generated website directory from the previous `script` step
- `repo` is the target repo where we should be deploying to
- `target-branch` is the branch that we want `local-dir` to be pushed to. For our setup we are using `master`
- `verbose` specifies how much detail Travis will log about its deploy activities

That concludes the configuration section. Remember to change it or add in some other functionality needed for your project and save it to `.travis.yml`. 

## Bringing It All Together

Now you've completed your config file, let's check it all in to GitHub.

```bash
git add --all
git commit -m 'Adding CI'
git push
```

Travis will automatically detect that a new change has been made against your repo. And with the inclusion of `.travis.yml`, it will now work against that file.

You can view the status of your repository's build by navigating to it from the [dashboard](https://travis-ci.com/dashboard) and clicking on it.

If any of the commands in the `script` section of the config returned a [non-zero status code](https://en.wikipedia.org/wiki/Exit_status#Shell_and_scripts), the build will fail. If this happens then have a look at a build log and investigate the issue. More likely than not someone else has encountered the problem before, so Google is your gatekeeper to solutions!

I won't run through the build log - since this post is getting fairly long already. In Travis you can expand what each stage is doing for some more verbose output. Essentially it is no different to what we did in our original `deploy.sh` script!

# From TravisCI to GitHub Actions

If you're perfectly happy using TravisCI as your CI service then there's no need for you to do the steps below since it will be about migrating to [GitHub Actions](https://help.github.com/en/actions/getting-started-with-github-actions/about-github-actions); GitHub's CI equivalent to TravisCI. However, there are some benefits which are worth considering.

## Benefits

**Firstly and most importantly**, there is a whole community of shared actions (a set of build instructions) which can save you a HUGE amount of time when it comes to piecing together a CI pipeline. If the TravisCI config seemed a bit intimidating, then these will be a whole lot more gentler to you. 

Whereas in our Travis config we had to define the individual commands needed to set up our environment and then how to build it, there's an [action](https://github.com/marketplace/actions/hugo-setup) for that! Want to include some markdown linting? There's an [action](https://github.com/marketplace/actions/markdownlint-cli) for that! 

I think you folks get the picture now. There's an [awesome-actions](https://github.com/sdras/awesome-actions) repository worth checking out for more actions.

**Secondly**, all your DevOps tools are in one place! I'm a big sucker for [GitLab](https://about.gitlab.com/) and while I don't use it for my personal projects, I've used it in a past life and found its seamless integration with all other tools second-to-none. Not having to worry about integrating between multiple services can only increase your productivity - allowing you to focus more on the application you're writing.

## Pricing

**However** - one downsides to GitHub Actions is how many build minutes you get. Remember Travis allowed unlimited build minutes for a public repository? With Actions - you are limited to [2,000 minutes in their free plan](https://github.com/pricing). 

If you've been building your project in Travis already, you'll notice it has been building (in my case at least) in ~30 seconds. With a bit of maths we can then say we will have 4,000 builds in a month on GitHub Actions.

Given that this isn't a huge project with multiple contributors working on it, I think it's safe to say we won't ever reach this limit - unless you're churning out blog posts left right and centre!

Sound good? Let's go.

## Creating Our Workflow 

Like all great services in the world, there is [great documentation](https://help.github.com/en/actions) to go along with them. Take a look over there if you'd like the detailed version. 

What I will be focusing on is the documentation for two sets of predefined actions; [actions-hugo](https://github.com/peaceiris/actions-hugo) for building our website, and [actions-gh-pages](https://github.com/peaceiris/actions-gh-pages) for deploying it to GitHub Pages. 

### Deployment Keys Setup

The very first thing we need to do is set up some keys that will allow our source repository (where the workflow will reside on) to push the built project to the GitHub Pages repo. 

In your terminal, create those keys now and copy the contents of the public key to your clipboard. 

```bash
$ ssh-keygen -t rsa -b 4096 -C "$(git config user.email)" -f ~/.ssh/gh-pages -N ""
Generating public/private rsa key pair.
Your identification has been saved in /home/jdheyburn/.ssh/gh-pages.
Your public key has been saved in /home/jdheyburn/.ssh/gh-pages.pub
# ...

$ pbcopy < ~/.ssh/gh-pages.pub
```

> MacBooks have a handy terminal command to do this called `pbcopy`. I've created an alias on my Linux laptop that does the same
>
> `alias pbcopy="xclip -selection clipboard"`

In GitHub load up your GitHub Pages repo and navigate to `Settings` and then `Deploy keys`. Give it an appropriate name, and paste in the public key. Make sure you check `Allow write access`.

{{< figure src="/images/gha-deploy-key.png" caption="Make sure you actually place the key here!" alt="GitHub Pages repo deploy keys page" >}}

Copy the contents of the *private key* you created earlier (perhaps using your new command?! {{<emoji ":smirk:" >}}) and navigate to the source code repository's `Settings` page, then `Secrets`. You'll need to give it a sensible name as this then referred to later in the workflow configuration. Paste the private key in the value field.

{{< figure src="/images/gha-secrets-key.png" caption="No secrets here!" alt="GitHub source code repo secrets page" >}}

### Workflow Configuration

In the root directory of your source code repo, create a directory called `.github/workflows`. In this directory is where GitHub Actions will look for jobs to do. Create a `yml` file in this directory to contain your build job definition. I went ahead and named mine `deploy.yml`, but you can name it whatever you like.

I used the [example](https://github.com/peaceiris/actions-gh-pages#%EF%B8%8F-repository-type---project) provided in the `actions-gh-pages` documentation as a base for my build definition. 

{{< gist jdheyburn b4b2cad15604de30f21ad0e1a85ee6b9 >}}
