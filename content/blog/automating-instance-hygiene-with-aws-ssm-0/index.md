---
date: 2020-10-21
title: "Automating Instance Hygiene with AWS SSM: Command Documents"
description: Exploring how AWS SSM can help to automate processes to keep instances healthy
type: posts
series:
  - Automating Instance Hygiene with AWS SSM
tags:
  - aws
  - ssm
  - automation
  - patching
draft: true
---

It's been a while since my [last post](/blog/assertions-in-gotests-test-generation/)... which could be down to me trying to salvage something out of summer! :sweat_smile:

In this post I want to talk a little bit more about AWS SSM. This was something I touched on when discussing patch baselines in a [previous post](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager), and within there is another service known as [Automation](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-automation.html). On first glance it may look pretty dull, but once you scratch the surface there are a number of capabilities it can unlock for you. I found a distinct lack of resources on how to write these documents, so this post will aim to help you get started on doing so!

This will be part one of a three part series about SSM Automation. The outline of the posts will be:

1. Re-introduction to SSM Documents in general, specifically the `Command` document
2. Moving onto `Automation` documents
3. Advanced use case for `Automation` documents

> I had planned for them all to be in one post... but decided to do individual posts for a deeper dive into each of them.

## Pre-requisites

This series assumes you have some knowledge of:

- Terraform
- These AWS services:
  - EC2
  - IAM
  - S3

