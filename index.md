---
layout: default
---

<section class="home-hero">
    <div class="hero-kicker">Agentic AI, local models, test harnesses</div>
    <h1>I build AI systems that have to work on real machines.</h1>
    <p>
        Field notes from Chicago. I care about latency, failure modes, and the small
        boring pieces that turn agent demos into systems people can actually trust.
    </p>
    <div class="hero-links">
        <a href="{{ '/about' | relative_url }}">About</a>
        <a href="{{ '/projects' | relative_url }}">Projects</a>
        <a href="{{ '/multiharness' | relative_url }}">multiharness</a>
        <a href="{{ '/field-notes' | relative_url }}">Field Notes</a>
        <a href="{{ '/stack' | relative_url }}">Stack</a>
        <a href="{{ '/now' | relative_url }}">Now</a>
        <a href="{{ '/uses' | relative_url }}">Uses</a>
        <a href="{{ '/archive' | relative_url }}">Archive</a>
    </div>
</section>

<section>
    <div class="section-label"><span class="prompt">$</span> focus</div>
    <div class="feature-grid">
        <div class="feature-card">
            <h3>Agent systems that run</h3>
            <p>Durable tasks, routing, retries, and failure handling. Less demo, more system.</p>
        </div>
        <div class="feature-card">
            <h3>Local AI on real hardware</h3>
            <p>Mac Studio setups, model choice, latency tradeoffs, and when local is the right move.</p>
        </div>
        <div class="feature-card">
            <h3>Harnesses and evaluation</h3>
            <p>If you cannot replay or explain the failure, you do not have much of a harness.</p>
        </div>
        <div class="feature-card">
            <h3>multiharness</h3>
            <p>A local-first agent harness that routes between local and cloud models without hiding the tradeoffs.</p>
        </div>
        <div class="feature-card">
            <h3>multiharness case study</h3>
            <p>The short public page for why routing is the product and the failure path matters.</p>
        </div>
        <div class="feature-card">
            <h3>Field notes</h3>
            <p>Short notes on routing, failure visibility, and the parts of the system I actually trust.</p>
        </div>
        <div class="feature-card">
            <h3>Stack</h3>
            <p>The public version of the setup: multiharness, ds4, and the reasoning behind both.</p>
        </div>
    </div>
</section>

<section class="archive-section">
    <div class="section-label"><span class="prompt">$</span> featured writing</div>
    <ul class="post-list">
        {% for post in site.posts limit:5 %}
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
