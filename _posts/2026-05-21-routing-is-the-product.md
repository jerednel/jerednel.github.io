---
layout: post
title: Routing Is the Product
excerpt: If a harness cannot choose between local and cloud models cleanly, it is leaving the hard part unsolved.
tags: [agents, local-ai, routing, harness, opinion]
---

I do not care about "local first" as a slogan.

I care about whether the system can make a practical call:

- local when the loop needs to be fast
- cloud when the task needs more headroom
- and both inside one workflow without turning into a mess

That is the useful part of [multiharness](https://github.com/jerednel/multiharness).
It is a local-first agentic harness that can route between local and cloud models
without hiding the path it took.

The DS4 piece matters for the same reason.
[antirez/ds4](https://github.com/antirez/ds4) is not interesting because it is a name.
It is interesting because it proves the loop can be real enough that local inference
is not just a benchmark flex.

My test is simple: can I see what changed, replay the path, and trust the failure mode?
If yes, the harness is doing work.
If no, the model choice is still theater.
