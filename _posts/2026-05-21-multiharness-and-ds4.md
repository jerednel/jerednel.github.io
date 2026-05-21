---
layout: post
title: multiharness and ds4
excerpt: A local-first agent harness only matters if it makes model choice and failure modes visible.
---

I care about two things:

1. the harness has to tell me what changed
2. local models have to be good enough to justify their latency and cost tradeoffs

That is why I keep pointing people at [multiharness](https://github.com/jerednel/multiharness).
It is a local-first agentic harness that can route between local and cloud models without
turning the workflow into a black box.

I also got it working with [antirez/ds4](https://github.com/antirez/ds4), which is a useful
check that this is not just theory. If the loop is real enough, local inference stops being a
vibe and starts being a practical choice.

The point is not "local at all costs."
The point is: if I can inspect the failure, replay the path, and change the setup without
guessing, I trust the system more.
