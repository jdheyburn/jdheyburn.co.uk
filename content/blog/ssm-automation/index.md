---
date: 2020-09-26
title: "SSM Automation WIP"
description: WIP
type: posts
tags:
  - aws
  - ssm
draft: true
---

It's been a while since my [last post](/blog/assertions-in-gotests-test-generation/) due to some changes going on in personal life. TODO fix

In this post I want to talk a little bit more about AWS SSM - this was something I touched on when discussing patch baselines in a [previous post](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager). But since SSM could be considered the dumping ground for AWS services with no other suitable home (TODO), there is another service called Automation. On first glance it may look pretty dull, but once you scratch the surface there are a number of capabilities this can unlock for you. Since it can be a bit tricky to get started, I wanted to explain some of the use cases for the Automation to help keep your plant healthy.

Since I could not find a good resource for writing SSM Automation Documents, I've written this to share my experience and hopefully help you to get started on your own Automation documents.

## SSM Re-primer

I've mentioned [SSM Documents](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager) before; to save you a click:

> An [SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) is essentially an automation script that you can perform on one or more instances at a time, with conditions to apply different sets of scripts depending on the operating system (OS) platform (i.e. Windows / Linux).

In that post I talk about how **AWS-RunPatchBaseline** is an example of a `RUN_COMMAND` document. Another type of document is known as `AUTOMATION`. AWS describes them as:

Run Command:

> Run Command uses command documents to run commands. State Manager uses command documents to apply a configuration. These actions can be run on one or more targets at any point during the lifecycle of an instance. Maintenance Windows uses command documents to apply a configuration based on the specified schedule.

Automation:

> Use automation documents when performing common maintenance and deployment tasks such as creating or updating an Amazon Machine Image (AMI). State Manager uses automation documents to apply a configuration. These actions can be run on one or more targets at any point during the lifecycle of an instance. Maintenance Windows uses automation documents to perform common maintenance and deployment tasks based on the specified schedule.

I like to use the below to differentiate between the two:

- Command documents are ran on instances themselves
- Automation document can call and orchestrate AWS API endpoints on your behalf, including executing Command documents on instances

There are also [other types](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) too which are beyond the scope of this post.

## Command Documents Example

All documents, for better or for worse, are defined in YAML. You can also define what OS each command should be executed on.

TODO include example of running ps on each OS. (or maybe a healthcheck example? so that it leads onto the next post easily)

That was a relatively simple example of a command document. However you may have a document which is much more verbose and has several more steps, and trying to read lines of code in amongst all that YAML can be tedious. 

A common pattern when executing command documents is to have two steps:

1. Download the script in question from S3
2. Execute the script from the download location

Such a command document would have a composition as below, for the same scenario provided previously.

TODO include example of running ps on each OS, downloading from S3. 

This involves having your script first uploaded to S3. Thankfully, through the power of [infrastructure-as-code](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#infrastructure-as-code-primer), you can have this automatically deployed to your environment once the module is written. An example of this can be seen below.

TODO include TF example of above 

## Automation Documents Example

So now we have a command document that performs healthchecks for us. What if we wanted to have this script executed after a patching event?

In the simplest form, the automation document would look something like this:

TODO add patch appian example

This document is made up of two steps, one is calling **AWS-RunPatchBaseline**, while the next one is the healthcheck document we created in the previous heading.

Now we can modify our patching maintenance window (TODO where to reference?) to use the new automation document we created instead.

TODO show updated mw

We can then do some cool stuff with maintenance window properties, such as ensuring only one instances is being patched at a time, and to abort any further patching if the automation document failed for whatever reason (such as a bad healthcheck post-patching).

TODO show this config

Note that you can replicate this behaviour in the AWS Console should you want to test your Automation document outside of a maintenance window.

TODO show the automation rate control example in Execute Automation SSM bit, then talk about how users can get set up on that

## Advanced Automation Example

The previous examples have been pretty basic thus far - only calling run commands that we have written ourselves.