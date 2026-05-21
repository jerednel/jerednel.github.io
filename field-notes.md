---
layout: default
title: Field Notes
permalink: /field-notes/
---

<section class="page-intro">
    <div class="hero-kicker">Field Notes</div>
    <h1>What I actually care about in agent systems.</h1>
    <p>
        This is the short version I want people to see when they land from X:
        practical routing, visible failures, and local models that earn their place.
    </p>
</section>

<div class="split-grid">
    <section>
        <h2>Routing</h2>
        <p>
            A harness should make the local-vs-cloud choice boring and explicit. If it
            hides the decision, the system is already harder to trust.
        </p>

        <h2 style="margin-top: 28px;">Failure visibility</h2>
        <p>
            I care more about replayable failure paths than polished demos. If I can’t
            see what changed, I can’t tell whether the system got better.
        </p>

        <h2 style="margin-top: 28px;">Local inference</h2>
        <p>
            Local models are useful when the loop is fast enough to matter and the setup
            is honest about tradeoffs.
        </p>
    </section>

    <aside class="callout">
        <h2>Proof points</h2>
        <ul class="bullet-list">
            <li><a href="https://github.com/jerednel/multiharness" target="_blank" rel="noreferrer">multiharness</a> routes between local and cloud models.</li>
            <li><a href="https://github.com/antirez/ds4" target="_blank" rel="noreferrer">antirez/ds4</a> showed local inference in a real loop.</li>
            <li><a href="/projects/">Projects</a> collects the public versions of both.</li>
        </ul>
    </aside>
</div>
