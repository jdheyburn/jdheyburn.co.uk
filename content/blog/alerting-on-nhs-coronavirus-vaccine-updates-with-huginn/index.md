---
date: 2021-05-25
title: "Alerting on NHS Coronavirus Vaccine Updates With Huginn"
description: Using Huginn as a web scraping tool to send an email when the eligible age group for a Covid vaccine changes
type: posts
series: []
tags:
  - coronavirus
  - huginn
  - marcrebillet
  - portainer
  - smtp
draft: true
---

The UK's coronavirus vaccine strategy has been to target those most vulnerable first, and then trickle down towards the healthier population. Since that age is creeping down toward my age group, I wanted to see if I could alert myself when I would be eligible for the vax.

My local GP would send out an SMS text message informing me when I'm eligible, however I've heard that this text can come days after you're eligible. Knowing that the latest guidance is maintained on the [NHS Coronavirus Vaccine site](https://www.nhs.uk/conditions/coronavirus-covid-19/coronavirus-vaccination/coronavirus-vaccine/), I can use [Huginn](https://github.com/huginn/huginn#what-is-huginn) to alert me when the page updates with the latest eligibility.

{{< figure src="vaccine-eligibility.png" link="vaccine-eligibility.png" class="center" caption="" alt="A list of bullet points of who is eligible to receive the vaccine, includes people aged 32 years and older, vulnerable people, etc" >}}

## tl;dr

- Huginn is an automation tool with a number of different agents
- It can be configured to monitor a property (or properties) on a web page and trigger an action
- That action can take the form of an email alert
- This can be used to monitor the latest age group eligible for a vaccine

## Deploying Huggin

