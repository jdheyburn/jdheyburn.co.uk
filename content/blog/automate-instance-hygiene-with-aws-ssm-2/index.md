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

In [part two]() of this [series]() we look at how we can automate SSM command documents using SSM Maintenance Windows.

This part will now explore another type of SSM Document; Automation.

## Prerequisites

All the code for this post can be found on [Github]().

You'll notice that we have changed some things around in this post, so if you've been using `terraform apply` in other posts to deploy to your AWS environment, you will notice some destructions.

TODO add architecture of this post (ALB in front of 3 nodes)

## Automation Documents

Back in [part one]() I gave a brief intro to automation documents. To save the click:

> Automation document can call and orchestrate AWS API endpoints on your behalf, including executing Command documents on instances

Essentially we can combine two command documents into one with an automation document. But why would we want to do this?

### Introducing proactive healthchecks

Well in the last post, we set up a maintenance window with two tasks; one for invoking **AWS-RunPatchBaseline** and another for **PerformHealthcheckS3** (our healthcheck SSM Document) - both of these are _command documents_. Say if we had a policy that wanted to ensure that after **AWS-RunPatchBaseline** was invoked, we would _always_ want the **PerformHealthcheckS3** invoked afterward... the Automation Document would help us get there.

Not only that, the way that our maintenance window is currently structured is it will invoke **AWS-RunPatchBaseline** across all instances in scope at the same time. Once they are all done then it will invoke **PerformHealthcheckS3** across all instances at the same time. This looks like this:

```
Given we have 2 instances; i-111, i-222
T+0: Invoke AWS-RunPatchBaseline on i-111, i-222
T+1: AWS-RunPatchBaseline finishes: i-111, i-222
T+2: Invoke PerformHealthcheckS3 on i-111, i-222
T+3: PerformHealthcheckS3 finishes: i-111, i-222
```

Say if you wanted to limit the rate of patching across these instances so that only one instance at a time was patched, and any healthcheck failures aborted the rest of patching, then simply changing `max_concurrency` from `100%` to `1` for each maintenance window task _will not achieve this_.

Maintenance windows complete one task across all instances in scope before moving onto the next task. If we have Task 1 for Patching and Task 2 for Healthchecking (is that even a word?), then the maintenance window is going to patch **all** instances first before it performs healthchecks on the instances. There is no way to execute the tasks synchronously on one instance at a time.

This means that if a bad patch were to be installed in your estate, you could have this order of events:

```
Given we have 2 instances; i-111, i-222
T+0: Invoke AWS-RunPatchBaseline on i-111
T+1: AWS-RunPatchBaseline finishes: i-111
T+2: Invoke AWS-RunPatchBaseline on i-222
T+3: AWS-RunPatchBaseline finishes: i-222
T+4: Invoke PerformHealthcheckS3 on i-111
T+5: PerformHealthcheckS3 FAILS: i-111
T+6: Invoke PerformHealthcheckS3 on i-222
T+7: PerformHealthcheckS3 FAILS: i-222
```

Now the healthcheck has failed for `i-222` as well because the bad patch landed on both instances, and production now has an outage.

Thankfully, Automation Documents help us avoid that - by combining the two command documents (AWS-RunPatchBaseline and PerformHealthcheckS3), we can mark this new automation document as a _solo maintenance window task_ and have it invoked one at a time on instances, and have it abort further invocations if any sub-documents failed within in:

```
Given we have 2 instances; i-111, i-222
T+0: Invoke AWS-RunPatchBaseline on i-111
T+1: AWS-RunPatchBaseline finishes: i-111
T+2: Invoke PerformHealthcheckS3 on i-111
T+3: PerformHealthcheckS3 FAILS: i-111
T+4: Abort invoking AWS-RunPatchBaseline on i-222
T+5: Abort invoking PerformHealthcheckS3 on i-222
```

Notice how the failed healthcheck on the first instance caused the rest of task invocations to abort? Here is the order of events for a happy path.

```
Given we have 2 instances; i-111, i-222
T+0: Invoke AWS-RunPatchBaseline on i-111
T+1: AWS-RunPatchBaseline finishes: i-111
T+2: Invoke PerformHealthcheckS3 on i-111
T+3: PerformHealthcheckS3 succeeds: i-111
T+4: Invoke AWS-RunPatchBaseline on i-222
T+5: AWS-RunPatchBaseline finishes: i-222
T+6: Invoke PerformHealthcheckS3 on i-222
T+7: PerformHealthcheckS3 succeeds: i-222
```

