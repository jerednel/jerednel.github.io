---
layout: post
title: "Why I Stopped Using Browser Automation for APIs"
date: 2026-02-19 15:00:00 -0600
tags: [automation, apis, web-scraping, python, ai]
---

I used to love browser automation. Give me a website without an API, and I'd fire up Selenium or Playwright and make it bend to my will. Login forms? No problem. JavaScript-heavy dashboards? Child's play. CAPTCHAs? ...Okay, that's where things got messy.

But over the years, I've quietly retired most of my browser automation scripts. Not because I don't need the data anymore, but because I learned a hard truth: browser automation is the tool of last resort, not the first choice.

## The Siren Song of "It Just Works"

Browser automation is seductive. You open a page, you click a button, you scrape some data. It mirrors how a human would do it, so it feels intuitive. And for quick, one-off tasks, it's genuinely useful.

But then you deploy it to production.

The website changes a CSS class. Your selector breaks at 2 AM. You wake up to 400 error emails and an angry Slack channel. This happened to me more times than I care to admit. The web is a moving target, and browser automation is a brittle way to hit it.

## The Hidden Costs Nobody Talks About

**Resource overhead is brutal.** A headless browser is essentially a full Chrome instance. Running 50 concurrent scraping jobs? That's 50 copies of Chrome eating RAM like it's going out of style. Compare that to 50 HTTP requests using `requests` or `httpx`—same data, fraction of the resources.

**Speed becomes a real problem.** A browser has to download CSS, execute JavaScript, render the DOM, wait for network calls to finish. An API call? Milliseconds. A browser session? Seconds, sometimes tens of seconds. Scale that difference, and your "simple" data pipeline becomes a bottleneck.

**Debugging is a nightmare.** When an API returns a 403, you know exactly what happened. When a browser script fails, it could be a timing issue, a selector change, a popup modal, a slow-loading element, or the moon being in the wrong phase. I've spent hours debugging scripts that worked yesterday and mysteriously broke today.

## The API-First Awakening

My turning point came on a project where I needed to extract data from a SaaS platform. I immediately reached for Playwright, built the scraper, and celebrated my victory. Then the platform released a public API two months later.

I rewrote the integration in an afternoon. The new version was 50x faster, used 10% of the resources, and had zero maintenance issues in the following year. The browser automation version had required 47 patches for "website changed" issues.

Now, my default approach is:

1. **Look for an API first.** Even if it's undocumented or requires authentication. Check the network tab in DevTools—many "API-less" sites actually expose internal endpoints.
2. **Reverse-engineer the API.** If there's no official API, inspect the XHR requests. Modern SPAs usually call REST or GraphQL endpoints you can replicate.
3. **Browser automation only when necessary.** JavaScript rendering that can't be bypassed, complex user interactions, or sites with aggressive bot detection.

## When Browser Automation Still Makes Sense

I'm not saying never use it. There are valid use cases:

- **Testing your own applications.** Playwright and Selenium are still the gold standard for end-to-end testing.
- **Sites that aggressively block programmatic access.** Some financial institutions and government sites make it genuinely hard to use anything else.
- **Complex workflows requiring visual verification.** If a human needs to see what's happening, automation might be the only option.

But these are exceptions, not the rule.

## The Lesson That's Stuck With Me

Browser automation is a power tool. It's heavy, dangerous, and leaves a mess. APIs are the scalpel—precise, efficient, predictable.

Every time I'm tempted to spin up a headless browser, I force myself to spend 30 minutes looking for an API-based solution. Nine times out of ten, I find one. And that tenth time? I document exactly why browser automation was necessary, because I know Future Me will wonder why I made that choice.

The best automation is the kind you can forget about. It runs, it works, it doesn't wake you up at night. Browser automation rarely meets that standard. APIs usually do.

Choose accordingly.
