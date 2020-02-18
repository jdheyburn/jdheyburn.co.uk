---
date: 2019-12-20
title: "Who Goes Blogging Pt. 3: Deploy Methods"
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

# Moving Away From deploy.sh

There's nothing necessarily wrong with using `deploy.sh` to push our code, however we want to get all the bells and whistles that Continuous Integration can provide to us such as checks to [verify the markdown](https://github.com/DavidAnson/markdownlint) - of which I hope to do a future blog post about.

Now there are many CI tools out there with the most well known likely to be [Jenkins](https://jenkins.io/), but there are also hosted solutions available which will take your code and perform your pipelines against them. 

One of those hosted solutions is [TravisCI](https://travis-ci.com/). They have several pricing options available, but for public open source projects, it is completely free! 

So it is a good idea to set your source code repository on GitHub to be public. TravisCI does include (at the time of writing) private projects in their free plan, but you are capped in some shape or form on how much the platform will do for you. 

{{< figure src="/images/travis-free.png" caption="Free is definitely a thing you love to see" alt="Screenshot of Travis free pricing plan" >}}

## TravisCI Account Setup

The TravisCI account setup for TravisCI is very streamlined - instead of creating *another* account for you to manage, it integrates in with GitHub, so this is the account you use to sign-up with. Head over to https://travis-ci.com/ and click on **Sign in with GitHub**.

{{< figure src="/images/travis-landing.png" caption="You can't resist a big green button..." alt="Screenshot of Travis landing page" >}}

GitHub will ask you if you *really* want to share some of your GitHub data with Travis. Travis seems like a nice person so why not?

{{< figure src="/images/travis-github-authorise.png" caption="Another green button? Why not!" alt="Screenshot of GitHub authorising Travis" >}}

Once you've done that, you'll be redirected to your new Travis Dashboard which... is looking rather lonely {{<emoji ":frowning:" >}} - let's fix that!

All we've done so far is allowed Travis to reach GitHub for creating an account for us - we now need to activate GitHub Apps integration to permit it to read and write to our repositories. The https://travis-ci.com/account/repositories page is what you need for that - then click on the **Activate** button.

{{< figure src="/images/travis-github-apps-integration.png" caption="...More green buttons?!" alt="Screenshot of GitHub Apps Integration" >}}

Now on the next screen you may or may not want the default selection which is `All repositories` which will give Travis read and write access to all your repos. I completely trust Travis if I were to select this, however there it is a best practice to follow the *principle of least privilege* not just for users but for services too. For the scope of this effort we're only wanting Travis to read and manipulate against two repos, `jdheyburn.co.uk` and `jdheyburn.github.io`. It also gives you a cleaner Travis dashboard too.

{{< figure src="/images/travis-github-repos-selection.png" caption="TODO" alt="Screenshot of GitHub Travis Repository Authorisation" >}}

TODO After this stage, landing page https://travis-ci.com/account/repositories


## TravisCI Configuration

Once we have our Travis account set up, we need to add in a [configuration file](https://docs.travis-ci.com/user/tutorial/) that Travis will read from to determine what steps we'd like it to perform.

In our source code repository (`jdheyburn.co.uk` in my case) we want to create a file at the root directory and call it `.travis.yml`. See below for an example of how I configured mine

{{< gist jdheyburn 073bd6d4cb9284774e7e7feee093d86f >}}

Let's break it down section by section.

### Build Environment

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

These settings here all refer to the build environment that we'd like our project to build on.

`dist` specifies what platform Travis should build the project on. In this case `xenial` refers to Ubuntu 16.04, which is a Linux distribution. There are [several others](https://docs.travis-ci.com/user/reference/overview/) to choose from and more likely than not you'll want the platform to be Linux. However if you had a Windows application written in `.NET` then you would likely want it built on a Windows Server since that is what supports it. 

`git.depth` tells Travis how many commits of your project to check out. This is passed directory to the `git` parameter `--depth` (more info on that [here](https://git-scm.com/docs/git-clone)). For our use case we're not interested in this option so we set it to `false` to disable the flag being passed to `git`.

`env.global` allows us to define what variables should be set in the environment. This is done in the form of an array of strings in the format `key=value`. So given the example, `HUGO_VERSION` will be set to `0.58.3`. We'll come back to this later.

`env.matrix` is the encrypted value that gets passed to the `GITHUB_TOKEN` environment variable which is used to allow Travis to commit the built project to our GitHub Pages repo. 
- You're going to want to take the personal access token generated from GitHub in the earlier step and encrypt it using [this method](https://docs.travis-ci.com/user/environment-variables#defining-encrypted-variables-in-travisyml), then add it back to this setting

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

# From TravisCI to GitHub Actions