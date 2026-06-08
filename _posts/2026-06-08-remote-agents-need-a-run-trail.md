---
layout: post
title: "Remote Agents Need A Run Trail"
excerpt: "An agent can run somewhere else. The trail still has to be easy to inspect."
tags: [agents, remote-agents, workflow, verification, automation]
---

Remote agents and background agents have the same weak spot.

They can do useful work while you are not looking, but the work gets hard to
trust if the trail is thin.

For a coding agent, I want a short record.

- what it tried
- what changed
- what failed
- what it skipped
- whether the next run should keep going

That changes how much I trust the tool.

Mobile control is a good example.

It is nice to steer a Mac from a phone. I just do not want the phone to become
the place where I understand the whole task.

The phone should approve, redirect, or stop a run. The main machine should keep
the details.

Cron agents have the same issue.

A Telegram message that says a job ran is not enough. I want to know what
changed and whether the next run is safe.

Hosted agents make it more obvious.

If the work moved off my machine, I want to see the machine boundary. Image,
permissions, network path, and rollback are part of the work.

An agent can run somewhere else. The trail still has to be easy to inspect.

That is what lets you restart from the failure instead of reading a clean
summary and guessing what happened.
