---
layout: default
---

<div class="home-intro">
    <h1>Hi, I'm Jeremy.</h1>
    <p>
        Data engineer in Chicago. I write about building data pipelines, 
        AI workflows, and the occasional productivity obsession. 
        Currently optimizing things at <a href="https://bain.com">Bain</a> 
        and <a href="https://seofriend.io">SEO Friend</a>.
    </p>
</div>

<h2 style="font-size: 1rem; color: var(--text-muted); margin-bottom: 24px; font-family: 'JetBrains Mono', monospace;">
    <span class="prompt">$</span> ls -la posts/
</h2>

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
