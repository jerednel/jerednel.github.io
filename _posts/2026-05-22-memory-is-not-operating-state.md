---
layout: post
title: "Memory Is Not Operating State"
excerpt: "Agent memory should help recover context. It should not become the authority for what is true."
tags: [agents, memory, state, workflow, verification]
---

The mistake in a lot of agent workflows is treating accumulated inference as
state.

The model talks through a task, remembers a few claims, summarizes its own
progress, and then the next step quietly depends on that residue being true.

That works until it does not.

The longer the run goes, the more the system can start carrying forward:

- stale assumptions
- unverified summaries
- half-correct file maps
- old tool results
- decisions that were never tied to evidence

That is not durable state.

That is operational gossip.

Memory should be input material, not the authority.

For long-running agent work, the durable part should live outside the model:

1. the declared objective
2. the current repo or app state
3. the commands that actually ran
4. the logs, screenshots, and errors observed
5. the files changed
6. the checks that passed or failed
7. the next concrete action

The agent can still use memory.

It can use it to recover context, avoid repeating decisions, and notice patterns
across sessions.

But each cycle should rebuild the working context from evidence the user can
inspect.

If the repo changed, the file tree wins.

If the browser disagrees, the browser wins.

If the test failed, the summary is wrong until it explains the failure.

That is the useful split:

- memory suggests where to look
- current state says what is true
- verification decides whether the work is done

This matters more as agents get longer-lived.

A short chat can survive some fuzzy continuity.

A background agent, scheduled run, or multi-hour coding task cannot.

Those systems need durable state that can be reconstructed without trusting the
model's self-narration.

The model can be disposable.

The work record cannot be.

That is the direction I trust: agents that are allowed to forget, because the
system around them knows how to rebuild the truth.
