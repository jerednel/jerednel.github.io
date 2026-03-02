---
layout: post
title: "I Replaced 6 Cron Jobs with One Agent Loop. Here's What Broke First."
date: 2026-03-02 09:00:00 -0600
tags: [automation, agents, cron, reliability, debugging]
---

The migration seemed straightforward. Six cron jobs, one per server, each doing one thing. I consolidated them into a single Python process with an event loop. One month later, I had written more debugging code than automation code. The failures taught me that distributed scheduling and centralized scheduling fail in completely different ways.

## The First Failure: Clock Skew Between Jobs

Two of my cron jobs had an implicit dependency. The data export job ran at 2 AM. The report generation job ran at 3 AM, assuming the export would be ready. This worked because the servers had synchronized clocks and the export never took more than 45 minutes.

When I moved both jobs into my agent loop, I broke that timing guarantee. The agent ran on one machine with one clock, but I had not accounted for how my new scheduling logic handled the dependency. I used a simple delay: run job B 60 minutes after job A starts. But job A failed on Tuesday night. The agent logged the failure and moved on. Job B ran anyway, processing stale data from Monday.

The stakeholder noticed first. Wednesday's report showed Tuesday's numbers. I spent an hour tracing the logic before realizing the agent had no concept of "only run if the previous job succeeded." Cron's implicit isolation had been protecting me from my own assumptions.

I implemented explicit dependency tracking. Jobs now declare upstream requirements. The agent builds a DAG before each execution cycle. If a dependency fails, dependent jobs do not run. The failure is logged, an alert fires, and the stale report never gets generated.

## The Memory Leak I Could Not Reproduce

The agent process grew by 200 MB per day. I profiled it. The leak was not in my code. It was in a third-party HTTP client library that cached SSL contexts indefinitely. Each job made HTTPS requests. Each request created a new SSL context. The library never cleaned them up.

Cron jobs do not have this problem because each execution is a fresh process. The memory leaks, the SSL contexts, the file descriptors all get reclaimed when the process exits. My agent was long-running, so every resource leak accumulated.

I tried forcing garbage collection. No effect. The SSL contexts were referenced by the library's internal cache, which was not exposed in the public API. I considered switching HTTP libraries, but the migration cost was high. Instead, I implemented job process isolation. Each job runs in a subprocess. The agent manages the pool, monitors health, and restarts workers that exceed memory thresholds.

This added complexity I had not planned for. Now I have a supervisor managing workers managing jobs. The architecture looks more like a job queue than a simple loop. But the memory stays flat and I can blame external libraries without rewriting my automation.

## The Silent Deadlock

The agent uses SQLite for state persistence. Job status, last run time, retry counts. I chose SQLite because it is simple and requires no external dependencies. On day twelve, the agent stopped processing jobs. The process was running. The logs showed nothing after 4:47 AM.

I attached a debugger. The main thread was blocked on a database write. A job had crashed mid-transaction, leaving the SQLite database locked. The agent's next iteration tried to update job status, hit the lock, and waited forever. No timeout. No error. Just silence.

SQLite's default locking mode waits indefinitely. I did not know this. I had assumed a timeout would raise an exception I could handle. Instead, the agent hung silently for six hours until I noticed reports were not arriving.

The fix was setting a busy timeout. Five seconds, then fail and retry. But the bigger lesson was about assumptions. I had assumed SQLite behaved like other databases. I had not read the documentation on concurrency behavior. The agent architecture was built on a foundation I did not understand.

## The Configuration Drift Problem

Cron jobs have local configuration. Each server's crontab lives on that server. If I change one job, I change one file on one machine. The blast radius is contained.

My agent uses a central configuration file. One YAML file defines all six jobs, their schedules, their dependencies, their resource limits. This seemed like a win for consistency. Until I changed the schedule for job three and accidentally modified job four's retry policy because I was in a hurry and did not validate the file.

The agent loaded the broken config and started applying it. Job four, which had been stable for weeks, suddenly had no retry limit. It hit a transient API error and looped forever, hammering the endpoint until my account was rate-limited for 24 hours.

I implemented config validation before loading. JSON Schema checks the structure. Range validators check numeric values. A dry-run mode shows what would change without applying it. But the real fix was admitting that centralization creates single points of failure. The convenience of one config file comes with the risk of one mistake breaking everything.

## The Observability Gap

Cron emails you when a job produces output. It is crude but effective. My agent had structured logging, metrics, and health checks. It was objectively better telemetry. But I had not built the consumer side.

For two weeks, I was flying blind. The logs existed. I was just not looking at them. The metrics were being recorded. I had no dashboard. When a job failed, I would SSH into the server and tail log files like it was 2005.

I built a simple status endpoint that returns JSON. Then I built a CLI tool that queries it. Then I added a webhook that posts job failures to Slack. The observability stack grew from a side comment to a significant component of the system.

The lesson: better instrumentation without consumption is worse than simple instrumentation you actually use. I should have built the Slack integration before the third job. Instead, I discovered failures by users complaining, which is the worst possible monitoring strategy.

## What the Agent Does Better

After addressing the failures, some advantages became clear.

**Backoff and jitter.** When an API rate-limits the agent, it backs off exponentially. Cron would just keep hammering on schedule. I have seen the agent recover from transient outages without human intervention while cron would have required manual intervention or tolerated continuous failures.

**Dynamic schedule adjustment.** One job runs more frequently during business hours and less frequently overnight. Implementing this in cron requires two entries and a wrapper script. The agent adjusts its own sleep intervals based on time of day. The code is clearer and the intent is explicit.

**Resource awareness.** The agent checks available disk space before starting jobs that generate large outputs. It skips them and alerts rather than failing midway through. Cron has no such capability without external wrapper scripts.

## The Code I Wish I Had Written First

If I were starting today, I would separate concerns differently. The current architecture conflates scheduling, execution, and state management. Here is what I would build:

```python
# scheduler.py - decides what runs when
# executor.py - runs jobs and captures results
# state.py - persists job history and dependencies
# monitor.py - alerts on failures and anomalies
```

Each component has clear interfaces. The scheduler does not know about HTTP requests. The executor does not know about timezones. The state module handles all database access. The monitor is the only component that sends notifications.

This separation would have made testing easier. It would have made the SSL context leak simpler to isolate. It would have made the deadlock obvious because the state module would be the only place with database locks.

## The Tradeoffs I Accept

My agent is now 1,200 lines of Python. It has more code than the six cron jobs it replaced combined. It requires a systemd unit file, a log rotation configuration, and a monitoring dashboard. The operational surface area has grown significantly.

But the reliability has improved measurably. Jobs no longer overlap. Dependencies are explicit. Failures are visible within seconds rather than discovered by users hours later. The system heals itself from most transient errors.

I still keep a crontab entry for the agent itself. Every minute, cron checks if the agent process is running. If not, it starts it. Some problems are truly best solved with a 40-year-old scheduling tool. The agent handles the complex coordination. Cron handles the one thing it does perfectly: running commands on schedule.

The failures were expensive in time and stress. They were also necessary. Each one revealed an assumption I had made without realizing it. The agent is stronger now because it was broken repeatedly until the breaking stopped. That is not a comfortable development process, but it is an effective one.

If you are considering a similar migration, budget time for failures you cannot yet imagine. They will happen. The question is whether you have monitoring in place to catch them and time allocated to fix them. The agent loop is not inherently better than cron. It is different, with different failure modes, different scaling characteristics, and different operational requirements. Choose it for the right reasons and you will be happy. Choose it because cron seems old-fashioned and you will learn why cron is still everywhere.
