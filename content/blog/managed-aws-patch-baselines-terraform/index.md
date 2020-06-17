---
date: 2020-05-26
title: "Managed AWS Patch Baselines Terraform"
description: I discuss an enhancement I made to terraform-aws-provider enabling enterprises to effectively manage patch baselines in AWS
type: posts
images:
    - images/jdheyburn_co_uk_card.png
draft: true
---

TODO include tl;dr

## AWS Primer

### EC2

Amazon Web Services (AWS) provides Cloud resources to those that require it, [for a cost](https://www.lastweekinaws.com/blog/4-reasons-lyft-is-smart-to-pay-aws-300m/) mind you. One resource in particular is a box-standard server known on AWS as [EC2 Instances](https://aws.amazon.com/ec2/) which you can secure shell ([SSH](https://www.ssh.com/ssh/)) into and do whatever you like with it - the world is now officially your oyster! :oyster:

Just like with your personal laptop, computer, mobile phone, etc., you need to patch your servers with the latest security updates to ensure that you are protected from any adversary gaining access to your devices. If they were to gain unauthorised access, they can execute whatever they like on there; whether that be sniffing around your network for some sensitive files, or [mining cryptocurrency](https://www.cybersecurity-insiders.com/hackers-cyber-attack-amazon-cloud-to-mine-bitcoins/) on your paid-for resources. Just like you earlier - your world is now officially *their* oyster!

EC2 instances are operated by you, and as per the [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/), *you* are responsible for ensuring the software is kept secured. 

### SSM & Patch Manager

AWS have a service used to help with the administration of EC2 instances called [Systems Manager (SSM*)](https://aws.amazon.com/systems-manager/). SSM is a bit of a beast and covers a lot of different functionalities - going deep on SSM is beyond the scope of this article - so you can read more about it on the [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html).

> \* SSM formerly was an acronym for Simple Systems Manager - I guess it got more complex than they thought!

To help you keep your instances patched, AWS provided the **Patch Manager** - within there it contains a number of tools to help with this. These are:

- **Patch Baselines**
  - a policy which filters available patches for your instances to what should be installed on it
  - filters which you can apply to a baseline include
    - how many days since the patch was released
    - the severity and classification of the patch
    - or even explicitly deny individual patches if you know they introduce a bug  
  - e.g. only install security classified patches marked as critical severity which have been released more than 7 days ago
- **Patch Groups**
  - a label which joins together patch baselines, to what instances they should be applied to
  - they apply to instances as a tag at the key "Patch Group"

To then perform a patch event on an instance, you will need to execute an SSM Document known as **AWS-RunPatchBaseline** on your target instances. An [SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) is essentially an automation script that you can perform on one or more instances at a time, with conditions to apply different sets of scripts depending on the operating system (OS) platform (i.e. Windows / Linux). 

**AWS-RunPatchBaseline** is one such example of a document that has both Windows and Linux stages, and it will check and install patches against the patch baseline that has been applied to your instance, via a patch group.

Say you had a security policy of ensuring instances must check for patches once a week - there's no need to manually execute the SSM Document yourself. [Maintenance Windows](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-maintenance.html) can help with that. They are essentially a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression) that you define to then execute a task. In this case we can create a maintenance window to execute the AWS-RunPatchBaseline document on a weekly basis.

## Enterprise Managed Patch Baselines

In an enterprise environment, you are more than likely to have a team dedicated to defining security policies, who will also write up patching policies (TODO include link). These policies will be followed by individual product teams to understand at minimum what patches should be installed on a server. 

For example, they may have a patching policy that states all patches marked as 'Critical' or 'Important' severity must be installed within 14 days of its release. If an out-of-band (OOB) patch is released, then it must be installed within 3 days.

These folk are the same lot who will also conjure up the **Patch Baselines** we learned about earlier. 

They may deploy these patch baselines in a stack that differs from yours. For example, imagine they deploy the baselines via a different Terraform state file to you. If you are creating **patch groups** in Terraform - you won't be able to reference the **patch baselines** they've created.

```hcl
resource "aws_ssm_patch_group" "front_end_servers" {
  baseline_id = aws_ssm_patch_baseline.front_end_servers.id # Terraform does not know about this resource!
  patch_group = "front_end_servers"
}
```

### Solution

With a [pull request](https://github.com/terraform-providers/terraform-provider-aws/pull/9486) I made to the [terraform-aws-provider](https://github.com/terraform-providers/terraform-provider-aws) project - I added the ability to pull in **patch baseline** resources that exist in the AWS account you are targeting, meaning if the enterprise security team had deployed a patch baseline via a different stack, then you can reference that in your **patch group**.

```hcl
data "aws_ssm_patch_baseline" "front_end_servers" {
  owner            = "Self"
  name_prefix      = "FrontEndServers"
  operating_system = "CENTOS"
}

resource "aws_ssm_patch_group" "front_end_servers" {
  baseline_id = data.aws_ssm_patch_baseline.front_end_servers.id
  patch_group = "front_end_servers"
}

resource "aws_instance" "front_end_server" {
  ... # variables removed for brevity 

  tags = {
    "Patch Group" = aws_ssm_patch_group.front_end_servers.id
  }
}
```

The documentation for its usage can be found [here](https://www.terraform.io/docs/providers/aws/d/ssm_patch_baseline.html). Another scenario might be where you want to reuse the **patch baselines** that AWS has created in your account. One such baseline is  `AWS-WindowsPredefinedPatchBaseline-OS-Applications`, which patches both the Windows OS, and selected Microsoft applications installed on the Windows server. 

Currently this is not the default baseline for Windows. So if you want to have this baseline assigned to a patch group, you could do something like this:

> A default baseline for an operating system is picked as the baseline for an EC2 instance which does not have a patch group assigned to it, for when the SSM document `AWS-RunPatchBaseline` executes against it.

```hcl
data "aws_ssm_patch_baseline" "windows_predefined_os_and_apps" {
  owner            = "AWS"
  name_prefix      = "AWS-WindowsPredefinedPatchBaseline-OS-Applications"
  operating_system = "WINDOWS"
}

resource "aws_ssm_patch_group" "active_directory" {
  baseline_id = data.aws_ssm_patch_baseline.windows_predefined_os_and_apps.id
  patch_group = "active_directory"
}

resource "aws_instance" "active_directory" {
  ... # variables removed for brevity 

  tags = {
    "Patch Group" = aws_ssm_patch_group.active_directory.id
  }
}
```


### Introducing Terraform

Terraform is HashiCorp's infrastructure-as-code product. 





