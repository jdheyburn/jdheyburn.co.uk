---
date: 2020-12-12
title: "Who Goes Blogging 7: Hugo Minify RSS Code Indentation Fix"
description: Hugo's minify function can cause code indentation in RSS feeds to break - I discuss the fix in this post
type: posts
series:
    - Who Goes Blogging
tags:
    - rss
    - hugo
draft: true
---

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

This is happening during the [GitHub Action](https://github.com/jdheyburn/jdheyburn.co.uk/blob/master/.github/workflows/deploy.yml#L31) that builds the website - I am using the `--minify` parameter which follows [this configuration](https://gohugo.io/getting-started/configuration/#configure-minify) by default, and the highlighted line.

```toml {hl_lines="24"}
[minify]
  disableCSS = false
  disableHTML = false
  disableJS = false
  disableJSON = false
  disableSVG = false
  disableXML = false
  minifyOutput = false
  [minify.tdewolff]
    [minify.tdewolff.css]
      decimals = -1
      keepCSS2 = true
    [minify.tdewolff.html]
      keepConditionalComments = true
      keepDefaultAttrVals = true
      keepDocumentTags = true
      keepEndTags = true
      keepQuotes = false
      keepWhitespace = false
    [minify.tdewolff.js]
    [minify.tdewolff.json]
    [minify.tdewolff.svg]
      decimals = -1
    [minify.tdewolff.xml]
      keepWhitespace = false
```


So what's happening is the RSS XML that Hugo generates for us is then being [minified](https://en.wikipedia.org/wiki/Minification_(programming)) to remove the whitespace generated in that file. This includes the whitespace that's used to indent the code in the RSS feeds. Not. Good.

## The Fix

In order to fix this we just need to copy the default minify config as mentioned above and change the last line to `keepWhitespace = true`.

You can view my [git commit](https://github.com/jdheyburn/jdheyburn.co.uk/commit/e56aaf581283eb7a7a4d97ca7a30553beda09271) that fixes this - should you want to include the fix too.

> I'm using `toml` for my config, so make sure you change it to what your config is defined in (`yaml` / `json`)

I tried to experiment to see if the whole config was required or not, but it appears so - if you found a way to omit some lines then let me know.

That's it - hope this help you with fixing your RSS feeds too!
