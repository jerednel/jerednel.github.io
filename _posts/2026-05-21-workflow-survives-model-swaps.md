---
layout: post
title: "The Workflow Survives Model Swaps"
excerpt: "The real benchmark is whether the workflow still works when the model changes."
tags: [agents, local-ai, harness, evaluation, opinion]
---

A lot of model talk starts at the wrong layer.

I care less about the label on the model and more about whether the workflow still
behaves when the model changes.

If swapping models breaks the path, then the harness was doing hidden work.
If the failure mode changes in a way I can see, then the system is honest.

That is the part I want from agentic software:

- stable handoffs
- visible failures
- replayable state
- short enough loops to change the implementation without guessing

Local AI matters when it shortens the loop.
Cloud AI matters when the task needs more headroom.

The point is not ideology.
The point is a workflow that survives the swap.
