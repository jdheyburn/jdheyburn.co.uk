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

For this part, I will tell you about how I migrated from deploying via a script, to a CI/CD tool - namely [TravisCI](https://travis-ci.com/). Then, I will document how I migrated from this, to the new [GitHub Actions](https://github.com/features/actions), GitHub's offering into the CI/CD space.

# CI/CD?

I mentioned CI/CD a few times then, before we talk about how there are too many acronyms in Tech (future blog post? Probably not!), CI/CD stands for Continuous Integration / Continuous (Delivery|Deployment). But what do they mean?

> Both of these are practices of a DevOps culture. In a nutshell this is where a bridge is formed between the Development team writing the business logic of the application, and Operations which would handle the ongoing functionality of the application such as releases, testing, etc. 
>
> This culture aims to have the Development team to think more about how their work affects other teams, which allows them to work in harmony of each other.
> 
> For more information on DevOps, I recommend this article and the subsequent book.
> - https://www.atlassian.com/devops
> - https://www.amazon.co.uk/dp/B07B9F83WM TODO affiliate link?

## Continuous Integration

