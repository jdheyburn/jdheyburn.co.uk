---
date: 2020-09-26
title: "Using SSM Automation "
description: WIP
type: posts
tags:
  - aws
  - ssm
  - automation
draft: true
---

It's been a while since my [last post](/blog/assertions-in-gotests-test-generation/)... which could be down to me trying to salvage something out of summer! :sweat_smile:

In this post I want to talk a little bit more about AWS SSM. This was something I touched on when discussing patch baselines in a [previous post](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager), and within there is another service known as [Automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html). On first glance it may look pretty dull, but once you scratch the surface there are a number of capabilities it can unlock for you. I found a distinct lack of resources on how to write these documents, so this post will aim to help you get started on doing so!

## SSM Re-primer

I've mentioned [SSM Documents](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager) before; to save you a click:

> An [SSM Document](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) is essentially an automation script that you can perform on one or more instances at a time, with conditions to apply different sets of scripts depending on the operating system (OS) platform (i.e. Windows / Linux).

In that post I talk about how **AWS-RunPatchBaseline** is an example of a `COMMAND` document. Another type of document is known as `AUTOMATION`. AWS [describes them](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) as:

- Command
  - uses command documents to run commands
  - State Manager uses command documents to apply a configuration
  - These actions can be run on one or more targets at any point during the lifecycle of an instance
  - Maintenance Windows uses command documents to apply a configuration based on the specified schedule
- Automation
  - Use automation documents when performing common maintenance and deployment tasks such as creating or updating an Amazon Machine Image (AMI)
  - State Manager uses automation documents to apply a configuration
  - These actions can be run on one or more targets at any point during the lifecycle of an instance
  - Maintenance Windows uses automation documents to perform common maintenance and deployment tasks based on the specified schedule

I like to use the below to differentiate between the two:

- Command documents are ran on instances themselves
- Automation document can call and orchestrate AWS API endpoints on your behalf, including executing Command documents on instances

There are also [other types](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) too which are beyond the scope of this post.

## Command documents