[Huginn](https://github.com/huginn/huginn) is a self-hosted automation kit that allows you to create agents and workflows in response to events, sort of like your own [IFTTT](https://ifttt.com/) (If This Then That). 

Being self-hosted it can be deployed out in a number of ways. I already have [Portainer](https://www.portainer.io/) (a GUI for [Docker](https://www.docker.com/)) running in a virtual machine - so to deploy it out I can follow the instructions for [Docker container deployment](https://github.com/huginn/huginn/blob/master/doc/docker/install.md) 



I use Caddy to give internal services at home a nice domain to remember. I added a configuration for Caddy to be Huginn-aware.

```json
TODO add config
```

Then I can access it from my browser.

## Setting up agents

The workflow we need to set up here is pretty simple whereby we only need two agents; a Website Agent and an Email Agent. The website agent will perform the scraping of the NHS website on a regular basis, and if the component on the web page has changed, then it will invoke it's downstream notifier - the Email Agent.

```text
Website Agent    ------ invokes ------>    Email Agent
```

### Website agent

From the Huginn home page, create a new agent, where the type will be Website Agent.

There will be a bunch of fields that appear, the only ones you need to fill in are:

- Name
  - e.g. `NHSScrape`
- Schedule
  - for me, checking once an hour is good enough
- Options

The other fields serve a purpose that's beyond the scope of this post.

Within Options comes the configuration used to define the website agent. The documentation for the agent config appears on the right hand side, so you can read through that for reference.

In order for us to determine how to configure this we first need to decide what part of the web page we want to be alerted on in event of a update. Refer to the screenshot above and you'll see a number of bullet points listed out of the vaccine criteria. The text we want to be alerted on is "people aged 32 and over".

The website agent supports an [xpath syntax](https://www.w3schools.com/xml/xpath_syntax.asp) as a config option, which is an expression syntax used to retrieve objects from XML documents - including HTML. But how do we find out what the xpath for this text field is?

Enter [SelectorGadget](https://selectorgadget.com/). It's a [bookmarklet](https://en.wikipedia.org/wiki/Bookmarklet) tool that helps with just that - I recommend taking a look at the [short tutorial](https://vimeo.com/52055686) on how to use it.

Since I know I only want to select the first bullet point in this particular list, I start off by first clicking that property which turns that node green.

{{< figure src="selector-gadget-1.png" link="selector-gadget-1.png" class="center" caption="Clicking on the property I want to target highlights it green" alt="" >}}

You can see the xpath for this is a `<li>` node, which returns 76 results on the page we're scraping. These are represented by the boxes that are highlighted yellow.

What I want to do is whittle it down by filtering out all the other `<li>` nodes I'm not interested in, so that I only have 1 result left. As I've already made my first selection, any subsequent clicks will now filter those out. So now it's just a case of playing whack-a-mole until all yellow highlighted fields are gone.

{{< figure src="selector-gadget-2.png" link="selector-gadget-2.png" class="center" caption="" alt="" >}}

Clicking the second bullet point indicated that I don't care about any other `<li>` elements in this range.

{{< figure src="selector-gadget-3.png" link="selector-gadget-3.png" class="center" caption="" alt="" >}}

`<li>` properties also make up headings at the top of the page - so these appear highlighted in yellow too.

{{< figure src="selector-gadget-4.png" link="selector-gadget-4.png" class="center" caption="" alt="" >}}

Clicking the Home element filters that out.

{{< figure src="selector-gadget-5.png" link="selector-gadget-5.png" class="center" caption="" alt="" >}}

Scrolling down further on the page, there's another `<li>` range which needs to be filtered.

{{< figure src="selector-gadget-6.png" link="selector-gadget-6.png" class="center" caption="" alt="" >}}

Boom - filtering that means we only have 1 element being targeted.

We now only have 1 selection, so now we can click the XPath button in the tool to retrieve the config we need.

```xpath
//ul[(((count(preceding-sibling::*) + 1) = 6) and parent::*)]//li[(((count(preceding-sibling::*) + 1) = 1) and parent::*)]
```

{{< figure src="selector-gadget-7.png" link="selector-gadget-7.png" class="center" caption="" alt="" >}}

Going back to the agent config, this xpath syntax then goes into the xpath key.

```json
{
  "expected_update_period_in_days": "2",
  "url": "https://www.nhs.uk/conditions/coronavirus-covid-19/coronavirus-vaccination/coronavirus-vaccine/",
  "type": "html",
  "mode": "on_change",
  "extract": {
    "title": {
      "xpath": "//ul[(((count(preceding-sibling::*) + 1) = 6) and parent::*)]//li[(((count(preceding-sibling::*) + 1) = 1) and parent::*)]",
      "value": "normalize-space(.)"
    }
  }
}
```

Once it's configured then you can click on **Dry Run** at the bottom to see the text it extracts.

### Email agent

Now that the website agent is set up we need to set up our alert destination; this takes the form of an email agent. At minimum, we only need to configure these fields:

- Name
  - e.g. NHSEmail
- Sources
  - select the website agent you created beforehand
- Options

Note that an agent such as email can have multiple sources - so if you wanted to be alerted on multiple web pages then you only need one email agent.

The options field is not as complex as the website agent - mine is configured with this:

```json
{
  "subject": "NHS Coronavirus Page update",
  "headline": "Vaccine age updated",
  "expected_receive_period_in_days": "2"
}
```

The real complexity lies in configuring Huginn to send email...

## Configure Gmail for sending email

I have a Gmail account which opens up SMTP access to allows applications to send email programatically, where Huginn has support for this. You'll notice back in setting up Huginn (TODO link) that I had a number of environment variables configured for SMTP. It took a bit of trial-and-error and searching through GitHub issues to get it right, but that config works for me.

Since my Gmail account is set up with 2FA, I cannot use my actual Gmail password in the SMTP_PASSWORD field. Instead what I have to do is set up an application-specific password that only Huginn is configured for. This restriction known in Google as [less secure app access](https://support.google.com/accounts/answer/6010255).

{{< figure src="google-less-secure-app-access.png" link="google-less-secure-app-access.png" class="center" caption="" alt="" >}}

As mentioned, we'll need to set up an app password. For this I navigated to the [app password page](https://myaccount.google.com/apppasswords) for my account and selected _Other (Custom name)_ from the app dropdown, to then enter the name of the app. The name doesn't matter here - it's for your reference.

{{< figure src="google-app-password-setup.png" link="google-app-password-setup.png" class="center" caption="" alt="" >}}

When you click on **Generate** it will display the password assigned. It is this value that goes into the SMTP_PASSWORD env var for Huginn to pick up.

As a recap, the environment variables that I needed to set in order to get emails to be sent were:

- `SMTP_DOMAIN=gmail.com`
- `SMTP_SERVER=smtp.gmail.com`
- `SMTP_PORT=587`
- `SMTP_AUTHENTICATION=plain`
- `SMTP_USER_NAME=$EMAIL_ADDRESS`
- `SMTP_PASSWORD=$APP_PASSWORD`
- `SMTP_ENABLE_STARTTLS_AUTO=true`
- `DATABASE_POOL=10`
  - I believe this is to tell Huginn that this is a production deployment - the default behaviour is to not send email in a non-prod deployment

Note if you did not start up Huginn with these environment variables already set, then you'll need to restart the service so that it can pick them up.

## Testing the flow

We can test the whole flow by making a modification to the website agent we created. Currently the mode we have it set to is `on_change` which is the desired end mode, and will only trigger its receivers if there has been a change in the property being selected. If we change the mode to be `all` then it will always invoke the receivers.

Couple this with setting a frequent schedule (i.e. every 5m) then we should be receiving an email with the current value every 5 minutes.

{{< figure src="example-email.png" link="example-email.png" class="center" caption="" alt="" >}}

Once the flow is tested, we can set the mode on the website agent back to `on_change`. Then it's just the waiting game until getting vaxx'ed up :syringe:

{{< youtube qeCwwYjf8gw >}}
