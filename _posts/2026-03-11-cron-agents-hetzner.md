---
layout: post
title: "Cron Jobs That Think: Running Isolated AI Agent Sessions on Hetzner"
date: 2026-03-11
tags: [ai, automation, infrastructure, agents]
---

About three weeks ago I got tired of babysitting my automation workflows. I had a Hetzner VPS (meridian-platform) running OpenClaw as an agent framework, and I kept manually triggering tasks that should have just... run. SEO reports, email summaries, content drafts.

So I wired up a proper cron-based agent scheduling system. Here is what I built, where it broke, and what the system actually looks like now.

## The Core Idea

OpenClaw has two session modes: a persistent "main" session (my primary Telegram chat interface) and isolated sessions that spin up, run a task, and die. The cron scheduler can target either one.

The key distinction: main session cron jobs inject a `systemEvent` -- basically a text notification. Isolated sessions run a full `agentTurn`, meaning the agent gets a message, has access to all tools, produces output, and the session is cleaned up after.

For real automation, you want isolated sessions. The main session should not be doing background processing while you are also trying to talk to it. That is a mess.

## Setting Up the First Job

The first job I created was an SEO keyword pull. The payload looks like this:

```json
{
  "schedule": { "kind": "cron", "expr": "0 9 * * 1", "tz": "America/Chicago" },
  "payload": {
    "kind": "agentTurn",
    "message": "Pull keyword data from DataForSEO for Isotec Security. Top 20 keywords by volume under 2000. Save to /root/.openclaw/workspace/seo-subagents/content-intelligence/ideas-YYYY-MM-DD.md"
  },
  "sessionTarget": "isolated",
  "delivery": { "mode": "announce" }
}
```

The `announce` delivery mode pushes the result back to my Telegram channel when the isolated session finishes. So I get a notification with the output without the agent clogging up my main session history.

First run: it worked, mostly. The agent ran, called DataForSEO, got keyword data, and saved the file. But the announce message came back blank. The agent had written the file but its final reply was a tool call result, not a human-readable summary. Lesson: the `agentTurn` message should explicitly ask for a summary as the final output, not just the task.

Fixed the prompt to end with: "Reply with a one-paragraph summary of what you found." Blank announces stopped happening.

## The Memory Problem

The isolated sessions are stateless by design. No conversation history. That is mostly what you want for a background task. But it created a weird problem with my SEO jobs.

I had two separate cron jobs: one to pull keyword ideas, one to score them against existing content. The scoring job was supposed to build on the ideas from the same week. But isolated sessions do not share state. The scoring agent had no idea what the ideas agent found.

Three ways to solve this:
1. Chain the jobs manually by reading the output file (what I ended up doing)
2. Use a shared Mem0 memory store that both sessions can query
3. Combine into a single longer-running job

I went with option 1. The scoring job's prompt now starts: "Read the most recent file in /root/.openclaw/workspace/seo-subagents/content-intelligence/ and score each keyword idea against..." The agent reads the file the previous job wrote. Simple, explicit, no magic.

Option 2 is more elegant but the Qdrant + Mem0 setup I have (running at 127.0.0.1:6333 with text-embedding-3-small embeddings) is best for fuzzy semantic recall, not structured handoffs. Passing data through files is dumber but more reliable for task chaining.

## Debugging Isolated Sessions

When an isolated session fails, you find out through the announce message. Or you do not find out at all, if the session crashes before it can announce. This happened twice.

The run history endpoint shows you what happened:

```bash
openclaw cron runs <jobId>
```

First crash: the agent tried to call a tool that is not available in isolated sessions (I had tried to use a Telegram-specific capability that only works in the channel context). Fixed by removing that from the prompt.

Second crash: timeout. The job was asking the agent to do too much. DataForSEO call, score keywords, write file, check against Google Search Console data, format markdown. The session hit the default timeout before finishing.

Split it into two jobs with a 30-minute gap. Both now complete well within limits.

## The Actual Schedule Now

What runs automatically on meridian-platform right now:

- **Monday 9 AM CT**: Keyword ideas pull (DataForSEO, isolated session)
- **Monday 9:30 AM CT**: Keyword scoring against existing GSC data
- **Wednesday 2 PM CT**: Blog post draft (this post, in fact)
- **Daily 7 AM CT**: Heartbeat check in main session -- email sweep, calendar scan
- **Friday 4 PM CT**: Weekly SEO report compiled and sent via Resend from reporting@bymeridian.com

The blog post job is interesting. It is templated with topic area guidance, real stack constraints, and a word count range. The job runs an isolated session which writes the post, commits it, and pushes to GitHub Pages. I review the announce summary and either let it publish or pull it back.

Some posts I have edited after the fact. Some went straight through. The constraint list in the prompt matters a lot -- early drafts would casually mention Zapier or Notion or other tools I do not use, which was annoying to clean up. Locking the prompt to the actual stack fixed that.

## What Does Not Work Well Yet

Scheduling time zones are still slightly annoying to reason about. I specify `tz: "America/Chicago"` in the cron expressions but I am always second-guessing whether the `at`-style one-shot jobs are being interpreted as UTC or local. They are UTC. I have gotten this wrong twice and had a job fire at 3 AM.

The announce delivery has no retry logic. If Telegram is having a bad moment when the session finishes, the announcement silently drops. The job still ran, the output file still exists, but I do not get the notification. Not catastrophic but annoying. I add a note to HEARTBEAT.md to check the relevant output directory during the next heartbeat.

Session cleanup on crash is not always clean. Occasionally a failed isolated session leaves behind a dangling process. I check `cron runs` if something seems off.

## Takeaway

The isolated session + cron pattern is genuinely useful. The failure modes are manageable once you understand them. The key habits:

- Always ask for a plain-text summary as the last line of the prompt
- File-based handoffs between chained jobs, not shared state
- Keep individual jobs focused enough to finish within timeout
- Check run history before assuming a job "just didn't fire"

The Hetzner box runs this whole thing comfortably. No orchestration overhead, no k8s, no Lambda cold starts. Cron fires a process, process runs, process dies. That is the whole system.