Documents are defined in either JSON or, [for better or for worse](https://github.com/cblp/yaml-sucks), YAML. You can also define what OS each command should be executed on. Check out this basic example below, which will list running processes on instances  :point_down:

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

Since a document is meant to perform an action (or group of actions) on a set of instances regardless of their operating system (OS), only the steps that apply to the OS platform for the instance they are being executed on will be invoked.

Therefore when we target this document to run on two EC2 instances, one Windows and one Linux, the step `ListServicesWindows` will be executed on the Windows box and vice versa for `ListServicesLinux`. This is because of the `precondition` key which filters on the `platformType`. Notably as well, we are targeting the appropriate actions for each platform; `aws:runPowerShellScript` for Windows and `aws:runShellScript` for Linux.

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

### Verbose command documents

The example above was a very basic example of such a document where we only had one line of command to execute. However you may have a document which is much more verbose and has several lines of code that need to be executed, and trying to read lines of code in amongst all that markup can be tedious. Here is a snippet of the **AWS-RunPatchBaseline** document which is written in JSON.

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

> You can see the [whole thing](https://console.aws.amazon.com/systems-manager/documents/AWS-RunPatchBaseline/content) on AWS. 

We can see there's a lot going on here - if we wanted to make updates to the script we lose out on [syntax highlighting](https://en.wikipedia.org/wiki/Syntax_highlighting) which helps to improve code readability and type hinting.

We can fix all these issues by adopting a common pattern when composing command documents. We can externalise the script to execute outside of the document by storing it in S3, then have the command perform these steps:

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
      sourceInfo: '{"path":"https://s3.amazonaws.com/script-bucket/ssm_scripts/ListServices.ps1"}'
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
      sourceInfo: '{"path":"https://s3.amazonaws.com/script-bucket/ssm_scripts/list_services.sh"}'
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

Note the additional action we've included called `aws:downloadContent` - which you can view the documentation for [here](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-downloadContent). Again we're using the `precondition` key to ensure each platforms downloads their respective script. We're also using the `inputs` key to instruct the action where it can download the script from; in this case, from S3, at the given S3 location - finalised with a location to save it on the instance.

Once the script is downloaded to the instance, we will need to have it executed. `aws:downloadContent` actually saves the script to a temporary directory for executing SSM commands on instances, so we need to reference it in the `downloads` directory for it; indicated by the `../downloads/list_services.sh` command.

#### Terraforming verbose command documents
 
This involves having your script first uploaded to S3. Thankfully, through the power of [infrastructure-as-code](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#infrastructure-as-code-primer), you can have this automatically deployed to your environment once the module is written. An example of this can be seen below.

```hcl
resource "aws_kms_key" "script_bucket_key" {
  description = "This key is used to encrypt bucket objects"
}

resource "aws_s3_bucket" "script_bucket" {
  bucket = "script-bucket"

  # Encrypt objects stored in S3
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.script_bucket_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_object" "list_services_windows" {
  bucket  = aws_s3_bucket.script_bucket.id
  key     = "ssm_scripts/ListServices.ps1"
  content = file("ListServices.ps1") # Ensure the script exists at this location
}

resource "aws_s3_bucket_object" "list_services_linux" {
  bucket  = aws_s3_bucket.script_bucket.id
  key     = "ssm_scripts/list_service.sh"
  content = file("list_service.sh") # Ensure the script exists at this location
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

For the pattern to work, you'll need to attach an IAM policy to the instance to allow it to pull the scripts from the S3 bucket. The JSON for this would look like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3Get",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::script-bucket/ssm_scripts/*"
    },
    {
      "Sid": "AllowKMS",
      "Effect": "Allow",
      "Action": ["kms:Decrypt"],
      "Resource": "arn:aws:kms:REGION:ACCOUNT_ID:key/KMS_ID"
    }
  ]
}
```

> You can read up more about IAM policies [here](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).

If you have an encryption policy set on the S3 bucket (you **should** have one if you don't - the example above shows how to do this in Terraform), you'll need to give the instance permission to decrypt the S3 objects using the same KMS key used to encrypt them with - this is what the statement `AllowKMS` is permitting in the policy.

Once again, we can have Terraform configure all of this for us:

```hcl
data "aws_iam_policy_document" "ssm_scripts" {
  statement {
    sid = "AllowS3"
    effect = "Allow"

    actions = ["s3:GetObject"]

    resources = ["${aws_s3_bucket.script_bucket.arn}/ssm_scripts/*"]
  }

  statement {
    sid = "AllowKMS"
    effect = "Allow"

    actions = ["kms:Decrypt"]

    resources = [aws_kms_key.script_bucket_key.arn]
  }
}

resource "aws_iam_policy" "ssm_scripts" {
  name        = "PullSSMScripts"
  description = "Enables instances to download SSM scripts from S3"

  policy = data.aws_iam_policy_document.ssm_scripts.json
}

resource "aws_iam_role_policy_attachment" "instance_download_scripts" {
  # Assuming the role below already exists for your EC2 instances
  role       = aws_iam_role.ec2_instance_role.arn
  policy_arn = aws_iam_policy.ssm_scripts.arn
}
```

Once done, you'll need to attach the IAM policy to the IAM role that your EC2 instance is assuming. 

TODO ssm console for triggering the above

After that, you'll have adopted a means of executing command documents on your EC2 instances!

## Automation documents

So now we have a command document that gets services that are currently running on the instance, what if we wanted to have this script executed after a patching event - so that we can confirm services are running fine?

In the simplest form, the automation document would look something like this:

```yaml
---
schemaVersion: '0.3'
description: Patch an instance then check instances are running OK
parameters:
  InstanceIds:
    type: StringList
    description: The instance to target
mainSteps:
  - name: PatchInstance
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPatchBaseline
      InstanceIds: '{{InstanceIds}}'
      OutputS3BucketName: script-bucket
      OutputS3KeyPrefix: ssm_output/
      ServiceRoleArn: >-
        arn:aws:iam::ACCOUNT_ID:role/system/ROLE_NAME
      TimeoutSeconds: 3600
      Parameters:
        Operation: Install
  - name: CheckInstancesPostPatch
    action: 'aws:runCommand'
    inputs:
      DocumentName: ListServices
      InstanceIds: '{{InstanceIds}}'
      OutputS3BucketName: script-bucket
      OutputS3KeyPrefix: ssm_output/
      ServiceRoleArn: >-
        arn:aws:iam::ACCOUNT_ID:role/system/ROLE_NAME
      TimeoutSeconds: 3600
```

On the face of it there is not a whole lot of difference here between this automation and the command documents. Some of the similarties include:

- `schemaVersion`
- `description`
- `mainSteps`, containing:
  - `name`
  - `action`
  - `inputs` for the `action`

Something new in this automation document is `parameters`. This allows the executor of this document to specify parameters that can be passed into the input of the steps. For now, AWS will recognise the `InstanceIds` name and provide some GUI assistance, which I'll touch on later.

### Steps breakdown

This document is made up of two steps, one is calling **AWS-RunPatchBaseline**, while the next one is calling the command document we made in the previous section, **ListServices**. In both steps we're specifying the action to be `aws:runCommand`. To understand further about the inputs we're providing to the action, see the [AWS documentation](https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-action-runcommand.html).

You will notice the line containing `InstanceIds: '{{InstanceIds}}'`. The curly braces (`{{`) indicate to the document that we want to reference the parameter named that value at the start of the document. This is how we pass what instances we want to have the document executed on.

Additionally we have `OutputS3BucketName` and `OutputS3KeyPrefix` specified in the inputs, this allows us to tell the command document where to store the output of the commands being executed in case we want to debug them for later on.

If the command document you are executing takes in parameters of its own like **AWS-RunPatchBaseline**, then you can enter a `Parameters` key like what we're doing above.

Just this document alone isn't needed, we need to create some other resources too to piece everything together.

### Terraforming automation document

Just like with the command document, we can Terraform this in a similar manner. Note the differing `document_type`.

```hcl
resource "aws_ssm_document" "patch_instance_with_healthcheck" {
  name            = "PatchInstanceWithHealthcheck"
  document_type   = "Automation"
  document_format = "YAML"

  content = <<DOC
---
schemaVersion: '0.3'
description: Patch an instance then check instances are running OK
parameters:
  InstanceIds:
    type: StringList
    description: The instance to target
mainSteps:
  - name: PatchInstance
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunPatchBaseline
      InstanceIds: '{{InstanceIds}}'
      OutputS3BucketName: ${aws_s3_bucket.script_bucket.id}
      OutputS3KeyPrefix: ssm_output/
      ServiceRoleArn: >-
        ${aws_iam_role.automation.arn}
      TimeoutSeconds: 3600
      Parameters:
        Operation: Install
  - name: CheckInstancesPostPatch
    action: 'aws:runCommand'
    inputs:
      DocumentName: '${aws_ssm_document.list_services.arn}'
      InstanceIds: '{{InstanceIds}}'
      OutputS3BucketName: ${aws_s3_bucket.script_bucket.id}
      OutputS3KeyPrefix: ssm_output/
      ServiceRoleArn: >-
        ${aws_iam_role.automation.arn}
      TimeoutSeconds: 3600
DOC
}
```

You'll notice we're referencing the `aws_s3_bucket.script_bucket` resource, we're going to reuse this bucket to store the output of the commands, at the prefix `ssm_output/`.

> Read up more [about S3](https://docs.aws.amazon.com/AmazonS3/latest/gsg/GetStartedWithS3.html), and about [S3 prefixes](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/using-folders.html).

There is also another resource referenced here called `aws_iam_role.automation`. This is the role that SSM will assume to execute this command. We didn't need to specify this when we were executing our command document earlier because AWS Console uses your permissions when logged in to execute the command. In most cases your permissions would include `AdministratorAccess`, which is God-like powers on everything. Since we are automating this document, we need to tell it what role it can use to perform the tasks as.

To Terraform that, this is what is needed:

```hcl
resource "aws_iam_role" "automation" {
  name = "Automation"
  assume_role_policy = data.aws_iam_policy_document.automation_assume_policy.json
}

data "aws_iam_policy_document" "automation_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
        "ssm.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "automation_policy" {
  statement {
    sid    = "AllowSSM"
    effect = "Allow"

    actions = [
      "ssm:DescribeInstanceInformation",
      "ssm:ListCommandInvocations",
    ]

    resources = ["*"]
  }

  statement {
    sid     = "AllowIAM"
    effect  = "Allow"
    actions = ["iam:PassRole"]

    resources = [
      aws_iam_role.automation.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "automation_policy" {
  name   = "AutomationPolicy"
  policy = data.aws_iam_policy_document.automation_policy.json
}

resource "aws_iam_role_policy_attachment" "automation_policy" {
  role       = aws_iam_role.automation.name
  policy_arn = aws_iam_policy.automation_policy.arn
}
```

> Describing the semantics of IAM permissions is out of scope for this post. You can check the [AWS docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html) for more info.

There is a lot going on here, but rest assured it is everything that is needed for the automation document to run.

We will need to also provide permissions for the EC2 instances to be able to upload the output of the command documents to S3.

```hcl
data "aws_iam_policy_document" "ssm_commands_output" {
  statement {
    sid = "AllowS3"
    effect = "Allow"

    actions = ["s3:PutObject"]

    resources = ["${aws_s3_bucket.script_bucket.arn}/ssm_output/*"]
  }

  statement {
    sid = "AllowKMS"
    effect = "Allow"

    actions = ["kms:GenerateDataKey"]

    resources = [aws_kms_key.script_bucket_key.arn]
  }
}

resource "aws_iam_policy" "ssm_commands_output_upload" {
  name        = "SSMCommandsOutputUpload"
  description = "Enables instances to upload output of SSM commands to S3"

  policy = data.aws_iam_policy_document.ssm_commands_output.json
}

resource "aws_iam_role_policy_attachment" "instance_upload_ssm_output_to_s3" {
  # Assuming the role below already exists for your EC2 instances
  role       = aws_iam_role.ec2_instance_role.arn
  policy_arn = aws_iam_policy.ssm_commands_output_upload.arn
}
```

### Executing the automation

Similarly to the command document, we can trigger the automation document via the AWS Console.

TODO add screenshots of this.

### Attaching automation to maintenance window

Now we can modify our patching maintenance window (TODO where to reference?) to use the new automation document we created instead.

TODO show updated mw and show this running in a screenshot

- Highlight the issue of it executing on multiple instances all at once

### Executing one instance at a time

We can then do some cool stuff with maintenance window properties, such as ensuring only one instances is being patched at a time, and to abort any further patching if the automation document failed for whatever reason (such as a bad healthcheck post-patching).

TODO show this config

Note that you can replicate this behaviour in the AWS Console should you want to test your Automation document outside of a maintenance window.

TODO show the automation rate control example in Execute Automation SSM bit, then talk about how users can get set up on that

## Proactively removing instances from circulation

The previous examples have been pretty basic thus far - only calling run commands that we have written ourselves.

- Talk about how we are not proactively removing nodes from circulation
- Could disrupt user experience
- need to remove the instance from the target group first
