---
layout: default
title: Projects
permalink: /projects/
---

<section class="page-intro">
    <div class="hero-kicker">Projects</div>
    <h1>Work worth pointing to.</h1>
    <p>
        These are the public projects I want the site and the X profile to point at when
        I talk about agentic AI, local models, and harnesses that have to survive reality.
    </p>
</section>

<div class="split-grid">
    <section>
        <h2>multiharness</h2>
        <p>
            <a href="https://github.com/jerednel/multiharness" target="_blank" rel="noreferrer">multiharness</a>
            is the main proof point: a local-first agentic harness that can use local and
            cloud models in the same workflow.
        </p>
        <ul class="bullet-list">
            <li>routes work to the right model instead of pretending one model fits everything</li>
            <li>keeps failure modes visible instead of burying them behind a polished demo</li>
            <li>makes the harness the thing you can inspect, replay, and trust</li>
        </ul>

        <h2 style="margin-top: 28px;">ds4</h2>
        <p>
            I also got it working with
            <a href="https://github.com/antirez/ds4" target="_blank" rel="noreferrer">antirez/ds4</a>,
            which is a good reminder that local models get interesting when the workflow is real
            enough to test.
        </p>
        <ul class="bullet-list">
            <li>local inference is only useful when the loop is fast enough to matter</li>
            <li>the model label matters less than how legible the failure path is</li>
            <li>good harnesses make model choice a practical decision, not a belief system</li>
        </ul>
    </section>

    <aside class="callout">
        <h2>How I talk about it</h2>
        <p>
            Short version: the harness is the product. The model is a component. If the
            system cannot show me what changed, I do not trust it yet.
        </p>
    </aside>
</div>
