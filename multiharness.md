---
layout: default
title: multiharness
permalink: /multiharness/
---

<section class="page-intro">
    <div class="hero-kicker">multiharness</div>
    <h1>The routing layer I wish more agent demos had.</h1>
    <p>
        This is the short version of the project: a local-first harness that can route
        between local and cloud models without pretending the tradeoff does not exist.
    </p>
</section>

<div class="split-grid">
    <section>
        <h2>What it does</h2>
        <ul class="bullet-list">
            <li>decides when a local model is enough and when cloud is the better call</li>
            <li>keeps the failure path visible so I can see what changed</li>
            <li>makes the harness the thing I inspect, not just the model name</li>
        </ul>

        <h2 style="margin-top: 28px;">Why I care</h2>
        <p>
            Most agent setups talk about intelligence and skip routing. I care about the
            boring part because that is where the system becomes trustworthy.
        </p>

        <h2 style="margin-top: 28px;">How I describe it</h2>
        <p>
            multiharness is not a demo wrapper. It is the layer that decides what runs
            where, keeps the loop short, and shows me the failure instead of hiding it.
        </p>
    </section>

    <aside class="callout">
        <h2>Paired proof</h2>
        <ul class="bullet-list">
            <li><a href="https://github.com/jerednel/multiharness" target="_blank" rel="noreferrer">multiharness</a> is the routing layer.</li>
            <li><a href="https://github.com/antirez/ds4" target="_blank" rel="noreferrer">antirez/ds4</a> is the local inference proof.</li>
            <li><a href="/stack/">Stack</a> is the public summary of the setup.</li>
        </ul>
    </aside>
</div>
