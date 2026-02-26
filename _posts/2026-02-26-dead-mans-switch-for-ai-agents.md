---
layout: post
title: "My AI Agents Kept Failing Silently. So I Built a Dead Man's Switch."
date: 2026-02-26 09:00:00 -0600
tags: [ai-agents, automation, monitoring, reliability, cron]
---

I run six AI agents on a permanent loop. They check my calendar, monitor GitHub repos, summarize pull requests, and handle routine data pipeline alerts. For three months, they worked fine. Then one died quietly on a Tuesday and I did not notice for four days.

The agent was supposed to scan for overdue dbt models every morning. It stopped running. My pipeline had stale data for 96 hours before a stakeholder asked why the dashboard looked wrong. The agent had encountered an unhandled API rate limit, crashed, and never restarted. systemd thought the process was fine because the parent was still running.

That failure taught me that agent reliability is not about making code that works. It is about making code that fails audibly.

## The Problem With "Just Use Cron"

My first attempt at scheduling was cron. Every agent had a crontab entry. This worked until it did not.

Cron has no concept of job success or failure. It runs a command at a time. Whether that command does what you want, whether it crashes, whether it produces output, cron does not care. You can redirect stderr to a log file, but then you need another system to watch that log file.

I tried adding health checks. Each agent would write a timestamp to a file on completion. A separate cron job would check those timestamps and email me if any were stale. This created a cascading dependency. Now I had to monitor the monitor.

The deeper problem was semantic. Cron assumes jobs are stateless and idempotent. AI agents are neither. They maintain conversation context, track memory across runs, and make decisions based on accumulated state. A naive restart does not restore them to a working condition. You cannot just "run it again" and expect coherent behavior.

## Attempt Two: Process Supervisors

I moved to systemd user services with restart policies. Each agent was a service. If it crashed, systemd would restart it. I added `Restart=always` and `RestartSec=10` and called it resilient.

This failed differently. One agent started hitting an API error on every run. It would start, fail immediately, systemd would restart it, it would fail again. The log file grew at 10MB per hour. The error was transient but the restart was not. I burned through my OpenAI API quota in a day because the agent kept retrying failed requests without backoff.

I added rate limiting and exponential backoff inside the agent. This helped with the API quota but revealed another problem. Some failures are permanent. An agent that crashes because its configuration file is malformed should not restart forever. It should stop and alert. Distinguishing transient from permanent failures requires context that systemd does not have.

## The Dead Man's Switch Pattern

The solution I use now is explicit heartbeat signaling. Every agent must prove it is alive and healthy by writing a structured health packet at regular intervals. If the packet stops arriving or contains an unhealthy status, the monitoring system takes action.

The health packet is a JSON file in a known location:

```json
{
  "agent_id": "dbt-monitor",
  "timestamp": "2026-02-26T08:45:00Z",
  "status": "healthy",
  "last_success": "2026-02-26T08:30:00Z",
  "consecutive_failures": 0,
  "version": "1.2.3"
}
```

The `status` field can be `healthy`, `degraded`, or `failed`. The agent decides its own status based on internal health checks. The `consecutive_failures` counter tracks how many runs failed since the last success. The `version` field lets me detect when an agent is running stale code after a deployment.

A separate watchdog process reads these packets every 60 seconds. It enforces three policies:

1. **Staleness**: If a packet is older than the expected interval plus a grace period, the agent is marked failed.
2. **Threshold**: If `consecutive_failures` exceeds a limit (usually 3), the agent is marked failed even if it is still reporting.
3. **Degradation**: If status is `degraded` for more than 15 minutes, escalate to `failed`.

When an agent is marked failed, the watchdog sends a notification and stops the agent process. It does not restart it automatically. Automatic restart was the mistake I made with systemd. Some failures need human attention.

## Implementation Details That Matter

The health packet must be written atomically. If the agent crashes mid-write, you do not want a partially written JSON file. I use a write-to-temp-then-rename pattern:

```python
import json
import tempfile
import os
from pathlib import Path

def write_health_packet(path: Path, packet: dict) -> None:
    temp_path = path.with_suffix('.tmp')
    with open(temp_path, 'w') as f:
        json.dump(packet, f)
        f.flush()
        os.fsync(f.fileno())
    os.rename(temp_path, path)
```

The `fsync` ensures the data hits disk before the rename. The rename is atomic on POSIX systems. The watchdog never sees a half-written packet.

The watchdog itself is a simple Python script running under systemd. Ironic, perhaps, but the difference is the watchdog has one job and it is simple enough to be obviously correct. It reads JSON files and makes decisions. It does not call external APIs or maintain state beyond the packet cache.

