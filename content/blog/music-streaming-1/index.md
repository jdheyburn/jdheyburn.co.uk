---
date: 2021-05-04
title: "Music Streaming 1"
description: Doing music streaming
type: posts
series:
  - Streaming music collection
tags:
  - test
draft: true
---

I mentioned in my previous post that I've been doing some organising of my music collection recently, the end goal of that was to self-host a personal music streaming service. This series will be an ongoing one about how I've managed to do that, and will probably include a load of changes along the way as I try out the various services and tooling available. But before we get anything streamed, we need to first organise what we have already. So to kick off this series, this post will talk about how my music is presently organised and how you can do the same too. Subsequent posts in the series will dive in a bit deeper on the streaming options.

## Why streaming service?

While I am subscribed to Spotify, they simply don't have all the music that I've bought over the years, whether that be music not available on streaming platforms, or just only having been released on vinyl - I'm missing out on listening to a lot of music I've bought over the years.

Without even getting into the discussion of audio quality of Spotify - they rank the lowest for paying artist royalties. Spotify I found has the best discovery algorithms for finding new music, and any that I really enjoy I try to buy physically or at the very least on Bandcamp.

## Organising music collection with beets

So if I'm going to stream, I need to make sure that all music files are grouped together in a way that makes it easier for streaming applications to find artists and their albums. I'm sure everyone at some point or another has _acquired_ music with varying degrees of quality, mixed tagging, and various folder structures. Maybe you even have two copies of an album and not realised it.

TODO include example of poor structure

The tool I came across to help combat this was beets. It's a free command-line app written in Python that creates a database (sqlite-backed) and given a directory to import, it will scan all music files within and try to correctly name and tag them.

Once it's identified the album the files correlate to, it will then move or copy (configurable) those files to a _new_ directory with the files grouped by however you want. I have this set up to group files by album artist, then by album title; this results in something like `music/Fleetwood Mac/Rumours/01 Fleetwood Mac - Second Hand News.mp3`.

Because beets maintains a database, it knows about albums you've already added to your library. So when you've already imported an mp3 album with 192kbps quality, and later down the import process it finds the same album with 320kbps, it's going to highlight that duplication to you along with the differences between them for you to decide how to proceed (Tip: it's going to be the better quality one).

### Configuring beets

Beets is **incredibly versatile and extensible**, and I spent a good deal of time playing around with various [config options](https://beets.readthedocs.io/en/stable/reference/config.html) in order to get my library organised how I would like.

