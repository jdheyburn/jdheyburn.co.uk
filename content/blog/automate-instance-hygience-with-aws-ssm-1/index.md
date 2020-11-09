---
date: 2020-11-12
title: "Automate Instance Hygiene with AWS SSM: Maintenance Windows"
description: Using SSM Maintenance Windows to automate SSM Documents
type: posts
series:
  - Automate Instance Hygiene with AWS SSM
tags:
  - aws
  - ssm
  - automation
  - terraform
  - patching
draft: true
---

[Last time](/blog/automate-instance-hygiene-with-aws-ssm-0/) we looked at writing our own SSM Command Document for the purpose of executing a healthcheck script on a set of EC2 instances across multiple platforms.

In this post we'll be exploring how we can automate this using maintenance windows - also within the SSM suite.

## Intro to Maintenance Windows

## Automating command documents with maintenance windows

So what's the purpose of all that we've done? Well we're not going to be manually invoking these command documents like what we have been doing so far - as engineers we need to be automating as many repetitive tasks as possible.

To summarise where we are now, we've produced a Command document which when executed, automates the following:

1. Downloads a healthcheck script from S3
2. Executes the healthcheck script, failing the command invocation if healthcheck does not pass

Healthchecks are important to run both continuously in our environment, as a means of monitoring and verifying the estate is working as intended, before your users notice. They are also necessary to run after a change has been introduced to the environment, such as a new code deployment, or even a patching event via the **AWS-RunPatchBaseline** document.

It's typical to use SSM Maintenance Windows to automate events in your AWS environment. You can even use it to execute **AWS-RunPatchBaseline**. This is something I've [covered before](/blog/using-terraform-to-manage-aws-patch-baselines-at-enterprise-scale/#ssm--patch-manager), but want to extend on that to show how its done.

### Barebones maintenance window with AWS-RunPatchBaseline

We're going to use Terraform again to build out a minimal maintenance window. You can view the code for it here TODO add link. A breakdown

```hcl
resource "aws_iam_role" "patch_mw_role" {
  name               = "PatchingMaintWindow"
  assume_role_policy = data.aws_iam_policy_document.patch_mw_role_assume.json
}

resource "aws_ssm_maintenance_window" "patch_window" {
  name              = "PatchInstances"
  schedule          = "cron(0 9 * * ? *)"
  schedule_timezone = "Europe/London"
  duration          = 4
  cutoff            = 1
}

resource "aws_ssm_maintenance_window_target" "patch_window_targets" {
  name          = "PatchInstanceTargets"
  window_id     = aws_ssm_maintenance_window.patch_window.id
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Terraform"
    values = ["true"]
  }
}

resource "aws_ssm_maintenance_window_task" "patch_instance" {
  name             = "PatchInstance"
  window_id        = aws_ssm_maintenance_window.patch_window.id
  service_role_arn = aws_iam_role.patch_mw_role.arn
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 10
  max_concurrency  = "100%"
  max_errors       = "0"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.patch_window_targets.id]
  }

  task_invocation_parameters {
    run_command_parameters {
        output_s3_bucket     = aws_s3_bucket.script_bucket.id
        output_s3_key_prefix = "ssm_output/"

      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}
```

These set of resources lay out the foundations of the maintenance window. In this example this window will be executed at 9am UK time every day.

We need to give it some instances to target, and we're doing this by specifying the tags of instances to include in the scope. Since our EC2 instances are already tagged with `Terraform = true`, this seems a good criteria to use.

> A more optimum tag to use would be `Patch Group` [described here](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-patch-patchgroups.html).

Lastly we need to give the window some tasks, since this is a barebones example we only want to specify a `RUN_COMMAND` type of **AWS-RunPatchBaseline**.

The task requires an IAM role for it to assume and execute the tasks, we'll also need to give it the appropriate permissions. There is a box-standard AWS policy we can utilise for this called [AmazonSSMMaintenanceWindowRole](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole$jsonEditor).

```hcl
data "aws_iam_policy_document" "patch_mw_role_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
        "ssm.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy" "ssm_maintenance_window" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

resource "aws_iam_role_policy_attachment" "patch_mw_role_attach" {
  role       = aws_iam_role.patch_mw_role.name
  policy_arn = data.aws_iam_policy.ssm_maintenance_window.arn
}
```

#### Logging command output to S3

Notice in the barebones example we're now logging the output of the commands to an S3 bucket. We do this because only the first 2500 characters of a command output are captured by default - if you wish to view any more then you need to set up your command job to output to either S3 or CloudWatch (currently only S3 is supported for maintenance windows). You'll notice we are using the same S3 bucket that is storing our scripts from earlier, whereby we are using the S3 prefix `ssm_output/`.

In order to set this up, we need to set up the following IAM permissions:

1. The S3 bucket policy needs to permit instance role `aws_iam_role.vm_base` to `s3:PutObject` on `"${aws_s3_bucket.script_bucket.arn}/ssm_output/*"`
2. The KMS key used to encrypt objects in the target S3 bucket needs to permit instance role `aws_iam_role.vm_base` to `kms:GenerateDataKey`
3. The instance role `aws_iam_role.vm_base` needs permissions to do the above on its respective side

To accomplish this we will need to add the following statements to each of their respective `aws_iam_policy_documents`

1.

```hcl
data "aws_iam_policy_document" "s3_allow_script_download" {
  # ...

  statement {
    sid    = "AllowS3Put"
    effect = "Allow"

    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.vm_base.arn]
    }

    resources = ["${aws_s3_bucket.script_bucket.arn}/ssm_output/*"]
  }
}
```

2.

```hcl
data "aws_iam_policy_document" "kms_allow_decrypt" {
  # ...

  statement {
    sid    = "AllowGenerateDataKey"
    effect = "Allow"

    actions = [
      "kms:GenerateDataKey",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.vm_base.arn]
    }

    resources = ["*"]
  }
```

3.

```hcl
data "aws_iam_policy_document" "ssm_scripts" {
  # ...

  statement {
    sid    = "AllowS3Put"
    effect = "Allow"

    actions = ["s3:PutObject"]

    resources = [
      "${aws_s3_bucket.script_bucket.arn}/ssm_output/*",
    ]
  }

  statement {
    sid    = "AllowKMS"
    effect = "Allow"

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt",
      ]

    resources = [aws_kms_key.script_bucket_key.arn]
  }
}
```

TODO update policy document resource names with their new names (find better names for them)

- Healthchecks are typically useful for executing after a change in our environment.
- Remember back to last time we spoke about SSM, we were covering aws-runpatchbaseline
- it is a best practice to perform a healthcheck on the instance after a patch event

TODO

- intro to MW if not done already
- how to create MW
- IAM roles and permissions

- have only one executed at a time? throw a failure and discontinue if there is one?
- afterward, how to log out command output

TODO link MW from previous post to this page
