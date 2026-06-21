---
layout: default
---

<section class="home-hero">
    <div class="hero-grid">
        <div class="hero-copy">
            <div class="hero-kicker">Jeremy Nelson / Chicago / local AI / agent systems</div>
            <h1 class="glitch-title" data-text="Make the system legible.">Make the system legible.</h1>
            <p>
                I build and test practical AI agent systems on real machines. The work is routing,
                state, evals, local inference, failure visibility, and the evidence trail that makes an
                autonomous run inspectable after the impressive part is over.
            </p>
            <div class="hero-links" aria-label="Primary links">
                <a href="{{ '/field-notes' | relative_url }}">Field notes</a>
                <a href="{{ '/projects' | relative_url }}">Systems</a>
                <a href="{{ '/stack' | relative_url }}">Stack</a>
                <a href="https://x.com/n3lson" target="_blank">X profile</a>
            </div>
        </div>
        <div class="signal-panel" aria-label="Signal board">
            <div class="signal-header">
                <span>agent-run.log</span>
                <span>live</span>
            </div>
            <div class="signal-screen">
                <span class="scanline"></span>
                <p><span class="prompt">$</span> objective: make uncertainty smaller</p>
                <p><span class="prompt">$</span> boundary: scoped tools, visible state</p>
                <p><span class="prompt">$</span> proof: files touched, checks run, failures named</p>
                <p><span class="prompt">$</span> local: fast loops beat sovereignty theater</p>
                <p><span class="prompt">$</span> stop: when the next safe step is obvious</p>
            </div>
        </div>
    </div>
</section>

<section class="signal-strip" aria-label="Positioning summary">
    <div>
        <span class="metric-label">position</span>
        <strong>AI systems engineer</strong>
    </div>
    <div>
        <span class="metric-label">surface</span>
        <strong>agents under pressure</strong>
    </div>
    <div>
        <span class="metric-label">taste</span>
        <strong>proof over performance</strong>
    </div>
</section>

<section class="home-section">
    <div class="section-label"><span class="prompt">$</span> operating principles</div>
    <div class="feature-grid">
        <article class="feature-card">
            <h3>Evidence beats narration.</h3>
            <p>Useful agents leave a run record: goal, repo state, commands, failures, checks, diff, and the reason the work stopped.</p>
        </article>
        <article class="feature-card">
            <h3>Local AI is a loop-speed tool.</h3>
            <p>The value is a shorter path from patch to test to recovery when the machine is sitting on your desk.</p>
        </article>
        <article class="feature-card">
            <h3>Harnesses should preserve weirdness.</h3>
            <p>A good harness captures the edge case, replays the failure, and makes the next model prove it did not just get lucky.</p>
        </article>
        <article class="feature-card">
            <h3>Memory is not operating state.</h3>
            <p>The agent can be disposable. The work record cannot. Context needs source, freshness, scope, and a reason to go quiet.</p>
        </article>
        <article class="feature-card">
            <h3>Routing is product judgment.</h3>
            <p>Model choice should expose task type, tool access, fallback reason, cost, latency, and the point where a human can override it.</p>
        </article>
        <article class="feature-card">
            <h3>Failure visibility is the UI.</h3>
            <p>The useful workbench shows current objective, files touched, failed action, evidence changed, and the next safe step.</p>
        </article>
    </div>
</section>

<section class="home-section split-grid">
    <div>
        <div class="section-label"><span class="prompt">$</span> current signal</div>
        <div class="manifesto-block">
            <p>
                My lane is the unglamorous layer between a demo and a system people can trust:
                permissions, state, replay, tool boundaries, eval traces, model routing, local
                hardware constraints, and the human-readable artifact left behind.
            </p>
            <p>
                I write from the machinery. The best agent work feels like a clear workbench:
                current state, visible edges, failed attempts, and proof that the next move is safe.
            </p>
        </div>
    </div>
    <div class="callout">
        <h2>Things I keep coming back to</h2>
        <ul class="bullet-list">
            <li>cost per verified outcome</li>
            <li>run ledgers and handoff quality</li>
            <li>local model latency and recovery loops</li>
            <li>tool permissions, blast radius, and rollback proof</li>
            <li>the carrying cost of generated code</li>
        </ul>
    </div>
</section>

<section class="archive-section">
    <div class="section-label"><span class="prompt">$</span> featured writing</div>
    <ul class="post-list">
        {% for post in site.posts limit:6 %}
        <li class="post-item">
            <h2><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h2>
            <div class="post-date">{{ post.date | date: "%b %d, %Y" }}</div>
            {% if post.excerpt %}
            <p class="post-excerpt">{{ post.excerpt | strip_html | truncate: 180 }}</p>
            {% endif %}
        </li>
        {% endfor %}
    </ul>
</section>
