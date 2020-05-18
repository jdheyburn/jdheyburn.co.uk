---
title: ":file_folder: Projects"
images:
    - images/jdheyburn_co_uk_card.png
---

## Portfolio Website

{{< figure src="jdheyburn-homepage.png" link="jdheyburn-homepage.png" class="center" alt="jdheyburn.co.uk homepage" >}}

- [jdheyburn.co.uk](https://github.com/jdheyburn/jdheyburn.co.uk) is my portfolio website - how you are reading this content!
- It is based the JAMstack framework [Hugo](https://gohugo.io/)
- Hosted on [GitHub Pages](https://pages.github.com/) and built & deployed via [GitHub Actions](https://github.com/features/actions)
- Globally distributed via [Cloudflare CDN](https://www.cloudflare.com/cdn/)

## OSS Contributions

### [terraform-aws-provider](https://github.com/terraform-providers/terraform-provider-aws/)

[**Add data source for aws_ssm_patch_baseline**](https://github.com/terraform-providers/terraform-provider-aws/pull/9486)

- Adding a data source component to `aws_ssm_patch_baseline` enables retrieval of AWS SSM Patch Baselines that already exist in your AWS account
- You can assign baselines that have been created by AWS, or managed outside of your Terraform configuration.
- A blog post detailing its capability will be linked here when available

**Status**: Merged :white_check_mark:

[**Add patch_source block to resource_aws_ssm_patch_baseline**](https://github.com/terraform-providers/terraform-provider-aws/pull/11879)
- The [patch source](https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager-how-it-works-alt-source-repository.html) API enables AWS SSM Patch Baselines to specify alternate patch repositories at runtime of the SSM Document AWS-RunPatchBaseline. 

**Status**: Awaiting Review :hourglass_flowing_sand: