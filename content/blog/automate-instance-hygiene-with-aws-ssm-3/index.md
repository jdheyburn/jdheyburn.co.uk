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

> While user data is useful in starting services, I don't advise storing the source code of your application in there like I've done - this is just a hacky way to get something up and running.

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
export GOCACHE=/tmp/go-cache
nohup go run /home/ec2-user/main.go
```

So on instance boot this will:

1. Create a new file called `main.go` and populate it with the lines between the `EOF` delimiters
1. Install Go
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

We can place a load balancer in front of our services

## Back to the problem

Now that we have a load balancer fronting our services, let's review executing our automation document and the problem it brings.



What we need is a means of removing the node from rotation

Terraform for this

Test it

Improvement to be made? can the load balancer ARN be dynamic?

LAstly write tldr
