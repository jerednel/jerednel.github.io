---
layout: post
title: "One Week After Replacing My Cron Jobs with an Agent Loop: Three Incidents"
date: 2026-03-23
tags: [ai, agents, cron, infrastructure, openclaw, debugging, postmortem]
---

Last week I wrote about consolidating six cron jobs into a single agent loop using OpenClaw on a Hetzner VPS. The migration took about two days. What followed was a week of incidents I did not expect.

This is the follow-up. Three things broke in ways that were instructive.

## Incident 1: Memory Poisoned a Downstream Task

The setup: I have a DataForSEO job that pulls keyword rankings each morning and stores a summary as a Mem0 memory. A second job -- an outreach report -- reads those memories and uses them to decide what to highlight. I built this deliberately, and it worked fine in testing.

What broke: the DataForSEO job started returning stale data because I hit a rate limit and the API call silently returned cached results. The job still completed. It still stored a memory. The memory was wrong, and the outreach report picked it up and sent a summary built on bad data. I did not notice for three days.

With the old shell scripts, each job was isolated. A bad output from job A did not automatically corrupt job B. The memory layer that makes tasks composable also makes them susceptible to garbage-in-garbage-out in ways that cross job boundaries.

Fix: I added a validation step to the DataForSEO job that checks result freshness before writing to memory. If the data is more than 24 hours old, it writes nothing and logs a warning. The outreach report now also checks the memory timestamp before using it. Not elegant, but it stops the propagation.

Lesson: shared memory is a shared failure surface. Treat it like a database -- validate on write, check freshness on read.

## Incident 2: The Delivery Mode Trap

OpenClaw's isolated sessions support a `delivery.mode` setting that controls how job output surfaces. The options are `announce` (push to Telegram), `webhook` (POST to a URL), or `none`. I set most of my jobs to `announce` after the first week.

What I did not notice: `announce` sends the final turn summary, not the full run log. One of my jobs -- the Bluesky posting job -- was completing and sending an "announced" summary that looked like success. The Qdrant semantic search was surfacing the right memory, the atproto SDK call was firing, and the Telegram summary said something like "Posted to Bluesky."

Except it was not posting. The atproto call was succeeding in the sense that it returned a response, but the post was going to a deprecated endpoint that the SDK silently accepted without actually creating a post. I only found out when I checked my Bluesky profile manually after five days.

The run log had the full response including a deprecation warning. The announced summary did not. I had built a monitoring setup that told me jobs completed without telling me what they actually did.

Fix: I added an explicit verification step that checks the Bluesky API for the post URI after each publish attempt. If the post is not found, the job fails loudly. I also changed the Telegram summary template to include the actual post URL when it succeeds, so there is a concrete artifact I can verify.

Lesson: "job completed" is not the same as "job did the right thing." Build verification into the task, not just error handling.

## Incident 3: Cron Schedule Drift

This one is minor but worth noting. I have a morning brief job that is supposed to fire at 7 AM Chicago time. I set the schedule in UTC (13:00) because the framework takes UTC cron expressions.

What I did not account for: DST happened. The US moved clocks forward, and my 13:00 UTC job now fires at 8 AM local instead of 7 AM. The job itself is fine. It just started being slightly wrong in a way that I notice every morning.

This is not an OpenClaw bug. It is a universal cron problem. OpenClaw does support timezone-aware cron expressions -- I just did not use one when I set up the job. The fix is a one-liner: update the schedule kind to `cron` with `tz: "America/Chicago"` instead of hardcoding UTC. I have not done it yet because the job still runs and the cost of the annoyance is lower than the cost of the fix at this exact moment.

Lesson: if your cron jobs are supposed to fire at a human-meaningful time (morning brief, end-of-day report), use a timezone-aware schedule from the start. UTC offsets are not stable.

## What the Week Actually Taught Me

The composability that makes an agent loop interesting is also where most of the new failure modes live. Shell scripts are isolated by default. They do not share memory, they do not build on each other's outputs, and when they fail, they fail in place. The blast radius is contained.

An agent loop with shared memory and chained tasks can produce failures that are harder to trace because the error happens in one place and surfaces somewhere else. The DataForSEO incident is a good example: the error was a stale API response, but the symptom was a wrong outreach report. If I had been debugging from the symptom, I would have started looking at the outreach job, not the data pipeline.

The visibility improvements are real. Run logs are better than shell stderr. Failed sessions surface via Telegram when delivery mode is configured. The Qdrant memory layer is genuinely useful for passing context between tasks without file I/O gymnastics.

But the debugging model is different, and assuming the old mental model would work here is what caused most of the wasted time.

If you are migrating from cron scripts to an agent loop: plan for the failure modes to change, not disappear. The ones you had before mostly go away. New ones show up.