## Handling Agent-Specific Failure Modes

Different agents fail in different ways. The dbt monitoring agent fails when the warehouse is unreachable. The GitHub PR summarizer fails when rate limits kick in. The calendar agent fails when OAuth tokens expire.

Each agent implements its own health check logic. The dbt agent considers itself degraded if query latency exceeds 30 seconds. The GitHub agent tracks its remaining rate limit and marks itself degraded below 100 requests. The calendar agent attempts a token refresh proactively and marks itself failed if refresh fails.

This domain knowledge belongs in the agent, not the watchdog. The watchdog enforces universal policies. The agents report domain-specific status. The separation of concerns keeps both pieces simple.

## The Notification Problem

When an agent fails, someone needs to know. I started with email. Emails got ignored. I moved to Slack direct messages. Those got noticed but created alert fatigue during periods of instability.

The notification system I use now has tiers:

- **Degraded**: Log only. No notification unless sustained.
- **Failed**: Immediate Slack DM with summary.
- **Failed for >1 hour**: Escalate to secondary channel with louder formatting.
- **Failed for >4 hours**: Page via Pushover with emergency sound.

The escalation prevents alert fatigue while ensuring real problems get attention. The thresholds are configurable per-agent. The calendar agent pages after 1 hour because missed meetings have immediate consequences. The PR summarizer waits 4 hours because code review delays are acceptable overnight.

## Recovery Procedures

When the watchdog detects a failed agent, it does not automatically restart. Instead, it creates a recovery ticket in my task system with a standard template:

```
Agent: {agent_id}
Failure Time: {timestamp}
Last Known Good: {last_success}
Consecutive Failures: {count}
Recent Logs: {tail -n 50}
Suggested Actions:
1. Check recent deployments
2. Verify external service status
3. Review configuration
4. Restart manually after root cause identified
```

This forces me to understand the failure before masking it with a restart. Sometimes the fix is a configuration change. Sometimes it is a code fix. Sometimes the external service is down and I just wait.

The manual step feels like friction. It is. But automatic restart of failing agents created more problems than it solved. The friction ensures I actually fix root causes instead of accumulating technical debt.

## What the Metrics Show

I have been running this system for two months. The data tells an interesting story.

Agents report degraded status about 3 times per week on average. Most resolve within 10 minutes without intervention. These are transient issues like API latency spikes.

Agents mark themselves failed about once per week. Half are due to external service outages. A quarter are configuration issues after deployments. The remaining quarter are bugs in the agent logic.

The dead man's switch caught 12 silent failures. These were cases where the agent process was running but not making progress. Without heartbeat verification, I would not have known. Two of those would have caused data pipeline delays if undetected.

Average time from failure to notification: 73 seconds. That includes the heartbeat interval, the watchdog polling interval, and notification latency.

## The Tradeoffs I Accept

This system adds complexity. I went from cron entries to systemd services to a custom watchdog with its own configuration and notification logic. The watchdog is itself a single point of failure. If it dies, everything appears fine because nothing complains.

I mitigate this by having the watchdog write its own health packet to a separate file. A second-level watchdog (a 5-line shell script in cron) checks that packet. If the primary watchdog goes silent for 5 minutes, I get paged. It is turtles all the way down, but only two turtles deep.

There is also operational overhead. When I deploy a new agent, I must define its heartbeat interval, failure thresholds, and notification policies. This takes 10 minutes but feels like ceremony. I have a template that reduces the friction, but it is still more than `crontab -e`.

## Lessons for Agent Builders

If you are running AI agents on a schedule, implement heartbeat verification immediately. Do not wait for the silent failure that teaches you why you need it. The implementation is not complex. A JSON file and a 50-line watchdog script are sufficient.

Design your agents to be crash-only software. They should be able to restart from any state without corruption. This is harder than it sounds when agents maintain conversation history or accumulated context. Store state explicitly, version it, and validate it on startup.

Treat agent failures as opportunities to improve the system. Every failure should result in either a code fix, a configuration change, or a monitoring improvement. If you are restarting agents without understanding why, you are missing the point.

Finally, accept that perfect reliability is not the goal. The goal is detectable failure with fast recovery. Agents will break. The question is whether you know they broke and whether you can fix them quickly. The dead man's switch answers the first part. Good runbooks answer the second.

My agents still fail. The difference is now I know about it in 73 seconds instead of four days. That is the kind of reliability that lets me sleep through the night.
