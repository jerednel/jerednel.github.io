---
layout: default
title: Answerproof
permalink: /answerproof/
description: "AI search visibility audits for B2B SaaS teams that need to know where buyers see competitors instead of them."
---

<section class="answerproof-hero" style="background-image: linear-gradient(90deg, rgba(8, 13, 19, 0.96) 0%, rgba(8, 13, 19, 0.86) 42%, rgba(8, 13, 19, 0.22) 100%), url('{{ "/assets/images/answerproof-hero.png" | relative_url }}');">
    <div class="answerproof-hero-copy">
        <div class="hero-kicker">Answerproof</div>
        <h1>Find out where AI search recommends your competitors instead of you.</h1>
        <p>
            A productized AI visibility audit for B2B SaaS teams. I test the buyer questions
            that matter, trace which sources AI systems cite, and turn the gaps into a 30-day
            revenue-search plan.
        </p>
        <div class="answerproof-actions">
            <a class="primary-action" href="mailto:jerednel@gmail.com?subject=Answerproof%20audit&body=Company%3A%0AWebsite%3A%0ATop%203%20competitors%3A%0AWhat%20buyers%20ask%20before%20choosing%20you%3A%0A">Book the audit</a>
            <a class="secondary-action" href="#score">Score your gap</a>
            <a class="secondary-action" href="https://github.com/jerednel/answerproof" target="_blank" rel="noreferrer">View checklist</a>
        </div>
    </div>
</section>

<section class="answerproof-band">
    <div class="section-label"><span class="prompt">$</span> offer</div>
    <div class="answerproof-offer-grid">
        <div class="answerproof-panel">
            <h2>What you get</h2>
            <ul class="answerproof-list">
                <li>Prompt map for high-intent buyer questions across your category.</li>
                <li>Competitor citation table across ChatGPT, Perplexity, Gemini, and Google AI surfaces.</li>
                <li>Source audit showing which pages, entities, schema, and third-party mentions shape the answers.</li>
                <li>30-day action plan ranked by revenue relevance and implementation effort.</li>
            </ul>
        </div>
        <div class="answerproof-panel">
            <h2>Who it is for</h2>
            <ul class="answerproof-list">
                <li>B2B SaaS teams with an existing category, not a brand-new market.</li>
                <li>Founders, CMOs, and growth leads who already care about SEO and conversion.</li>
                <li>Teams that suspect traditional rankings are no longer the whole discovery path.</li>
                <li>Companies with 2 to 5 named competitors buyers regularly compare.</li>
            </ul>
        </div>
    </div>
</section>

<section class="answerproof-band">
    <div class="section-label"><span class="prompt">$</span> packages</div>
    <div class="pricing-grid">
        <article class="price-card">
            <div class="price-label">Diagnostic</div>
            <h2>$1,500</h2>
            <p>One-time audit, delivered as a buyer-question map, competitor citation report, and prioritized fixes.</p>
            <a href="mailto:jerednel@gmail.com?subject=Answerproof%20Diagnostic">Start diagnostic</a>
        </article>
        <article class="price-card featured-price">
            <div class="price-label">Monitor</div>
            <h2>$2,500/mo</h2>
            <p>Monthly prompt tracking, answer-drift review, source-gap analysis, and implementation planning.</p>
            <a href="mailto:jerednel@gmail.com?subject=Answerproof%20Monitor">Start monthly</a>
        </article>
        <article class="price-card">
            <div class="price-label">Build</div>
            <h2>$5,000/mo</h2>
            <p>Everything in Monitor plus done-with-you technical SEO, schema, content briefs, and citation work.</p>
            <a href="mailto:jerednel@gmail.com?subject=Answerproof%20Build">Talk scope</a>
        </article>
    </div>
</section>

<section id="score" class="answerproof-band">
    <div class="section-label"><span class="prompt">$</span> self-check</div>
    <div class="score-tool">
        <div>
            <h2>Is this worth checking now?</h2>
            <p>
                This quick score is intentionally blunt. If the total is high, the risk is not
                abstract brand awareness. It is buyers asking AI for vendor shortlists and seeing
                somebody else first.
            </p>
        </div>
        <form class="score-form" data-answerproof-score>
            <label>
                <span>Competitor comparisons matter in your sales cycle</span>
                <input type="range" min="0" max="5" value="3" name="comparisons">
            </label>
            <label>
                <span>Your category has informational searches before demos</span>
                <input type="range" min="0" max="5" value="3" name="research">
            </label>
            <label>
                <span>Your current SEO content is strong but generic</span>
                <input type="range" min="0" max="5" value="2" name="content">
            </label>
            <label>
                <span>You do not know which sources AI answers cite</span>
                <input type="range" min="0" max="5" value="4" name="citations">
            </label>
            <output class="score-output" data-score-output>14 / 20: worth a first audit</output>
        </form>
    </div>
</section>

<section class="answerproof-band">
    <div class="section-label"><span class="prompt">$</span> why me</div>
    <div class="answerproof-proof">
        <p>
            This sits at the intersection of work I already do: technical SEO, data engineering,
            operator-style diagnosis, and testing AI systems as systems rather than demos. The
            deliverable is not a dashboard dump. It is a ranked answer to one expensive question:
            what should change this month so more qualified buyers see you in AI-mediated search?
        </p>
        <a class="section-link" href="mailto:jerednel@gmail.com?subject=Answerproof%20audit">Send me your site</a>
    </div>
</section>

<script>
    const scoreForm = document.querySelector('[data-answerproof-score]');
    const scoreOutput = document.querySelector('[data-score-output]');

    if (scoreForm && scoreOutput) {
        const updateScore = () => {
            const values = Array.from(scoreForm.querySelectorAll('input[type="range"]'));
            const total = values.reduce((sum, input) => sum + Number(input.value), 0);
            let message = 'monitor, but do not buy yet';
            if (total >= 14) message = 'worth a first audit';
            if (total >= 17) message = 'high-risk gap';
            scoreOutput.textContent = `${total} / 20: ${message}`;
        };

        scoreForm.addEventListener('input', updateScore);
        updateScore();
    }
</script>
