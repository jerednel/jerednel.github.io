---
layout: default
title: Archive
---

<section class="page-intro">
    <div class="hero-kicker">Archive</div>
    <h1>Writing archive</h1>
    <p>
        Older posts are still here, but the emphasis now is agentic AI, local models, and
        evaluation work.
    </p>
</section>

<section class="archive-section">
    <div class="section-label"><span class="prompt">$</span> ls -la posts/</div>
    <ul class="post-list">
        {% for post in site.posts %}
        <li class="post-item">
            <h2><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h2>
            <div class="post-date">{{ post.date | date: "%b %d, %Y" }}</div>
            {% if post.excerpt %}
            <p class="post-excerpt">{{ post.excerpt | strip_html | truncate: 160 }}</p>
            {% endif %}
        </li>
        {% endfor %}
    </ul>
</section>
