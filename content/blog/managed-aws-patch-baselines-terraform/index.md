---
date: 2020-05-26
title: "Managed AWS Patch Baselines Terraform"
description: I discuss a method allowing 
type: posts
images:
    - images/jdheyburn_co_uk_card.png
draft: true
---


Amazon Web Services (AWS) provides Cloud resources to those that require it, [for a cost](https://www.lastweekinaws.com/blog/4-reasons-lyft-is-smart-to-pay-aws-300m/) mind you. One resource in particular is a box-standard server which you can secure shell (SSH) into, and do whatever you like with it - the world is now officially your oyster! :oyster:

Just like with your personal laptop, computer, mobile phone, etc., you need to patch it with the latest security updates to ensure that you are protected from any adversary gaining access to your devices. Once they have access they can execute whatever they like on there; whether that be sniffing around your network for some sensitive files, or [mining cryptocurrency](https://www.cybersecurity-insiders.com/hackers-cyber-attack-amazon-cloud-to-mine-bitcoins/) on your paid-for resources. Just like you earlier - the world is now officially *their* oyster!

EC2 instances are operated by you, and as per the [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/), *you* are responsible for ensuring it is secured. AWS have a service used to help with the administration of EC2 instances called Systems Manager (SSM*). SSM is a bit of a beast and covers a lot of different functionalities - going deep on SSM is beyond the scope of this article - so you can read more about it on the [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html).

> \* SSM formerly was an acronym for Simple Systems Manager - I guess it got more complex than they thought!

To help you keep your instances patched, AWS provided the **Patch Manager** - within there it contains a number of tools to help with this. These are:

- **Patch Baselines**
  - a policy which filters available patches for your instances to what should be installed on it
  - filters which you can apply to a baseline include
    - how many days since the patch was released
    - the severity and classification of the patch
    - or even explicitly deny individual patches if you know they introduce a bug  
   e.g. only install security classified patches marked as critical severity which have been released more than 7 days ago
- **Patch Groups**
  - a label which joins together patch baselines, to what instances they should be applied to
  - they apply to instances as a tag at the key "Patch Group"

To then perform a patch event on an instance, you will need to execute an SSM Document known as **AWS-RunPatchBaseline** on your target instances. An [SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) is essentially an automation script that you can perform on one or more instances at a time, with conditions to apply different sets of scripts depending on the operating system (OS) platform (i.e. Windows / Linux). 

AWS-RunPatchBaseline is one such example of a document that has both Windows and Linux stages, and it will check and install patches against the patch baseline that has been applied to your instance, via a patch group.

Say you had a security policy of ensuring instances must check for patches once a week - there's no need to manually execute the SSM Document yourself. **Maintenance Windows** can help with that. They are essentially a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression) that you define to then execute a task. In this case we can create a maintenance window to execute the AWS-RunPatchBaseline document.

