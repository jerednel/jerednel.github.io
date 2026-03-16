---
layout: post
title: "I Replaced 6 Cron Jobs with One Agent Loop. Here's What Broke First."
date: 2026-03-16
tags: [ai, agents, cron, infrastructure, openclaw, debugging]
---

Six months ago my Hetzner VPS had six cron jobs. Each did one thing: pull SEO data, check rankings, send a Telegram summary, run an outreach report, ping HubSpot, post to Bluesky. They worked fine in isolation. They were also a pain to maintain, hard to debug when they failed silently, and completely unable to handle any logic more complex than "run script, pipe output, send message."

I consolidated them into a single agent loop using OpenClaw on the same box. This is what I learned, mostly through things breaking.

## What "One Agent Loop" Actually Means

It is not one cron job. It is one *framework* handling multiple scheduled tasks, with shared memory, shared tooling, and a consistent execution environment. OpenClaw runs on the VPS and exposes a cron scheduler that fires isolated agent sessions at configured intervals. Each session runs a task with access to Mem0 for memory, the same set of tools I use interactively, and a Telegram channel for output.

The old architecture was six independent shell scripts scheduled via system crontab. If one failed, I found out when I noticed the report was missing. The new architecture fails loudly: failed sessions surface in Telegram, and I can inspect run history with `cron runs <jobId>`.

That said, the first two weeks were rough.

## What Broke First: Path Assumptions

The most common failure in the first week was wrong file paths. The agent sessions run as the `openclaw` user, not root. Half my scripts assumed `/root/obsidian-vault/` for notes storage. That directory does not exist for the openclaw user. Every session that touched note storage errored immediately.

Fix: move working paths to the workspace at `/var/lib/openclaw/.openclaw/workspace/`. I updated the scripts, updated `TOOLS.md` with the canonical paths, and added a note about the vault migration being incomplete. The vault at `/root/obsidian-vault/` is technically still there -- I just cannot use it from agent sessions without a sudo escalation I do not want to automate.

The lesson: cron jobs on a single-user system tend to accumulate root assumptions. When you move them to a service user, all those assumptions surface at once.

## What Broke Second: The gog CLI

I had a task that checked Gmail for urgent emails and summarized them to Telegram. Worked fine on my laptop. On the Hetzner box, `gog` authenticated against credentials stored in a keyring that was set up under a different user context. The credentials file was not migrated when I stood up the OpenClaw environment.

I spent about an hour thinking this was an OpenClaw issue before I realized `gog` just could not find its credentials. Running `gog auth credentials <json>` fixed it, except the credentials file path it expected (`/var/lib/openclaw/.config/gogcli/credentials.json`) did not exist yet, so I had to create the directory first.

The email check job still does not run fully automatically. I have not finished re-authenticating gog in that environment. The job is disabled in the scheduler until I do. I marked it in `TOOLS.md` with a warning so future-me does not waste time trying to figure out why it is broken.

## The Silent Failure Problem is Still Real

Old cron jobs failed silently. I expected agent sessions to be better. They are, but not automatically.

An isolated session that hits an unhandled error does log the failure. The problem is "log" and "notify" are different things. For the first few weeks I was not watching the cron run history, so I missed failures that had been silently accumulating. I assumed the agent would push a notification on failure. It does not unless you configure delivery mode for the job.

Once I set `delivery.mode = "announce"` on each job, failed runs sent a Telegram message. That is the behavior I wanted from the start -- I just had not read the docs carefully enough to know it was opt-in.

## Memory Across Tasks

This is the part that actually works better than the old cron setup. Mem0 gives tasks shared context without me having to pass state around manually.

The SEO report job stores ranking summaries as memories. The outreach report job reads those summaries without me explicitly wiring the two jobs together. The DataForSEO API call happens once; the data persists in memory and gets referenced downstream. With shell scripts, I was writing state to temp files and doing careful grep work to thread data between jobs. It was fragile.

The tradeoff is that memory retrieval adds latency. Auto-recall fires on every turn and does a Qdrant similarity search. For short tasks that run at 9 AM when no one is waiting on them, this does not matter. For anything interactive, you feel it.

## Debugging is Different Now

Shell script debugging: add `set -x`, read stderr. Agent session debugging: read the run log, look at which tool calls fired, check whether the memory injection was relevant to the task.

The run log format is actually good once you get used to it. Tool calls are sequential, you can see inputs and outputs, and errors are localized to the failing call. When the Bluesky post job started failing, the log showed exactly which atproto SDK call errored and what the response was. With the old script, I would have gotten a non-zero exit code and a generic error message.

The one thing I miss from shell scripts: they are auditable by anyone with a text editor. Agent sessions require understanding the framework to know what actually ran. That is a real tradeoff if you ever need someone else to look at your automation.

## Current State

Four of the six jobs are running reliably. One (Gmail check) is disabled pending re-auth. One (HubSpot sync) was cut entirely because it was not providing useful signal -- the job ran but I never looked at the output.

Consolidating into one framework did not automatically make everything work better. It made failures more visible and the successful tasks more composable. That is worth something, but it required fixing a bunch of things that the old brittle setup was quietly papering over.

If you are thinking about doing this: budget time for the migration phase. Every assumption your cron jobs make about users, paths, and credentials will surface in the first two weeks.
