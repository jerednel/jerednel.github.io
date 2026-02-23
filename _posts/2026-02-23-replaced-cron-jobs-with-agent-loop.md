---
layout: post
title: "I Replaced 6 Cron Jobs with One Agent Loop. Here's What Broke First."
date: 2026-02-23 09:00:00 -0600
tags: [automation, cron, agents, ai, monitoring]
---

I had six cron jobs scattered across three servers. They checked APIs, sent alerts, generated reports, and kept the lights on. They worked fine until they didn't. A job would fail silently. Another would run twice because of daylight saving time. One server ran out of disk space and nobody noticed because the monitoring job was on that same server.

So I built an agent loop. One process that handles everything, makes decisions, and tells me what it is doing. It sounded elegant. It mostly is. But the path from "elegant idea" to "production system" was paved with failures I should have seen coming.

## The Original Sin: Thinking This Was Simple

My first design was naive. A Python script with a `while True` loop, some `asyncio`, and a schedule dictionary. Jobs would register themselves, the loop would sleep until the next execution, and everything would be neatly orchestrated from one place.

It worked perfectly on my laptop for three days. I deployed it to a VPS and it died within six hours. The reason was embarrassing: I had not handled the case where a job runs longer than its interval. My web scraper job took 45 minutes. It was scheduled every 30 minutes. The queue backed up. Memory ballooned. The OOM killer stepped in.

Lesson one: cron's "skip if still running" behavior is actually a feature, not a limitation. I had to build that myself.

## The State Problem I Did Not Anticipate

Cron jobs are stateless by default. Each run is fresh. This is annoying when you want to know what happened last time, but it is also safe. Nothing carries over unless you explicitly save it.

My agent loop was stateful. It tracked job history, success rates, retry counts. I stored this in a SQLite database. Then the database locked during a concurrent write because I had forgotten that SQLite and asyncio do not play nice without proper connection handling.

The agent crashed. When it restarted, it had no idea what was supposed to be running. Some jobs were mid-execution. Others had failed but not been recorded. I spent two hours manually reconciling state, checking logs, and wondering why I had ever thought this was better than cron.

Lesson two: state management is the hard part. Plan for crashes, restarts, and partial failures. Use a proper database if you need concurrency, or accept the limitations of SQLite and design around them.

## The Timezone Bug That Woke Me Up

One job runs at 8 AM every weekday. Simple enough. I stored the schedule as "08:00" and parsed it with Python's `datetime`. I forgot to specify a timezone. The VPS was in UTC. I am in Central Time. For months, the job ran at 2 AM my time, which was fine because nobody was awake to see it fail.

Then daylight saving time happened. The job started running at 3 AM. Then 1 AM. I could not figure out why the schedule kept drifting until I realized that UTC does not have daylight saving time, but my naive time math did not account for the fact that "8 AM America/Chicago" is not a fixed UTC offset.

Lesson three: use a proper scheduling library. I switched to `APScheduler` which handles timezones, daylight saving time, and all the edge cases I had confidently assumed were "simple."

## The Debugging Nightmare

When a cron job fails, you get an email. It is ugly, but it works. When my agent loop failed, I got silence. The loop was still running, so there was no crash. The job had failed inside a task, swallowed by an exception handler I had written too broadly.

I spent a week with intermittent failures I could not reproduce. The logs showed success. The actual result was wrong. Eventually I found the bug: a `try/except Exception` block that logged the error but did not raise it, so the agent marked the job as completed successfully.

I ripped out all my error handling and started over. Now every job failure is loud. The agent sends me a Telegram message with the full traceback. It is annoying. It should be annoying.

Lesson four: silent failures are worse than no automation at all. Build alerting first, features second.

## What Actually Got Better

After fixing the catastrophic mistakes, some things genuinely improved.

**Dependencies between jobs.** Cron makes this painful. You either chain jobs with `&&` or use temporary files as signals. My agent can declare: "Job B runs after Job A succeeds." If Job A fails, Job B waits. If Job A succeeds, Job B starts immediately. No polling, no race conditions.

**Dynamic scheduling.** Some jobs need to run more often during business hours. Others should back off when APIs are rate-limiting. The agent adjusts. It failed a few times before I got the backoff logic right, but now it self-tunes better than a static crontab ever could.

**Centralized observability.** I can ask the agent what it is doing. It tells me: three jobs running, two queued, one failed three hours ago. I built a simple web dashboard because I got tired of querying the database. This would have been a project with cron. With the agent, it was a 50-line Flask app.

## The Tradeoffs Are Real

I lost something in this transition. Cron is universal. Every sysadmin knows how to read a crontab. My agent is bespoke. If I get hit by a bus, someone has to read my code to understand what runs when.

I also gave up simplicity. A cron job is one line. My agent is 800 lines of Python, plus tests, plus monitoring, plus a systemd unit file to keep it alive. That is overhead I cannot ignore.

But I gained resilience. Jobs do not overlap. Failures are visible. State is tracked. The system heals itself from most transient errors without waking me up.

## Would I Do It Again?

Yes, but differently. I would use an existing framework like `APScheduler` or `Prefect` from day one instead of rolling my own. I would design for crashes before handling success cases. I would build alerting before building the first actual job.

If you have simple, independent tasks that just need to run periodically, cron is still the right answer. Do not let the agent hype convince you otherwise. But if your automation has grown into a tangled mess of dependencies, retries, and state management hacks, an agent loop might be worth the migration pain.

Just expect the first week to be rough. The failures are educational. The debugging builds character. And when it finally works, you will have earned the right to be slightly smug about it.

I am still slightly smug. But I check the logs every morning. Just in case.
