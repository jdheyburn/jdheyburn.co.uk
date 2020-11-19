---
date: 2020-11-24
title: "Automate Instance Hygiene with AWS SSM: Automation Documents"
description: TBC
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

Structure:

Recap on what we've done

Intro to automation docs
- add that they can be used to combined command documents
- why do this? rate limiting (1 instance at a time)
- having two maintenance window tasks means you cannot perform the tasks synchronously one at a time on instances
- therefore automation doucments help us to piece command documents together
- beyond this, they can also be used to 


Prerequisites
- where to follow along, link the code here
- mention the folder restructure (either in here or in tldr?)
  - and the new architecture, ALB in front of 3 nodes

Automation doc combining the two
- whats different about what we have so far (new yaml format)
- show how to test in create automation
  - then with rate limiting
  - indicate max errors, and throw an error to test out rate limiting
- then show how to include it in a MW
  - show a good run
  - then show a bad run, highlight that max errors is differnet to executing automation, because it is written by different teams


Extend the doc to gracefully take the nodes out of rotation from the ALB
- the one that requires the target group arn being passed in



Bonus: 
- Improve the automation doc so that you can pass in whatever document you like to invoke it (i.e. a maintenance command wrapper)
- Improve the automation doc so that you do not have to specify the target groups for that instnace
  - it should just dynamically look it up



## Automation documents

So now we have a command document that gets services that are currently running on the instance, what if we wanted to have this script executed after a patching event - so that we can confirm services are running fine?

In the simplest form, the automation document would look something like this:

```yaml
---
schemaVersion: "0.3"
description: Patch an instance then check instances are running OK
parameters:
  InstanceIds:
    type: StringList
    description: The instance to target
mainSteps:
  - name: PatchInstance
    action: "aws:runCommand"
    inputs:
      DocumentName: AWS-RunPatchBaseline
      InstanceIds: "{{InstanceIds}}"
      OutputS3BucketName: script-bucket
      OutputS3KeyPrefix: ssm_output/
      ServiceRoleArn: >-
        arn:aws:iam::ACCOUNT_ID:role/system/ROLE_NAME
      TimeoutSeconds: 3600
      Parameters:
        Operation: Install
  - name: CheckInstancesPostPatch
    action: "aws:runCommand"
    inputs:
      DocumentName: ListServices
      InstanceIds: "{{InstanceIds}}"
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
