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

All documents, [for better or for worse](https://github.com/cblp/yaml-sucks), are defined in YAML - though you have the option to define them in JSON too. You can also define what OS each command should be executed on.

```yaml
# list_services.yml
---
schemaVersion: "2.2"
description: List out services running on hosts
mainSteps:
  - action: aws:runPowerShellScript
    name: ListServicesWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      runCommand:
        - Get-Service
  - action: aws:runShellScript
    name: ListServicesLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      runCommand:
        - ps -ef
```

Since a document is meant to perform an action on a group of instances regardless of their operating system (OS), only the steps that apply to the OS platform for the instance they are being applied to will run. TODO reword? Therefore when we target this document to run on two EC2 instances, one Windows and one Linux, the step `ListServicesWindows` will be executed on the Windows box and vice versa for `ListServicesLinux`. This is because of the `precondition` key we have that filters on the `platformType`. Notably as well, we are targeting the appropriate actions for each platform; `aws:runPowerShellScript` for Windows and `aws:runShellScript` for Linux.

> [See here](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html) for a full list of what actions you can perform in a command document.

Using Terraform you can deploy out the document to your environment like so.

```hcl
resource "aws_ssm_document" "list_services" {
  name            = "ListServices"
  document_type   = "Command"
  document_format = "YAML"

  content = file("list_services.yml")
}
```

Once deployed, we can navigate to System Manager in the AWS Console to trigger it.

TODO include screenshots on applying in the console

### Verbose command document

You may have a document which is much more verbose and has several more commands that need to be executed in it, and trying to read lines of code in amongst all that markup can be tedious. Here is a snippet of the **AWS-RunPatchBaseline** document which is written in JSON.

```json
{
  // ... 
  "mainSteps": [
    {
      "precondition": {
        "StringEquals": [
          "platformType",
          "Windows"
        ]
      },
      "action": "aws:runPowerShellScript",
      "name": "PatchWindows",
      "inputs": {
        "timeoutSeconds": 7200,
        "runCommand": [
          "# Check the OS version",
          "if ([Environment]::OSVersion.Version.Major -le 5) {",
          "    Write-Error 'This command is not supported on Windows 2003 or lower.'",
          "    exit -1",
          "} elseif ([Environment]::OSVersion.Version.Major -ge 10) {",
          "    $sku = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU",
          "    if ($sku -eq 143 -or $sku -eq 144) {",
          "        Write-Host 'This command is not supported on Windows 2016 Nano Server.'",
          "        exit -1",
          "    }",
          "}",
          "# Check the SSM agent version",
          "$ssmAgentService = Get-ItemProperty 'HKLM:SYSTEM\\CurrentControlSet\\Services\\AmazonSSMAgent\\'",
          "if (-not $ssmAgentService -or $ssmAgentService.Version -lt '2.0.533.0') {",
          "    Write-Host 'This command is not supported with SSM Agent version less than 2.0.533.0.'",
          "    exit -1",
          "}",
          "",
          // ... 
        ]
      }
    }
  ]
}
```

> You can see the [whole thing](https://eu-west-1.console.aws.amazon.com/systems-manager/documents/AWS-RunPatchBaseline/content) on AWS. 

We can see there's a lot going on here - if we wanted to make updates to the script we lose out on [syntax highlighting](https://en.wikipedia.org/wiki/Syntax_highlighting) which helps to improve code readability and type hinting.

We can avoid this by adopting a common pattern when composing command documents. We can externalise the script to execute outside of the document (by storing it in S3), then have the command perform these steps:

1. Download the script in question from S3
2. Execute the script from the download location

Such a command document would have a composition as below, for the same scenario provided previously.

```yaml
# list_services_verbose.yml
---
schemaVersion: "2.2"
description: List out services running on hosts
mainSteps:
  - action: aws:downloadContent
    name: DownloadScriptWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/script_bucket_location/ListServices.ps1"}'
      destinationPath: ListServices.ps1
  - action: aws:runPowerShellScript
    name: ExecuteListServicesScriptWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      runCommand:
        - ..\downloads\ListServices.ps1
  - action: aws:downloadContent
    name: DownloadScriptLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/script_bucket_location/list_services.sh"}'
      destinationPath: list_services.sh
  - action: aws:runShellScript
    name: ListServicesLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      runCommand:
        - ../downloads/list_services.sh
```

Note the additional action we've included called `aws:downloadContent` - which you can view the documentation for [here](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-downloadContent). Again we're using the `precondition` flag to filter what platform should be downloading what script. We're also using the `inputs` key to instruct the action where it can download the script from; in this case, from S3, at the given S3 location - finalised with a location to save it on the instance.

Once the script is downloaded to the instance, we will need to have it executed. `aws:downloadContent` actually saves the script to a temporary directory for executing SSM commands on instances, so we need to reference it in the `downloads` directory for it; indicated by the `../downloads/list_services.sh` command.

#### Terraform
 
This involves having your script first uploaded to S3. Thankfully, through the power of [infrastructure-as-code](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#infrastructure-as-code-primer), you can have this automatically deployed to your environment once the module is written. An example of this can be seen below.

```hcl
# First upload the scripts to S3
resource "aws_s3_bucket" "script_bucket" {
  bucket = "script-bucket"

  # ... removed for brevity
}

resource "aws_s3_bucket_object" "list_services_windows" {
  bucket  = aws_s3_bucket.script_bucket.id
  key     = "ssm_scripts/${local.linux_script_loc}"
  content = file("ListServices.ps1")
}

resource "aws_s3_bucket_object" "list_services_linux" {
  bucket  = aws_s3_bucket.script_bucket.id
  key     = "ssm_scripts/list_service.sh"
  content = file("list_service.sh")
}

resource "aws_ssm_document" "list_services" {
  name            = "ListServices"
  document_type   = "Command"
  document_format = "YAML"

  content = <<DOC
---
schemaVersion: "2.2"
description: List out services running on hosts
mainSteps:
  - action: aws:downloadContent
    name: DownloadScriptWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/${aws_s3_bucket.script_bucket.id}/${aws_s3_bucket_object.list_services_windows.id}"}'
      destinationPath: ListServices.ps1
  - action: aws:runPowerShellScript
    name: ExecuteListServicesScriptWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      runCommand:
        - ..\downloads\ListServices.ps1
  - action: aws:downloadContent
    name: DownloadScriptLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/${aws_s3_bucket.script_bucket.id}/${aws_s3_bucket_object.list_services_linux.id}"}'
      destinationPath: list_services.sh
  - action: aws:runShellScript
    name: ListServicesLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      runCommand:
        - ../downloads/list_services.sh
DOC
}
```

You'll notice the Terraform config for `aws_ssm_document.list_services` is different to the previous example, whereby we have the document contents listed directly in the resource itself instead of within a file. This allows us to make use of Terraform's [string interpolation](https://www.terraform.io/docs/configuration-0-11/interpolation.html) to infer the dependency `aws_ssm_document.list_services` has on the scripts (`aws_s3_bucket_object`), and to dynamically set the location of the scripts location in S3.

TODO iam roles will be needed on the instance to allow the script to be downloaded

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
