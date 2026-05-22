---
layout: post
title: "Replayable Benchmarks"
excerpt: "A benchmark only starts earning trust when the harness can replay the same failure."
tags: [agents, harness, evaluation, benchmarks, reliability]
---

Replayable failure is the product.

If a model only looks good once, I do not trust the result.

What I want from a benchmark is not a bigger screenshot. I want a harness that
can answer a few boring questions:

- can it replay the same case?
- does the failure show up the same way twice?
- did one variable change, or did the whole setup drift?
- can I explain the delta after a model swap?

That is the part people skip when they talk about agent performance.

The model matters. The score matters. But the workflow is the thing you actually
ship.

The practical test is simple:

1. run the same task twice
2. change one variable
3. check whether the result changes in a way you can explain

If you cannot do that, you do not have a benchmark yet.

You have a story.

I care about replayability because it makes failures cheaper to use.

The first failure tells you something broke.
The second failure tells you whether the harness can show you the same thing
again.

That is when the result starts becoming useful.
