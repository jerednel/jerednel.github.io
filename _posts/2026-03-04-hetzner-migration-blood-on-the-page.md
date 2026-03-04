---
layout: post
title: "Moving My AI Workers to Hetzner: A Migration Guide with Blood on the Page"
date: 2026-03-04 09:45:00 -0600
tags: [infrastructure, hetzner, openclaw, ollama, migration, self-hosting]
---

I moved my entire AI agent infrastructure from a home server to a 4 euro Hetzner CX21 in under three hours. The migration worked. Then it broke. Then it broke again in ways I did not anticipate. Here is what actually happened, what I fixed, and what I should have done differently.

## The Setup I Was Leaving

My home server was an old Dell Optiplex with 32GB RAM and a GTX 1060. It ran OpenClaw, Ollama, cron jobs, and various Python scripts for SEO automation. It was reliable until it was not. Power outages, ISP issues, and the occasional thermal shutdown made it clear: if I wanted 24/7 agent availability, I needed something else.

Hetzner CX21: 2 vCPUs, 4GB RAM, 40GB NVMe, 4 euros per month. No GPU. The challenge was not the move. The challenge was running everything that previously needed 32GB RAM and a GPU on a machine with neither.

## The First Mistake: Thinking the Cloud Had Infinite Resources

I copied my entire setup to the CX21 and started services. Ollama loaded a 7B model. The system immediately started swapping. Response times went from 2 seconds to 90 seconds. The agent loop, which checks for work every minute, could not complete its cycle before the next cycle started.

I checked the specs again. 4GB RAM total. The Ollama model alone needed 4.5GB. I had assumed I could run the same models on CPU with a performance penalty. I was wrong. The penalty was not performance. It was functionality.

The fix was model downsizing. I switched from Llama 2 7B to Qwen 2.5 3B. It fit in 2.1GB. Responses took 8 seconds instead of 2, but they completed without swapping. The agent loop stabilized. I lost some reasoning quality, but the system became predictable again.

## The Authentication Cascade

Moving to a new machine meant re-authenticating everything. This sounds simple. It was not.

First: OneDrive. My scripts use the OneDrive CLI to fetch client data. The authentication token was tied to the old machine's browser state. I had to re-run the device flow, copy the code, authorize on my laptop, then paste the resulting token back. The CLI documentation says this takes two minutes. It took forty because I kept missing the 15-minute token expiration window.

Second: Google services. The gog CLI, which I use for some legacy data pulls, stored credentials in a keyring that did not transfer. Re-authentication required a headless browser flow that Google kept blocking as suspicious. I had to add the CX21's IP to my Google account's trusted devices, wait an hour for propagation, then try again.

Third: SSH keys. I had automated pushes to GitHub. The new machine had no keys. I generated them, added them to GitHub, then realized my deployment scripts hardcoded the old machine's SSH key path. I updated the scripts, committed, pushed, and pulled on the new machine. The git pull failed because the remote was still set to the local IP of the old server.

Every authentication flow broke. Each one seemed trivial. Together, they consumed two hours.

## The Path Problem

My scripts had hardcoded paths. `/home/jeremy/old-server/scripts/` appeared in fifteen files. I had meant to use environment variables. I never did. Now I was `sed`-ing through files on a production machine, hoping I did not break anything.

Some paths were in Python scripts. Some were in shell wrappers. Some were in systemd unit files I had forgotten existed. I found one in a cron job that called a script that called another script with an absolute path.

The proper fix would have been configuration management. Ansible, or at least a consistent environment variable scheme. I did not have that. I had thirty minutes of `grep -r` and careful editing. It worked. It was not maintainable.

## The Bear Blog Integration I Almost Forgot

My content pipeline generates posts for Bear Blog. The integration was a Python script that called the Bear API. On the old machine, it ran as part of a daily cron job. I moved it to the CX21, ran it manually to test, and got a 401 error.

The Bear Blog API key was in an environment variable on the old machine. I had not exported it. Worse, I could not find where I had originally stored it. I checked my password manager. I checked my notes. I checked email. I found it in a shell history file from six months ago, still there because I had never configured HISTCONTROL.

I set the variable, tested the script, and watched it succeed. Then I added it to systemd's environment file so the cron job would have it. Then I restarted the cron service. Then I realized systemd does not reload environment files on service restart; you need daemon-reload. Another ten minutes of debugging why scheduled posts were not appearing.

## The Monitoring Gap

On my home server, I knew something was wrong because I would notice. The machine was in my office. If the fans spun up, I heard it. On a Hetzner VPS, there is no fan noise. There is nothing.

The CX21 had its first OOM kill at 3 AM. I found out at 9 AM when a client asked why their report had not arrived. The agent process had died. Systemd had restarted it. The restart had failed because the SQLite database was locked from the unclean shutdown. The agent was running but not processing jobs because it could not write state.

I built a dead man's switch that afternoon. A simple script that runs every five minutes, checks if the agent has written a heartbeat to a file, and alerts me if the heartbeat is stale. It is crude but effective. I should have built it before the migration.

## What Actually Works Now

After three days of fixes, the system is stable. Here is the architecture:

**Ollama runs Qwen 2.5 3B.** It is not as capable as the 7B model, but it fits in RAM. For tasks that need more reasoning, I call the OpenClaw gateway which can route to cloud models. Most automation tasks do not need deep reasoning. They need consistent, fast responses.

**OpenClaw runs in a systemd service with restart always.** If it crashes, it comes back. If it OOMs, it comes back. The dead man's switch alerts me if it comes back broken.

**All secrets are in environment files loaded by systemd.** No more hardcoded tokens. No more hunting through shell history.

**Cron jobs are minimized.** The agent loop handles scheduling. Cron only runs the dead man's switch and the agent health check.

**Data flows through OneDrive.** Client files sync from their shared folders to the CX21. Processed reports sync back. The agents never hold the only copy of anything important.

## The Cost Reality

4 euros per month for the CX21. Bandwidth is included. I pay for outgoing traffic over 20TB, which I will never hit. The home server cost nothing to run except electricity, which was about 8 euros per month. The migration saved me 4 euros monthly and gave me actual reliability.

But the time cost was real. Six hours of migration work. Two hours of debugging the first week. Another hour building monitoring. At my hourly rate, I could have rented a managed service for a year. The economics only work because I learned things I will use again.

## What I Should Have Done

1. **Documented every authentication flow before starting.** I would have known about the Google trusted device delay.

2. **Used environment variables for all paths from the start.** The `sed` marathon was avoidable.

3. **Built monitoring first, not after the first outage.** The 3 AM OOM kill was predictable. Predictable problems should not become surprises.

4. **Tested the smaller model before migration.** I would have known about the RAM constraints and planned the architecture accordingly.

5. **Created a proper secrets management system.** Environment files in systemd are better than hardcoded strings, but they are not a vault. I am considering HashiCorp Vault or at least a proper secret manager. For now, file permissions and regular audits suffice.

## The Verdict

The migration was worth it. My agents run 24/7 without interruption. Clients get their reports on time. I do not worry about power outages or thermal shutdowns. The 4GB RAM constraint forces me to write efficient code, which is a feature disguised as a limitation.

But I am not happy with how I got here. The failures were avoidable. The debugging was unnecessary. The migration was a success because I fixed problems quickly, not because I avoided them.

If you are considering a similar move, budget time for authentication hell. Test your resource assumptions. Build monitoring before you need it. And accept that your first migration will teach you what your second migration should look like. Mine certainly did.
