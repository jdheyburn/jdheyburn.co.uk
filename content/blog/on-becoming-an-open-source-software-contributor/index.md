---
date: 2020-01-26
title: "On Becoming An Open Source Software Contributor"
description: Some words about having my first open source pull request merged to terraform-provider-aws
type: posts
images:
- terraform-aws.png
tags:
- aws
- documentation
- terraform
- opensource
aliases:
- /posts/on-becoming-an-open-source-software-contributor/
---

This is going to be a relatively shorter post that'll be in two parts since it's more of a self-promotion... But as of this Friday just gone, I finally had a [pull request](https://github.com/terraform-providers/terraform-provider-aws/pull/11388) approved to be merged to [terraform--provider-aws](https://github.com/terraform-providers/terraform-provider-aws)!

Okay so it's only a small piece of documentation, I've actually got another larger PR waiting to be merged in to the same project with new added functionality - and a bug fix in the pipeline too - which I hope to talk about in the future at some point. Although I can't say I'm surprised this one got approved first - since it is by far the simplest change, and increased documentation is rarely a bad thing to add to a project.

## Background

To talk a bit more about the context behind it, [AWS SSM Patch Baselines](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-patch-baselines.html) is used to define the rules of what patches should be installed on your EC2 instances. 

For patch baselines tied to Linux instances, you can only define what patches should be installed *at the OS level*. However for Windows instances - in addition to defining OS level patches - you can also define *Microsoft application patches* to be installed too!

While this can be done in the AWS Console easily enough, it is very common to define these resources as infrastructure-as-code (IaC), for which there are several to choose from. For my team we use [Terraform](https://www.terraform.io) - and we wanted a way to be able to replicate the patch baselines we could create in the console into Terraform code too.

After some digging I came across [this issue](https://github.com/terraform-providers/terraform-provider-aws/issues/8942) on `terraform-provider-aws` that indicated the functionality was missing from the provider. When in fact the support had been there all along, since the AWS provider is merely a wrapper around [aws-sdk-go](https://github.com/aws/aws-sdk-go) which calls the necessary APIs to create the resources. Where Terraform comes in is generating the dependency graphs for said resources and creating them in order asynchronously.

As you can see from the ticket, I was suggested to improve on the documentation - which leads us to where we are now. It is still pending release, however when it is out I'll link it below.

In the meantime, let me talk about the importance of documentation in the next section.

## Documentation Case Study

I'm a bit of a sucker when it comes to documentation. Yes everyone talks about how important it is to include it not just open source projects but also in your day-to-day job. A whole lot of the time there is far too much knowledge-retention and not enough knowledge-sharing. 

> This reminds me of the character Brent from the novel [The Phoenix Project](https://itrevolution.com/book/the-phoenix-project/) - who doesn't share a lot of the domain knowledge he experiences. FWIW I highly recommend the book!

In fact, documentation isn't always necessarily for sharing knowledge with others, it is also about sharing knowledge *with yourself*.

What do I mean by that?

Documenting down architecture, processes, runbooks, etc., can help to give you clarity into the subject you are writing about. Once you've extracted all the details and are able to view them at a high-level, you're able to iron out any creases and make improvements from there. 

However, more importantly, and one that is most beneficial to me is that...

**You will forget that shit and will need to reference it back again!**

{{< figure src="elephant-cartoon.png" class="center" alt="Cartoon elephant" caption="Not everyone can have the memory of an elephant..." width="400x" >}}

We are only human right? There is no way we can remember what most of us did a few weeks ago let alone a project from 6+ months ago.

## Example

As an example of this a few years ago at a previous employer, I worked on a project to build a number of microservices that acted as an onboarding layer to integrate between internal corporate services (e.g. user entitlements, processes that user had access to, etc.) and [AppDynamics](https://www.appdynamics.com/).

I laid down all the flows, the design decisions, the architecture, the models, etc., on my documentation tool of choice (currently it's [Confluence](https://www.atlassian.com/software/confluence)) as a place of reference should either my team, or myself need to refer back to it later on. 

A few months later I took an internal move to another team within the same firm. In this new team I picked up a whole load of new information, of which there was no way I was able to retain everything all at once. 

Later on when my former teammates wanted to add an additional feature to the previous project, or wanted to troubleshoot a particular bug and wanted some context behind why things were operating the way that they were, they would reach out to me. 

***At that point I directed myself and my former teammate to the documentation page for a refresher, and to let them know where they can go to solve the issue without me.***

Without that documentation I guarantee that I would've spent a whole load more time on trying to recollect my thoughts, only to waste the time of my teammate. If there was an ongoing incident too, then the time to resolution would be hastened too.

## Conclusion

Don't be that person to retain knowledge, it'll end up coming round and biting you in the arse. 

After you're done reading this, make a mental note to write down any process or piece of information you come across. Even if you're doing a task or exercise for the first time, document your steps to how you got there - you'll certainly need it in order to replicate the steps in future.

Make a small start now that will make a big difference later on.