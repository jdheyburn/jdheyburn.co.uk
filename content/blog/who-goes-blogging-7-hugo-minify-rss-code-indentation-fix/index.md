---
date: 2020-12-14
lastmod: 2021-12-15
title: "Who Goes Blogging 7: Hugo Minify RSS Code Indentation Fix"
description: Hugo's minify function can cause code indentation in RSS feeds to break - I discuss the fix in this post
type: posts
series:
    - Who Goes Blogging
tags:
    - rss
    - hugo
---

> **UPDATE 2021-12-15**
>
> The minify config was incorrect at time of publication, and so it's been corrected so that minification *does* happen while not impacting XML files.
>
> Thanks to [Andrea](https://aradaelli.com/) for pointing this out to me!

It's certainly been a while since the [previous post](/blog/who-goes-blogging-6-three-steps-to-improve-hugos-rss-feeds/) in this series, which has become the home of any updates I make to my [Hugo](https://gohugo.io/) website.

This post is a quick one but it's something I've been meaning to fix for a while. The RSS feeds that are generated will also include code blocks as defined through code fences (```) or through `{{</* highlight */>}}` shortcodes in your post content.

However for some reason the code blocks generated in my RSS feeds were losing their indentation. Take this code snippet example from my [latest post](/blog/automate-instance-hygiene-with-aws-ssm-2).

```hcl
resource "aws_ssm_document" "patch_with_healthcheck" {
name = "PatchWithHealthcheck"
document_type = "Automation"
document_format = "YAML"
content = templatefile(
"documents/patch_with_healthcheck_template.yml",
{
healthcheck_document_arn = aws_ssm_document.perform_healthcheck_s3.arn,
output_s3_bucket_name = aws_s3_bucket.script_bucket.id,
output_s3_key_prefix = "ssm_output/",
}
)
}
```

Whereas it should be rendering as:

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

This is happening during the [GitHub Action](https://github.com/jdheyburn/jdheyburn.co.uk/blob/master/.github/workflows/deploy.yml#L31) that builds the website - I had previously been using the `--minify` flag which follows [this configuration](https://gohugo.io/getting-started/configuration/#configure-minify) by default.

What's happening is the RSS XML that Hugo generates for us is then being [minified](https://en.wikipedia.org/wiki/Minification_(programming)) to remove the whitespace generated in that file. This includes the whitespace that's used to indent the code in the RSS feeds. Not. Good.

On original publication I thought setting `minify.tdewolff.xml.keepWhitespace = true` would be enough. On [closer reading](https://github.com/tdewolff/minify#xml), it does not have the desired effect.

## The Fix

In order to fix this we need to add in the below to the site's config. Then we can remove the `--minify` flag from our build script, since minification is enabled via our config now.

```toml
[minify]
  disableXML = true
  minifyOutput = true
```

> I'm using `toml` for my config, so make sure you change it to what your config is defined in (`yaml` / `json`)

Hope this help you with fixing your RSS feeds too!
