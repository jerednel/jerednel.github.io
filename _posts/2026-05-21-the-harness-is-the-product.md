---
layout: post
title: "The Harness Is the Product"
date: 2026-05-21 12:00:00 -0500
tags: [agents, harness, evaluation, reliability, opinion]
---

A lot of agent demos are impressive for about six seconds.

Then you ask the obvious question: what happens when it breaks?

That is where the actual product starts.

If your agent cannot tell you:

- what prompt it saw
- what tools it called
- what it retried
- what it changed
- where it failed

then you do not really have a harness. You have a demo with logging attached.

The harness is what makes the system testable.
It is what makes regressions visible.
It is what lets you compare models without trusting vibes.

This is why I care about test harnesses more than hype.

The model is important, obviously. But the harness decides whether the result is:

- a repeatable workflow
- a one-off trick
- or a confusing mess you cannot debug

I want systems that can answer simple questions cleanly:

- did it work?
- if not, why not?
- what changed since last time?
- what should I trust here?

That is the real work.

Everything else is the demo layer.
