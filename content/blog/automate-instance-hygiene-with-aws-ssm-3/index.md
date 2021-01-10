---
date: 2021-01-10
title: "Automate Instance Hygiene with AWS SSM: Proactive Instance Removal"
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

Welcome to the last post in this [series]() where we've been exploring SSM Documents. So far in the series we've covered:

- How [Command Documents](/blog/automate-instance-hygiene-with-aws-ssm-0/) can help to execute commands on EC2 Instances
- Automating these Command Documents through [Maintenance Windows](/blog/automate-instance-hygiene-with-aws-ssm-1/)
- Safely chaining Command Documents through [Automation Documents](/blog/automate-instance-hygiene-with-aws-ssm-2/), and aborting for any failures

This post will now look into how we can use Automation Documents to perform maintenance on EC2 instances without causing any reduced user experience.

## Prerequisites

As always, the code for this post can be found on [GitHub]().

ALB components - https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html

## Introducing load balancers

A key component when working with services is known as a [load balancer](<https://en.wikipedia.org/wiki/Load_balancing_(computing)>). These are components that distribute traffic and requests across backends (i.e. services) in a variety of algorithms, such as:

- Round-robin
  - every backend serves the same number of requests
  - most common
- Weighted round-robin
  - backends receive a fixed percentage of incoming requests
  - useful if some backends are more beefy than others
  - also used in [canary deployments](https://martinfowler.com/bliki/CanaryRelease.html)
- TODO add more

There are multiple benefits to having a load balancer sit in front of your services:

- Protecting your infrastructure; user requests are proxied via the load balancer
- Distribute traffic and requests however you like
- Perform healthchecks on backends and don't forward traffic to unhealthy nodes
- Drain and remove backends to permit for rolling upgrades

While there are several different load balancers out there such as [nginx](https://www.nginx.com/) and [HAProxy](https://www.haproxy.org/), AWS has its own managed load balancer service known as [ELB](https://aws.amazon.com/elasticloadbalancing/).

TODO add diagram of new architecture and explain

### Adding web services

In our current architecture, we just have 3 EC2 instances with nothing running on them which has served us well until now. Let's simulate a real web service by running a simple Hello World application across each of the instances. We can utilise EC2s [user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) to start a basic service up for us by giving it as script to run on boot.

> While user data is for useful provisioning services, I don't advise storing the source code of your application in there like I've done - this is just a hacky way to get something up and running.

Because Go is pretty awesome and simple, let's use that as our web service, returning a simple `Hello, World!` when it is hit. We'll also have it return the name of the instance that was hit - this will be used later.

```bash
#!/bin/bash
cat <<'EOF' > /home/ec2-user/main.go
package main

import (
        "fmt"
        "net/http"
        "os"
)

func main() {
        http.HandleFunc("/", HelloServer)
        http.ListenAndServe(":8080", nil)
}

func HelloServer(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        fmt.Fprintf(w, "Hello, World! From %v\n", hostname)
}
EOF
yum install golang -y
(crontab -l 2>/dev/null; echo "@reboot nohup go run /home/ec2-user/main.go") | crontab -
export GOCACHE=/tmp/go-cache
nohup go run /home/ec2-user/main.go
```

So on instance boot this will:

1. Create a new file called `main.go` and populate it with the lines between the `EOF` delimiters
1. Install Go
1. Create a [crontab](https://en.wikipedia.org/wiki/Cron) entry to run the service on subsequent boots
1. Run the Go application in the background

We've been using Terraform to provision our nodes. So we need to save this script in a file, `scripts/hello_world_user_data.sh`, and then pass it into the `user_data` attribute of our EC2 modules.

```hcl
module "hello_world_ec2" {
  source         = "terraform-aws-modules/ec2-instance/aws"
  version        = "~> 2.0"

  # ... removed for brevity

  user_data = file("scripts/hello_world_user_data.sh")
}
```

Terraform will recreate any EC2 nodes with a change in `user_data` contents, so when you invoke `terraform apply` all instances will be recreated.

After they have all successfully deployed, you should be able to `curl` the public IP address of each instance to verify your setup is correct. If you are getting timeouts then make sure your instances have a security group rule permitting traffic from your IP address through port 8080.

```bash
$ curl http://54.229.209.60:8080
Hello, World! From ip-172-31-39-169.eu-west-1.compute.internal

$ curl http://3.250.160.209:8080
Hello, World! From ip-172-31-21-197.eu-west-1.compute.internal

$ curl http://34.254.238.146:8080
Hello, World! From ip-172-31-8-52.eu-west-1.compute.internal
```

### Fronting with a load balancer

Now that we have a web service hosted on our instances, let's now add a load balancer in front of it - this will now become the point of entry for our application instead of hitting the EC2 instances directly.

> For this I am using a Terraform module for provisioning all the components in the load balancer, and expanding on them is beyond the scope of this post.
>
> You can navigate to the AWS ALB (TODO acronym?) [documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) to find out more.

#### Security groups

Before we can provision the load balancer, we need to specify the security group (SG) and the rules that should be applied to it. You can view this on [GitHub]().

Since our application is written to serve request on port 8080, we need to permit both the new `aws_security_group.hello_world_alb` SG and the existing `aws_security_group.vm_base` SG to communicate between each other.

```hcl
resource "aws_security_group" "hello_world_alb" {
  name   = "HelloWorldALB"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "alb_egress_ec2" {
  security_group_id        = aws_security_group.hello_world_alb.id
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vm_base.id
}

resource "aws_security_group_rule" "ec2_ingress_alb" {
  security_group_id        = aws_security_group.vm_base.id
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.hello_world_alb.id
}
```

Now we need to open up the ALB to allow traffic to hit it. In our case it will just be us hitting it, but this will change depending on who the consumer of the service is. If it is to serve traffic from the Internet then `cidr_blocks` would be `["0.0.0.0/0"]`.

The ALB will be hosting the traffic on insecure HTTP (port 80).

```hcl
resource "aws_security_group_rule" "alb_ingress_user" {
  security_group_id = aws_security_group.hello_world_alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [local.ip_address]
}
```

#### ALB module

The [module documentation](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest) will tell us how we need to structure it.

Our requirements dictate we need the following:

- Receive traffic on port 80
- Forward traffic to backend targets on port 8080
- Include health checks to ensure we do not forward requests to unhealthy instances

Translate these into the context of the module and we have something like this:

```hcl
module "hello_world_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "HelloWorldALB"

  load_balancer_type = "application"

  vpc_id          = data.aws_vpc.default.id
  subnets         = tolist(data.aws_subnet_ids.all.ids)
  security_groups = [aws_security_group.hello_world_alb.id]

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "instance"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        unhealthy_threshold = 2
        interval            = 6
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
}
```

> In order to keep this post simple I am not fronting services over HTTPS (secure HTTP) - I would strongly advise against doing this for non-test scenarios.

TODO keep?

<!-- Here's a breakdown of each attribute:

- `load_balancer_type` - application to provision an ALB
- `vpc_id` - set to the VPC where the rest of our stack is running in
- `subnets` - we're allowing the ALB to be provisioned in any subnet; for an ALB serving traffic from the web you would want to deploy it in a public subnet instead of a private one
- `security_groups` - what SGs should be applied to this ALB - we're assigning the one from [earlier]()

Now we define the target groups, which is a [key component](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) of an ALB. -->

Another piece we will need is to hook up our EC2 instances with the target group created.

```hcl
resource "aws_lb_target_group_attachment" "hello_world_tg_att" {
  count            = length(module.hello_world_ec2.id)
  target_group_arn = module.hello_world_alb.target_group_arns[0]
  target_id        = element(module.hello_world_ec2.id, count.index)
  port             = 8080
}
```

There's some clever Terraform going on here. All we're doing is looping over each of the created EC2 instances in the module and adding it to the target group, to receive traffic on port 8080.

### Hitting the load balancer

Whereas when we were testing the services by hitting the EC2 instances directly, we'll now be hitting the ALB instead. You can grab the ALB DNS name from the [console](https://console.aws.amazon.com/ec2/v2/home#LoadBalancers:sort=loadBalancerName).

```bash
$ curl http://HelloWorldALB-128172928.eu-west-1.elb.amazonaws.com:80
Hello, World! From ip-172-31-31-223.eu-west-1.compute.internal
```

Nice - and we can see from here what instance we've hit in the backend, since we included the hostname in the response.

If we now hit the ALB one more time, we will get a different instance respond.

```bash
$ curl http://HelloWorldALB-128172928.eu-west-1.elb.amazonaws.com:80
Hello, World! From ip-172-31-0-10.eu-west-1.compute.internal
```

This is the load balancer rotating between the backends available to it. We can see the rotation by repeatedly hitting the endpoint.

```bash
$ while true; do curl http://HelloWorldALB-128172928.eu-west-1.elb.amazonaws.com:80 ; sleep 1; done
Hello, World! From ip-172-31-31-223.eu-west-1.compute.internal
Hello, World! From ip-172-31-43-11.eu-west-1.compute.internal
Hello, World! From ip-172-31-0-10.eu-west-1.compute.internal
Hello, World! From ip-172-31-31-223.eu-west-1.compute.internal
Hello, World! From ip-172-31-0-10.eu-west-1.compute.internal
Hello, World! From ip-172-31-43-11.eu-west-1.compute.internal
Hello, World! From ip-172-31-43-11.eu-west-1.compute.internal
```

## Back to the problem

Now that we have a load balancer fronting our services, let's review executing our automation document and the problem it brings.

If an instance were to be rebooted during the AWS-RunPatchBaseline stage of the automation document, then there is a chance that a request would have been forwarded to that instance before the health checks against it have failed.

To simulate this, let's create a new automation document which simulates a reboot. We'll just take our existing patching document and replace the patch step with a reboot command, following the [guidelines](https://docs.amazonaws.cn/en_us/systems-manager/latest/userguide/send-commands-reboot.html) to do this.

```yaml
---
schemaVersion: "0.3"
description: Executes a reboot on the instance followed by a healthcheck
parameters:
  InstanceIds:
    type: StringList
    description: The instance to target
mainSteps:
  - name: InvokeReboot
    action: aws:runCommand
    inputs:
      DocumentName: AWS-RunShellScript
      InstanceIds: "{{ InstanceIds }}"
      OutputS3BucketName: ${output_s3_bucket_name}
      OutputS3KeyPrefix: ${output_s3_key_prefix}
      Parameters:
        Commands: |
          flag_location=/home/ec2-user/REBOOT_STARTED
          if [ ! -f $flag_location ]; then
            echo "Creating flag file at $flag_location"
            touch $flag_location
            echo "Reboot initiated"
            exit 194
          fi
          echo "Reboot finished, removing flag file at $flag_location"
          rm $flag_location
  - name: ExecuteHealthcheck
    action: aws:runCommand
    inputs:
      DocumentName: ${healthcheck_document_arn}
      InstanceIds: "{{ InstanceIds }}"
      OutputS3BucketName: ${output_s3_bucket_name}
      OutputS3KeyPrefix: ${output_s3_key_prefix}
```

Then the Terraform code for this looks like:

```hcl
resource "aws_ssm_document" "reboot_with_healthcheck" {
  name            = "RebootWithHealthcheck"
  document_type   = "Automation"
  document_format = "YAML"

  content = templatefile(
    "documents/reboot_with_healthcheck_template.yml",
    {
      healthcheck_document_arn = aws_ssm_document.perform_healthcheck_s3.arn,
      output_s3_bucket_name    = aws_s3_bucket.script_bucket.id,
      output_s3_key_prefix     = "ssm_output/",
    }
  )
}
```

Now if we were to run this document (TODO link to previous article on how to do this) against an instance while having the command below running on your local machine in the background to simulate traffic hitting the load balancer. 

```bash
$ while true;
do
  resp=$(curl http://HelloWorldALB-128172928.eu-west-1.elb.amazonaws.com:80 2>/dev/null)
  if echo $resp | grep -q html; then
    error=$(echo $resp | grep -oPm1 "(?<=<title>)[^<]+")
    echo "Error - $error"
  else
    echo $resp;
  fi
  sleep 1
done
```

TODO show the demo of this then carry on

What we need is a means of removing the node from rotation

Terraform for this

Test it

Improvement to be made? can the load balancer ARN be dynamic?

TODO have ip addresses all match up (may need to rerun commands)

LAstly write tldr
