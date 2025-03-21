---
date: 2025-03-21
title: Reorganising Obsidian Journal Notes
description: Using AI to help restructure my journal notes in an Obsidian vault
type: posts
tags:
  - ai
  - obsidian
---

I finished off my [previous post on journalling](/blog/how-i-use-obsidian-to-journal/) in Obsidian with a couple of wish lists:

> I do have some improvements I wish to make such as moving notes away from their respective flat directories. i.e.:
>
> - Daily notes move from `planner/daily` to be grouped by year and month: `planner/daily/YYYY/MM`
> - Weekly notes move from `planner/weekly` to `planner/weekly/YYYY`
> - Monthly notes move from `planner/monthly` to `planner/monthly/YYYY`

I've been playing around with AI code generation, specifically the Claude 3.7 Sonnet model, and I wanted to see if it could produce scripts to help with this.

With a few prompts, it returned with something I was able to use to move everything over. Initially it generated seperate scripts for each journal note type (daily, weekly, monthly, quarterly), but I asked it to condense them down into a single script for simplicity. I also asked for user confirmation prior to moving files as a means of validating what it's doing.

You can find all the scripts on the Github gist link below.

https://gist.github.com/jdheyburn/f64effd0b606a68044d7d28960becc77

I strongly recommend backing up your vault and pausing your sync tool of choice before executing any of the scripts.

{{< figure src="organised-daily-notes.png" link="organised-daily-notes.png" class="center" caption="After the scripts run, notes are now grouped into tidier directories" alt="Output of `ls -l` command, showing directories named after months and the daily notes underneath months" >}}

## Group new files

Now that existing files had been moved, I had to change the settings for the Periodic Notes plugin to template new files at their correct location:

{{< figure src="updated-periodic-notes-settings.png" link="updated-periodic-notes-settings.png" class="center" caption="" alt="Periodic Notes plugin in Obsidian, the format of each note has been updated as per below this image" >}}

I had to update the format of each periodic note as follows:

- Daily
  - `YYYY/MM/YYYY-MM-DD`
  - e.g.: `2025/03/2025-03-21`
- Weekly
  - `YYYY/YYYY-[W]ww`
  - e.g.: `2025/2025-W12`
- Monthly
  - `YYYY/YYYY-MM-[M]`
  - e.g.: `2025/2025-03-M`
- Quarterly
  - `YYYY/YYYY-[Q]Q`
  - e.g.: `2025/2025-Q1`

These get created under their respective note folder, e.g. `planner/monthly`.

With all but daily notes, I'm prepending `YYYY/` to the filename. Periodic Notes will see this as a directory and template out the format. Daily is prepended by `YYYY/MM/` to allow for grouping on months too.

## Updated explicit daily note links

From my [previous post](/blog/how-i-use-obsidian-to-journal/#daily) you would have seen daily notes link to adjacent days through an explicit link under `planner/daily`.

```
# Monday 20th November 2023
<< [[planner/daily/2023-11-19|2023-11-19]] || [[planner/daily/2023-11-21|2023-11-21]] >>
[[2023-W47]]  || [[2023-11-M]]
```

These links broke after the restructure because the notes are no longer directly underneath `planner/daily`. I can't remember the reason why I set it up this way; it might've been because I expected more daily notes in various locations. In either case I don't have a need for it, so we can change these to implicit links. There are also implicit links to weekly and monthly notes, but these links will work fine as the files are still in the vault, Obsidian will be able to find them.

I also asked Claude to write me a bash one-liner to rename these:

```bash
find planner/daily -name "*.md" -type f -exec sed -i '' -E 's/\[\[planner\/daily\/([0-9]{4}-[0-9]{2}-[0-9]{2})\|([0-9]{4}-[0-9]{2}-[0-9]{2})\]\]/[[\1]]/g' {} \;
```

This took just 2 seconds to run! I also made sure to backup my Obsidian vault before hand, in case it went a bit haywire.

My daily note template also needed updating so that new notes follow this:

```
# <% thisDayLong %>
<< [[<% previousDayFmt %>]] || [[<% nextDayFmt %>]] >>
[[<% thisWeek %>]]  || [[<% thisMonth %>]]
```

Finally, I enabled syncing and watched as all the files were updated.

Thanks for reading!
