---
date: 2020-07-02
title: "Using Terraform to Manage AWS Patch Baselines at Enterprise Scale"
description: I discuss an enhancement I made to terraform-aws-provider enabling enterprises to effectively manage patch baselines in AWS with Terraform
type: posts
---

If you’re new to AWS and patching principles then continue reading, else you can [skip to juicy stuff below](#data-sources-for-patch-baselines).

## AWS Primer :cloud:

### EC2

Amazon Web Services (AWS) provides Cloud resources to those that require it, [for a cost](https://www.lastweekinaws.com/blog/4-reasons-lyft-is-smart-to-pay-aws-300m/) mind you. One resource in particular is a box-standard server known on AWS as [EC2 Instances](https://aws.amazon.com/ec2/) which you can secure shell ([SSH](https://www.ssh.com/ssh/)) into and do whatever you like with it - the world is now officially your oyster! :oyster:

Just like with your personal laptop, computer, mobile phone, etc., you need to patch your servers with the latest security updates to ensure that you are protected from any adversary gaining access to your devices.

If they were to gain unauthorised access, they can execute whatever they like on there; whether that be sniffing around your network for some sensitive files, or [mining cryptocurrency](https://www.cybersecurity-insiders.com/hackers-cyber-attack-amazon-cloud-to-mine-bitcoins/) on your paid-for resources. Just like you earlier - your world is now officially _their_ oyster!

EC2 instances are operated by you, and as per the [AWS Shared Responsibility Model](https://aws.amazon.com/compliance/shared-responsibility-model/), _you_ are responsible for ensuring the software is kept secured.

### SSM & Patch Manager

AWS have a service used to help with the administration of EC2 instances called [Systems Manager (SSM\*)](https://aws.amazon.com/systems-manager/). SSM is a bit of a beast and covers a lot of different functionalitie, going deep on SSM is beyond the scope of this article - so you can read more about it on the [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html).

> \* SSM formerly was an acronym for Simple Systems Manager - I guess it got more complex than they thought!

To help you keep your instances patched, AWS provided the [Patch Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-patch.html) - within there it contains a number of tools to help with this. These are:

- [**Patch Baselines**](https://docs.aws.amazon.com/systems-manager/latest/userguide/about-patch-baselines.html)
  - a policy which filters available patches for your instances to what should be installed on it
  - filters which you can apply to a baseline include
    - how many days since the patch was released
    - the severity and classification of the patch
    - or even explicitly deny individual patches if you know they introduce a bug
  - e.g. only install security classified patches marked as critical severity which have been released more than 7 days ago
- [**Patch Groups**](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-patch-patchgroups.html)
  - a label which joins together patch baselines, to what instances they should be applied to
  - they apply to instances as a tag at a key named `Patch Group`

To then perform a patch event on an instance, you will need to execute an SSM Document known as **AWS-RunPatchBaseline** on your target instances.

> An [SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) is essentially an automation script that you can perform on one or more instances at a time, with conditions to apply different sets of scripts depending on the operating system (OS) platform (i.e. Windows / Linux).

**AWS-RunPatchBaseline** is one such example of a document that has both Windows and Linux stages, and it will check and install patches against the patch baseline that has been applied to your instance, via a patch group.

> However if an EC2 instance is not assigned to a patch group, then AWS will pick the **default baseline** for that instances operating system

Say you had a security policy of ensuring instances must check for patches once a week - there's no need to manually execute the SSM Document yourself. [Maintenance Windows](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-maintenance.html) can help with that. They are essentially a [cron expression](https://en.wikipedia.org/wiki/Cron#CRON_expression) that you define to then execute a task. In this case we can create a maintenance window to execute the AWS-RunPatchBaseline document on a weekly basis.

The resulting relationship of all the above looks like this:

```
Maintenance Windows ──┬── invokes ───> SSM Document ─── queries ───> Patch Baseline
                      |
                      |
                      └── targets ───> Patch Groups ─── assigned to ───> EC2 Instances
```

## Infrastructure as Code Primer

Creating your resources through a web UI such as AWS Console is okay for learning in. But how do you ensure your infrastructure is repeatable across several environments? Not only that, how do you easily keep a history of the state of your application infrastructure?

This is where [infrastructure as code](https://en.wikipedia.org/wiki/Infrastructure_as_code) (IAC) comes in. IAC is where all your infrastructure resources are defined in code, and published onto a source code repository of your choosing (GitHub, GitLab, etc.).

That way you can ensure the code that defines your infrastructure can be repeated across your different application environments, and be able to view history of code changes.

It also acts as a single source of truth that everyone in your team can depend on for what the application state looks like.

There are several IAC tools that you can use:

- [CloudFormation](https://aws.amazon.com/cloudformation/) is AWS’s home-grown solution exclusively for AWS services
- There are platform-agnostic tools such as [Terraform](https://www.terraform.io/)
  - written in its own proprietary language HashiCorp Configuration Language (HCL)
  - I’ve talked about Terraform before in a [previous post](/blog/on-becoming-an-open-source-software-contributor/#background)
- Or for a language-agnostic, platform-agnostic tool - [Pulumi](https://www.pulumi.com/why-pulumi/) is the one for you.

In the case of Terraform, it keeps the current state of your infrastructure stack in a file stored in a shared remote location. This is known as the [state file](https://www.terraform.io/docs/state/index.html), and it is used by Terraform to understand what resources Terraform is aware of in your platform.

## Patch Baselines in an Enterprise Environment

When managing Terraform in an enterprise environment, it is a best practice to split up the infrastructure on the structure of the teams working on them, known as workspaces. This is something advised by [Terraform themselves](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html#the-recommended-terraform-workspace-structure). For example, you would have a workspace for billing, and one for networking. That way you can ensure teams can work effectively without treading on each others' toes.

The same principle can be applied to a security team that defines security policies, who will also write up patching policies. These policies will be followed by teams working in different workspaces to understand at minimum what patches should be installed on a server, and how quickly to install them.

> Check out the University of Exeter’s own [patching policy](https://www.exeter.ac.uk/media/level1/academicserviceswebsite/it/recordsmanagementservice/policydocuments/Patch_Management_Policy_FINAL.pdf) for an example.

For example, an enterprise may have a patching policy that states all patches with a severity marked as ‘Critical’ or ‘Important’ must be installed within 14 days of its release. If an out-of-band (OOB) patch is released, then it must be installed within 3 days.

These folk are the same lot who will also conjure up the **Patch Baselines** we learned about earlier.

They may deploy these patch baselines in a different Terraform workspace from yours. If that were the case, then if you wanted to refer back to these in your Terraform workspace, then the [`remote_state`](https://www.terraform.io/docs/providers/terraform/d/remote_state.html) resource is something you might need.

```hcl
# This example references a subnet_id created in another workspace
data "terraform_remote_state" "vpc" {
  backend = "remote"

  config = {
    organization = "hashicorp"
    workspaces = {
      name = "vpc-prod"
    }
  }
}

resource "aws_instance" "foo" {
  # ...
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id
}
```

So the above works if all parties are using Terraform workspaces. But what if you're using Terraform, and the security team (who are managing patch baselines) are using something different like the mentioned CloudFormation or Pulumi.

If you are creating **patch groups** in Terraform - you won’t be able to reference the **patch baselines** they’ve created, because they are in a different state file.

```hcl
resource "aws_ssm_patch_group" "front_end_servers" {
  baseline_id = aws_ssm_patch_baseline.front_end_servers.id # Terraform does not know about this resource!
  patch_group = "front_end_servers"
}
```

You could of course replicate the patch baseline they’ve created in your Terraform code, but then that does not scale in an enterprise.

```hcl
resource "aws_ssm_patch_baseline" "front_end_servers" {
  name = "front-end-servers"

  ... # variables removed for brevity
}

resource "aws_ssm_patch_group" "front_end_servers" {
  baseline_id = aws_ssm_patch_baseline.front_end_servers.id # Not good!
  patch_group = "front_end_servers"
}
```

This is what we want to avoid.

### Data Sources For Patch Baselines

[Data sources](https://www.terraform.io/docs/configuration/data-sources.html) in Terraform allow you to pull resources in your platform that may exist in a separate state file to yours, or even a completely different IAC tool to Terraform, such as CloudFormation. What we need is a data source component for the `aws_ssm_patch_baseline` resource.

With a [pull request](https://github.com/terraform-providers/terraform-provider-aws/pull/9486) I made to the [terraform-aws-provider](https://github.com/terraform-providers/terraform-provider-aws) project - I added the ability to pull in **patch baseline** resources that exist in the AWS account you are targeting, meaning if the enterprise security team had deployed a patch baseline via a different stack, then you can reference that in your **patch group**.

```hcl
# This resource is defined outside of the current working Terraform state
# So we are making a call to retrieve the ID of the resource in AWS
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

The documentation for its usage can be found [here](https://www.terraform.io/docs/providers/aws/d/ssm_patch_baseline.html).

Another scenario might be where you want to reuse the **patch baselines** that AWS has created in your account. One such baseline is `AWS-WindowsPredefinedPatchBaseline-OS-Applications`, which patches both the Windows OS, and selected Microsoft applications installed on the Windows server.

Currently this is not the default baseline for Windows. So if you want to have this baseline assigned to a patch group, you could do something like this:

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

## Conclusion

This is a relatively short post - but it was just a quick introduction to AWS Patch Manager. I hope you find it helpful in applying your enterprise patching strategy to your product teams!
