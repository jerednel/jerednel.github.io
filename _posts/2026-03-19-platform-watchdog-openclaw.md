---
layout: post
title: "How I Built a Platform Watchdog With an AI Agent and Cron"
date: 2026-03-19
tags: [devops, openclaw, hetzner, docker, monitoring, debugging]
---

I run a small platform on a Hetzner VPS. One Docker stack, a handful of containers, one domain: app.bymeridian.com. Not a lot of moving parts, but enough to wake up to a broken site and spend 20 minutes figuring out what died and why.

So I built a watchdog. Not a paid service, not a dedicated monitoring tool. Just an OpenClaw cron job that checks whether the platform is alive and, if it isn't, does something about it.

Here's how that actually works.

## The Setup

The VPS runs Ubuntu, Docker Compose stack for the platform app, and OpenClaw for the agent layer. OpenClaw handles scheduled jobs in isolated sessions, each with its own model context. Alerts go to Telegram because that's where I live.

The watchdog job runs on a recurring interval. Its payload is an `agentTurn` that gets executed in an isolated session. The prompt tells the agent to:

1. Hit the health endpoint at app.bymeridian.com
2. If it returns 200, do nothing
3. If it fails or times out, SSH into the server and restart the relevant container
4. Either way, report back

The "report back" part matters. Delivery mode is `announce`, which pushes a summary to my Telegram channel when the run finishes. I get silence when everything is fine, a message when something was wrong.

## What Failed First

The first version of the watchdog used `curl` inside the agent session to check the endpoint. That worked in testing but missed a class of failures: the domain could resolve, the load balancer could respond, but the actual app container could be crashed with a 502 surfaced by nginx.

I changed the check to look at the HTTP status code, not just whether the connection succeeded. The health endpoint now explicitly returns 200 with a JSON body that includes the version and uptime. The watchdog checks both: status code and that the JSON parses without error. If either fails, it triggers the restart flow.

That caught two real incidents that curl-only would have missed.

## The Restart Logic

The restart is a shell command run over SSH: `docker compose restart api`. Not a full stack restart, just the API container, because it's almost always the API that goes down. The database container has never been the problem.

I debated whether to do `docker compose down && up` vs just `restart`. The difference matters. `restart` preserves volumes and network state but can leave a container in a bad state if the issue is something like a memory leak. `down && up` is cleaner but has more downtime.

I went with `restart` first, then added a follow-up check 30 seconds later. If the platform still isn't responding after the restart, the agent sends a higher-priority alert and stops retrying. At that point it's probably something I need to look at manually.

Two incidents so far. Both resolved by the restart. One was a memory limit being hit, the other was an unhandled exception that killed the process. Neither required me to touch anything.

## How the Cron Job Is Structured

OpenClaw cron jobs have a few key fields: schedule, payload, delivery, and sessionTarget. For this job:

- `schedule.kind` is `every` with an interval in milliseconds (every 5 minutes)
- `payload.kind` is `agentTurn` with the monitoring prompt
- `sessionTarget` is `isolated` so it doesn't carry state from previous runs
- `delivery.mode` is `announce` with `bestEffort: true` so a failed delivery doesn't block the job

The `bestEffort` flag was something I added after an early incident where the Telegram delivery itself was erroring (network blip), which was causing the job run to be marked failed even when the platform check succeeded. Now delivery failures are logged but don't affect the run status.

## What the Agent Actually Does

The agent in the isolated session has access to `exec` (for SSH commands) and `web_fetch` (for the health check). That's it. No memory access, no file writes. The prompt is specific enough that it doesn't need to improvise.

I've run it about 800 times now. The failure modes I've seen:

- SSH timeout when the server was briefly unreachable (marked as platform down, sent alert, I checked manually and it was fine)
- Health check returning 200 but the JSON parsing failing because the response was an nginx error page (this was the 502 case, correctly triggered restart)
- One false positive when I was doing a manual deploy and the container was legitimately down for 90 seconds

The false positive rate is low enough that I don't need a silence window or inhibit logic yet.

## Tradeoffs

Using an LLM agent for this is probably overkill. A shell script with curl, ssh, and mailx would do the same thing with less latency and zero cost per run. The real reason I did it this way is that OpenClaw is already the layer I use for everything else on this server, and I wanted the watchdog to fit into the same operational model: cron job, isolated session, Telegram output.

The cost is low because the prompt is short and the model doesn't do much reasoning. It executes a checklist. I'm not asking it to diagnose anything complex.

If I needed sub-minute alerting I'd use something purpose-built. For a side project where 5-minute detection is fine, this is good enough.

## Current State

The watchdog has been running for about a month. It's caught two real incidents. It's added maybe $3 in API costs over that time. I check Telegram, not dashboards.

The next thing I want to add is tracking restart history to a file on the server so I can look for patterns. If the API container is restarting every Tuesday at 2am, that's something I should know. Right now I just get the alerts and don't aggregate them.

That's the next version.