### Additional automation actions

So we know that automation documents allow us to combine command documents together - this is done using the `aws:runCommand` action, though there are [many more](https://docs.aws.amazon.com/systems-manager/latest/userguide/automation-actions.html) actions available to you, some of which we'll explore later.

## Combining command docs into automation

We combine command documents as below in YAML; like command documents they can also be defined in JSON.

For the first time we are defining a parameter called `InstanceIds`, which takes in a list of instance IDs to then pass down to the command documents, as they will need to know what instances to invoke the commands on. The value assigned to this parameter is retrieved back with the notation `"{{ InstanceIds }}"`, which you can see being passed into the inputs of the sub-documents.

We're also following logging best practices by having the command output logged to S3.

Other than that, there's not really a whole lot of difference between this and a command document, so far!

> It's important to note the `schemaVersion` must be `0.3` for automation documents.

```yaml
---
schemaVersion: "0.3"
description: Executes a patching event on the instance followed by a healthcheck
parameters:
  InstanceIds:
    type: StringList
    description: The instance to target
mainSteps:
  - name: InvokePatchEvent
    action: aws:runCommand
    inputs:
      DocumentName: AWS-RunPatchBaseline
      InstanceIds: "{{ InstanceIds }}"
      OutputS3BucketName: jdheyburn-scripts
      OutputS3KeyPrefix: ssm_output/
      Parameters:
        Operation: Scan
  - name: ExecuteHealthcheck
    action: aws:runCommand
    inputs:
      DocumentName: PerformHealthcheckS3
      InstanceIds: "{{ InstanceIds }}"
      OutputS3BucketName: jdheyburn-scripts
      OutputS3KeyPrefix: ssm_output/
```

### Terraform automation documents

We can deploy these to AWS using Terraform once again. Note that the `document_type` is `Automation` and that we're using templating to set the variables in the document, such as referencing the PerformHealthcheckS3 command document ARN.

You can see the templated version of the document in Github TODO add link.

```hcl
resource "aws_ssm_document" "patch_with_healthcheck" {
  name            = "PatchWithHealthcheck"
  document_type   = "Automation"
  document_format = "YAML"

  content = templatefile(
    "documents/patch_with_healthcheck_template.yml",
    {
      healthcheck_document_arn = aws_ssm_document.perform_healthcheck_s3.arn,
      output_s3_bucket_name    = aws_s3_bucket.script_bucket.id,
      output_s3_key_prefix     = "ssm_output/",
    }
  )
}
```

### Testing automation documents

Now let's go and test this by manually invoking it. This can be done by navigating to [Automation](https://console.aws.amazon.com/systems-manager/automation/executions) within Systems Manager and clicking [Execute Automation](https://console.aws.amazon.com/systems-manager/automation/execute).

> For a shortcut of invoking the commands, you can use the below command to invoke the below CLI command. Then you may skip to [the results](#results).

```bash
aws ssm start-automation-execution \
  --document-name "PatchWithHealthcheck" \
  --document-version "\$DEFAULT" \
  --target-parameter-name InstanceIds \
  --max-errors "0" \
  --max-concurrency "1" \
  --region eu-west-1
```

#### Setup

Navigate to the **Owned by me** tab and select the name of your created document, **PatchWithHealthcheck**, then click **Next**.

Because we want to test this document executing one at a time on an instance, we'll need to select the **Rate control** option.

{{< figure src="execute-automation-1.png" link="execute-automation-1.png" class="center" alt="Execute automation document page for PatchHealthcheck, Rate Control is selected" >}}

We'll need to select what instances are our targets. The instances in scope for this document are tagged with the key `App` with the value `HelloWorld`, so let's use that as our criteria. Note this is the most scalable solution for targeting instances. TODO link to github terraform for the tag being set?

{{< figure src="execute-automation-2.png" link="execute-automation-2.png" class="center" alt="A screenshot of the execute automation page with tag key App and tag value HelloWorld specified" >}}

> Because we used the special parameter `InstanceIds` in our document, the execution setup has displayed a nice instance picker for us to choose from!
>
> We're not using it in this example, but this is helpful if you just wanted to target a particular subset of instances.

{{< figure src="instance-id-picker.png" link="instance-id-picker.png" class="center" alt="A screenshot of the execute automation page with the instance ID picker being used to select instances in scope" >}}

Then we need to specify how the rate of invocation should be controlled. Our criteria for this is:

- Execute on 1 instance at a time
- Abort further invocations if any produce a error

Therefore we need to set the concurrency to 1 and the error threshold to 0.

{{< figure src="execute-automation-3.png" link="execute-automation-3.png" class="center" alt="A screenshot of the execute automation page with concurrency set to 1 and the error threshold set to 0" >}}

Once all done then click **Execute**.

#### Results

As the execution progresses you'll notice it invoke the document on one instance at a time. As it completes you'll have a screen that looks like the below as you click onto the execution detail page. Notice that the start and end times of each instance invocation do not overlap with one another. 

> Step name is the same as the instance ID in this case

{{< figure src="execute-automation-4.png" link="execute-automation-4.png" class="center" alt="A screenshot of the successfully completed execution detail page, all executed steps across all instances are successful and did not overlap one another" >}}

We can dive into each step invocation (the blue text in the above screenshot) to view the commands that were invoked.

{{< figure src="execute-automation-5.png" link="execute-automation-5.png" class="center" alt="A screenshot of a successful automation step, there is a clickable URL for the step execution ID" >}}

{{< figure src="execute-automation-6.png" link="execute-automation-6.png" class="center" alt="A screenshot of a successful automation document PatchWithHealthcheck - both patching and healthcheck run command steps are successful" >}}

At this detail we can see the individual `aws:runCommand` actions performed on the instance.

### Failure testing

Okay so we've confirmed the document now only invokes synchronously. Let's now test to see if further invocations are aborted when there is a failure.

To simulate the failure, we can borrow a trick from the [first post](/blog/automate-instance-hygiene-with-aws-ssm-0/#testing-in-aws-ssm-console) in this series by flipping the healthcheck script from `>` to `<`. Once that change is deployed we can re-run the document using the same method as [above](#testing-automation-documents).

{{< figure src="failed-automation-1.png" link="failed-automation-1.png" class="center" alt="Simulating a failure, now the rate-limited automation document fails on the first instance invocation" >}}

We can see the failure, and that the automation did not invoke on more instances! We can drill down into the invocation to see why it failed.

{{< figure src="failed-automation-2.png" link="failed-automation-2.png" class="center" alt="The execution detail page for PatchWithHealthcheck, the patch event succeeded but the healthcheck is marked as failed" >}}

From this page you can then continue to drill down to the run command output to determine the cause of the failure.

## Automating automation awesomeness

Now that we've tested the automation document and we're happy to have it automated, let's get this added to a maintenance window task. We can reuse the same maintenance window as we created last time, but with some differences.

Since we are targeting an automation document, we need to specify the `task_type` as `AUTOMATION`, and we update the `task_arn` to our new document accordingly.

We want to ensure our new combined document is only invoked on one instance at a time, so `max_concurrency` is set to `1`.

Within `task_invocation_parameters` we use `automation_parameters` as opposed to `run_command_parameters`.

- `document_version` allows us to target a specific document version
- any parameters required by the document are defined within `parameter`

Remember that our document takes in `InstanceIds` as a parameter? Well you'll notice that the value is set to `"{{ TARGET_ID }}"`. This is known in AWS as a [pseudo parameter](https://docs.aws.amazon.com/systems-manager/latest/userguide/mw-cli-register-tasks-parameters.html), whereby the instance ID returned by `WindowTargetIds` will be passed into the automation document.

> Depending on what `resource_type` your `aws_ssm_maintenance_window_target` is set up as will result in a different value to `{{ TARGET_ID }}` - in our case ours is `INSTANCE`, so this becomes the instance ID.
>
> See the [AWS docs](https://docs.aws.amazon.com/systems-manager/latest/userguide/mw-cli-register-tasks-parameters.html#pseudo-parameters) for a full breakdown.

```hcl
resource "aws_ssm_maintenance_window_task" "patch_with_healthcheck" {
  window_id        = aws_ssm_maintenance_window.patch_with_healthcheck.id
  task_type        = "AUTOMATION"
  task_arn         = aws_ssm_document.patch_with_healthcheck.arn
  priority         = 10
  service_role_arn = aws_iam_role.patch_mw_role.arn

  max_concurrency = "1"
  max_errors      = "0"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.patch_with_healthcheck_target.id]
  }

  task_invocation_parameters {
    automation_parameters {
      document_version = "$LATEST"

      parameter {
        name = "InstanceIds"
        values = ["{{ TARGET_ID }}"]
      }
    }
  }
}
```

`InstanceIds` is a special parameter name that AWS recognises and so will provide an instance picker in the GUI of Execute Automation.

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