All source code for this post is available on [GitHub](https://github.com/jdheyburn/terraform-examples/aws-ssm-automation-1), I'll be referencing it throughout.

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

There are also [other types](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html) too which are beyond the scope of this series.

### SSM Managed Instances

In order to have scripts executed remotely on your instances, they will need to become [managed instances](https://docs.aws.amazon.com/systems-manager/latest/userguide/managed_instances.html). This requires having the below set up correctly:

- the [SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) installed on your instance
  - done so by default on all Amazon Linux AMIs and Windows AMIs
- connectivity from your instances to the [following endpoints](https://docs.aws.amazon.com/general/latest/gr/ssm.html):
  - `https://ssm.REGION.amazonaws.com`
  - `https://ssmmessages.REGION.amazonaws.com`
  - `https://ec2messages.REGION.amazonaws.com`
- the [correct IAM permissions](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html) to interface with SSM
  - this are all provided by the AWS IAM policy [AmazonSSMManagedInstanceCore](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore$serviceLevelSummary)
  - the example for this post shows the [policy being attached](https://github.com/jdheyburn/terraform-examples/aws-ssm-automation-1/ec2_iam.tf) to the EC2 IAM role

If your instances are appearing in the [managed instances console](https://console.aws.amazon.com/systems-manager/managed-instances) then everything is set up correctly; if not then follow the [troubleshooting guide](https://aws.amazon.com/premiumsupport/knowledge-center/systems-manager-ec2-instance-not-appear/).

TODO screenshot

## Command documents

Documents are defined in either JSON or, [for better or for worse](https://github.com/cblp/yaml-sucks), YAML. You can also define what OS each command should be executed on. This could be helpful if you wanted a healthcheck script to be executed across all (or a subset of) your instances in one swoop. As an example, my healthcheck script could be to check to see if the CPU is overloaded.

### Constructing a healthcheck script

I could use the below to perform a healthcheck on a Windows box:

```powershell
$Avg = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select Average).Average
If ($Avg -gt 90) {
  Throw "Instance is unhealthy - Windows"
}
Write-Output "Instance is healthy - Windows"
```

And the equivalent for Linux would be:

```bash
# Sources:
# https://stackoverflow.com/a/9229580
# https://bits.mdminhazulhaque.io/linux/round-number-in-bash-script.html
avg_cpu=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)+1}')
if (( avg_cpu > 90 )); then
  echo "Instance is unhealthy - Linux"
  exit 1
fi
echo "Instance is healthy - Linux"
```

> You'll notice the scripts output the OS they are running on - this will serve as an explanation for when we run the scripts as a command document later on.

Note these scripts are just rudimentary examples of healthcheck scripts. Your healthcheck script may be checking that services are running ok, whether a task can be performed, etc. For the sake of this example, I've decided to do a simple check against the CPU load for demonstration.

### Testing in AWS SSM Console

Let's now test them in the AWS SSM Console. For this example I've spun up two EC2 instances, one Linux and one Windows, [using Terraform](https://github.com/jdheyburn/terraform-examples/aws-ssm-automation-1). To run the commands we can navigate to [this URL](https://console.aws.amazon.com/systems-manager/run-command/send-command), and running `AWS-RunPowerShellScript` and `AWS-RunShellScript` for both Windows and Linux EC2s respectively. We don't care about logging the output of the scripts just yet.

TODO screenshot of happy case

We can see they have executed fine. Let's flip the condition so we can test them failing.

TODO screenshot of bad case

This is cool - in the script we can define what constitutes as a failure and have this propagate up to AWS. This will come in use later on in the post.

### Terraforming command documents

Now let's get these scripts Terraformed so we can reap the [benefits](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#infrastructure-as-code-primer) of infrastructure-as-code. First we need to define the document in the YAML format.

```yaml
# documents/perform_healthcheck.yml
---
schemaVersion: "2.2"
description: Perform a healthcheck on the target instance
mainSteps:
  - name: PerformHealthCheckWindows
    action: aws:runPowerShellScript
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      runCommand:
        - "$Avg = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select Average).Average"
        - "If ($Avg -gt 90) {"
        - '  Throw "Instance is unhealthy- Linux"'
        - "}"
        - 'Write-Output "Instance is healthy - Windows"'
  - name: PerformHealthCheckLinux
    action: aws:runShellScript
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      runCommand:
        - "avg_cpu=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)+1}')"
        - "if (( avg_cpu > 90 )); then"
        - '  echo "Instance is unhealthy - Linux"'
        - "  exit 1"
        - "fi"
        - 'echo "Instance is healthy - Linux"'
```

Since a document is meant to perform an action (or group of actions) on a set of instances regardless of their operating system (OS), only the steps that apply to the OS platform for the instance they are being executed on will be invoked.

Therefore when we target this document to run on two EC2 instances, one Windows and one Linux, the step `PerformHealthCheckWindows` will be executed on the Windows box and vice versa for `PerformHealthCheckLinux`. This is because of the `precondition` key which filters on the `platformType`. Notably as well, we are targeting the appropriate actions for each platform; `aws:runPowerShellScript` for Windows and `aws:runShellScript` for Linux.

> [See here](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html) for a full list of what actions you can perform in a command document.

Using Terraform you can deploy out the document to your environment like so.

```hcl
resource "aws_ssm_document" "perform_healthcheck" {
  name            = "PerformHealthcheck"
  document_type   = "Command"
  document_format = "YAML"

  content = file("documents/perform_healthcheck.yml")
}
```

Once deployed, we can navigate to System Manager in the AWS Console to trigger it.

TODO include screenshots on applying in the console

We can see that both executed successfully! Let's dive into some more intermediate documents.

### Verbose command documents

The example above was a very basic example of such a document where we only had a few lines of code to execute. The healthcheck script you write for your service may have several more lines of code to execute,and trying to read lines of code in amongst the document markup format can be tedious. Here is a snippet of the **AWS-RunPatchBaseline** document, written in JSON, which has over 100 lines in the `runCommand` section.

```json
{
  // ...
  "mainSteps": [
    {
      "precondition": {
        "StringEquals": ["platformType", "Windows"]
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
          ""
          // ...
        ]
      }
    }
  ]
}
```

> You can see the [whole thing](https://console.aws.amazon.com/systems-manager/documents/AWS-RunPatchBaseline/content) on AWS.

Even from this snippet it is hard to distinguish what is going on. Losing out on [syntax highlighting](https://en.wikipedia.org/wiki/Syntax_highlighting) means the code is readable by any means, and since this is a JSON file format, we lose type hinting for the language we are writing the script in (PowerShell in this case).

We can fix all these issues by adopting a common pattern when composing command documents. We can have S3 store the script, then have the command document perform these actions:

1. Download the script in question from S3
2. Execute the script from the download location

Such a command document would have a composition as below, for the same scenario provided previously.

```yaml
# documents/perform_healthcheck_s3.yml
---
schemaVersion: "2.2"
description: Perform a healthcheck on the target instance
mainSteps:
  - action: aws:downloadContent
    name: DownloadScriptWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/jdheyburn-scripts/ssm_scripts/PerformHealthcheck.ps1"}'
      destinationPath: PerformHealthcheck.ps1
  - action: aws:runPowerShellScript
    name: ExecutePerformHealthCheckWindows
    precondition:
      StringEquals:
        - platformType
        - Windows
    inputs:
      runCommand:
        - ..\downloads\PerformHealthcheck.ps1
  - action: aws:downloadContent
    name: DownloadScriptLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      sourceType: S3
      sourceInfo: '{"path":"https://s3.amazonaws.com/jdheyburn-scripts/ssm_scripts/perform_healthcheck.sh"}'
      destinationPath: perform_healthcheck.sh
  - action: aws:runShellScript
    name: ExecutePerformHealthCheckLinux
    precondition:
      StringEquals:
        - platformType
        - Linux
    inputs:
      runCommand:
        - ../downloads/perform_healthcheck.sh
```

Note the new action called `aws:downloadContent` - which you can view the documentation for [here](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-plugins.html#aws-downloadContent). Again we're using the `precondition` key to ensure each platforms downloads their respective script. We're also using the `inputs` key to instruct the action where it can download the script from; in this case, from S3, at the given S3 location - finalised with a location to save it on the instance.

Once the script is downloaded to the instance, we will need to have it executed. `aws:downloadContent` actually saves the script to a temporary directory for executing SSM commands on instances, so we need to reference it in the `downloads` directory for it; indicated by the `../downloads/perform_healthcheck.sh` command.

#### Terraforming verbose command documents

This involves having your script first uploaded to S3. Thankfully, through the power of [infrastructure-as-code](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#infrastructure-as-code-primer), you can have this automatically deployed to your environment once the module is written. An example of this can be seen below.

TODO up to here

```hcl
resource "aws_kms_key" "script_bucket_key" {
  description = "This key is used to encrypt bucket objects"
}

resource "aws_s3_bucket" "script_bucket" {
  bucket = "jdheyburn-scripts"

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

resource "aws_s3_bucket_object" "per_windows" {
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

## Maintenance Windows executing command documents

Optional additional heading?
