---
layout: post
title: "Building a Ranking Monitor with DataForSEO and Google Search Console (And Why I Need Both)"
date: 2026-03-18
tags: [seo, data-engineering, dataforseo, gsc, python, pipeline, debugging]
---

I spent two weeks trying to answer a simple question: which of my pages are ranking but not converting clicks? That question turned into a pipeline. This is the build log.

## The Problem With Using Either Source Alone

Google Search Console gives you clicks, impressions, CTR, and position -- data Google chooses to share, with the sampling and (not provided) caveats baked in. DataForSEO's SERP API gives you an independent position check against a real live search result. They're measuring different things.

GSC position is an average. If your page ranks position 3 on Monday and position 12 on Thursday, GSC shows something like 7.5. DataForSEO gives you what's actually there right now when you query it. Neither is ground truth. Together they triangulate.

The use case I was building for: find keywords where GSC shows high impressions and low CTR, then cross-reference with DataForSEO to see if the actual SERP position matches what GSC claims. If GSC says you're at position 4 with a 1.2% CTR, but DataForSEO shows you're in a featured snippet at position 1, the CTR problem is probably the meta description or title, not rank. That's a different fix than "rank higher."

## Stack

Running on meridian-platform (Hetzner VPS). Python scripts, DataForSEO REST API, GSC via OAuth token managed by `gsc-oauth`, results stored locally as JSON and summarized through OpenClaw sessions over Telegram.

No database. Flat files for now. That was a deliberate call -- I wanted to iterate fast without managing schema migrations while I was still figuring out what questions I actually wanted to ask.

## Phase 1: Pull GSC Data

The GSC API authentication was the first pain point. `gsc-oauth` manages the OAuth token refresh, but the credentials file path needs to be explicit or it silently tries the wrong location and returns an empty result set instead of an auth error. I lost about an hour to that.

```python
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
import json, os

TOKEN_PATH = "/path/to/gsc-oauth/token.json"
creds = Credentials.from_authorized_user_file(TOKEN_PATH)
service = build("searchconsole", "v1", credentials=creds)

body = {
    "startDate": "2026-02-15",
    "endDate": "2026-03-15",
    "dimensions": ["query", "page"],
    "rowLimit": 1000
}

response = service.searchanalytics().query(
    siteUrl="https://jerednel.github.io",
    body=body
).execute()
```

Empty `rows` key in the response means one of three things: no data in that range, wrong site URL format (trailing slash matters), or a silent auth failure. I added explicit error logging before assuming the data was actually empty.

The GSC data shape I cared about: query, page, clicks, impressions, CTR, position. I filtered to queries with impressions > 50 to avoid noise, and CTR < 3% as the signal for underperformers.

## Phase 2: DataForSEO Position Check

DataForSEO's Live SERP endpoint is the right call here -- you get results back synchronously without managing task IDs. The tradeoff is cost per request, so I only queried the specific keywords that passed the GSC filter rather than a broad crawl.

```python
import requests
from base64 import b64encode

DATAFORSEO_LOGIN = "your-login"
DATAFORSEO_PASSWORD = "your-password"
auth = b64encode(f"{DATAFORSEO_LOGIN}:{DATAFORSEO_PASSWORD}".encode()).decode()

def check_serp_position(keyword, domain):
    payload = [{
        "keyword": keyword,
        "location_code": 2840,  # US
        "language_code": "en",
        "device": "desktop",
        "os": "windows"
    }]
    
    response = requests.post(
        "https://api.dataforseo.com/v3/serp/google/organic/live/regular",
        headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"},
        json=payload
    )
    
    data = response.json()
    items = data["tasks"][0]["result"][0]["items"]
    
    for item in items:
        if item.get("type") == "organic" and domain in item.get("domain", ""):
            return item.get("rank_absolute"), item.get("title"), item.get("description")
    
    return None, None, None
```

The response structure nests deeply: `tasks[0]["result"][0]["items"]` is where the SERP results live. I got a KeyError on the first run because one task returned a status code indicating the keyword returned no results (valid -- some queries have no organic results). Added a check for `tasks[0]["status_code"] == 20000` before assuming result data exists.

## Phase 3: The Join and What It Surfaces

The join is just a Python dict lookup -- keyword from GSC against DataForSEO result. The interesting cases:

**GSC shows position 8-15, DataForSEO shows position 1-3.** This happens more than I expected. It usually means a featured snippet or People Also Ask box that GSC counts as position 1 but users don't perceive as a "result." CTR tanks because the answer is visible without clicking. These pages aren't underperforming -- they're just the wrong format for the query intent.

**GSC shows position 3-5, DataForSEO shows position 15+.** This means DataForSEO caught a ranking drop that GSC's averaging has smoothed out. Worth investigating for technical issues or freshness problems.

**Both sources agree you're at position 6-10 with low CTR.** This is the cleaner signal: the title and meta description need work, or you're competing on a keyword where the top 5 results have rich snippets and yours is a bare blue link.

## The Output

I run the full pipeline weekly, output a JSON file with the comparison results, and have an OpenClaw session that summarizes the flagged keywords to Telegram. The summary prompt asks for the top 5 most actionable discrepancies, not a dump of everything -- otherwise the signal disappears in noise.

## What I'd Do Differently

The flat file approach worked for prototyping but it's getting unwieldy. The JSON files don't have consistent schemas across runs because I kept changing what I was capturing. A lightweight SQLite table with a fixed schema would have cost me an hour upfront and saved several hours of cleanup. Lesson relearned.

The DataForSEO cost on a filtered set is manageable -- I'm running roughly 40-60 keyword lookups per week after the GSC filter. If I expanded to a full site crawl without pre-filtering, the cost would scale linearly and get uncomfortable fast. The GSC pre-filter is doing real work here.

## What's Next

The thing I actually want to build is a version that runs automatically when I publish a new post -- check GSC impressions at 7, 14, and 30 days for any queries the post starts picking up, flag any that hit the high-impressions-low-CTR pattern early. The weekly batch works but the signal comes late. Early detection means fixing the title before the post has had six months to accumulate the wrong ranking.

That's a cron job with a trigger condition. Haven't built it yet.
