---
layout: post
title: "My $5 Semantic Search Setup Outperformed Elastic. Here's the Bill of Materials."
date: 2026-02-25 09:00:00 -0600
tags: [data-engineering, search, embeddings, sqlite, vector-database]
---

I had 12,000 notes spread across Notion, Obsidian, and random Markdown files. Finding anything required remembering where I put it and what I called it. Keyword search failed constantly. I would search for "database migration" and miss the note titled "postgres upgrade playbook" that had exactly what I needed.

I considered ElasticSearch. I even started setting it up. Then I saw the resource requirements and the learning curve and the operational overhead. For personal use, it felt like buying a freight truck to carry groceries.

So I built something smaller. It costs $5 per month to run, searches 12,000 documents in under 100ms, and requires zero maintenance. It also failed spectacularly three times before it worked.

## The Architecture That Actually Stuck

The final stack is almost embarrassingly simple:

- **OpenAI text-embedding-3-small** for embeddings ($0.02 per 1M tokens)
- **SQLite with sqlite-vec** for vector storage (free, runs anywhere)
- **A 200-line Python script** for indexing and querying
- **A single $5/month VPS** for hosting

Total monthly cost: roughly $2.50 in API calls plus $5 for the server. The whole thing fits in 150MB of RAM.

But getting here required failing through three more complex designs first.

## Failure One: The Pinecone Trap

My first instinct was to use a "real" vector database. I signed up for Pinecone, loaded my embeddings, and built a query interface. It worked great for a week.

Then I got the bill: $70 for 12,000 vectors. I had misread the pricing. Pinecone charges for storage and query volume in ways that scale poorly for small, high-query use cases. My personal search habit (dozens of queries per day) was expensive because I was not sharing costs across a large user base.

I also realized I had created a dependency. If Pinecone changed pricing, had an outage, or shut down, my search was dead. For a business, that risk might be worth the managed service benefits. For personal infrastructure, it felt wrong.

Lesson: managed services optimize for scale you do not have. Do the math before you commit.

## Failure Two: The Full-Text Red Herring

After Pinecone, I tried a different approach. SQLite has full-text search built in. FTS5 is fast and battle-tested. Maybe I did not need vectors at all. Maybe good old-fashioned inverted indexes would work if I just tuned them right.

I spent three days building stemming pipelines, synonym lists, and relevance scoring. I tested it on 500 documents. It was okay. Then I tested it on the full 12,000.

The problem was not speed. FTS5 was plenty fast. The problem was semantic mismatch. I would search "how do I handle duplicate rows" and get results about SQL duplicate elimination. What I wanted was a note about idempotency patterns in data pipelines. The words did not match, but the meaning did.

I measured recall at 34%. That is, for 100 queries where I knew the right note existed, FTS5 found it 34 times. Embeddings on the same test set scored 87%.

Lesson: full-text search and semantic search solve different problems. Do not let nostalgia for simpler tech blind you to actual requirements.

## Failure Three: The Local-Only Mirage

Having rejected cloud vector databases and pure full-text search, I tried keeping everything local. No APIs, no servers, just a Python script and local models. Privacy-preserving, offline-capable, completely free.

I used sentence-transformers with the all-MiniLM-L6-v2 model. It worked. Embeddings were decent. Query latency was fine for one-off searches.

Then I tried to index the full corpus. My laptop fans spun up. The process took 4 hours. My CPU was pegged at 100% the entire time. The resulting model and embeddings consumed 2GB of disk space.

I told myself this was acceptable. Then I added 500 new notes and realized I needed to re-index everything. Another 4 hours. I started skipping updates because the cost was too high. The search became stale. I stopped trusting it.

Lesson: local models are not free. They cost time and electricity and friction. Factor in update frequency when you calculate total cost of ownership.

## The Working Design

The system I run now splits the difference. I use OpenAI's API for embeddings because it is fast (12,000 documents in 8 minutes) and cheap ($0.25 per full re-index). I store vectors locally in SQLite because it is portable, queryable with SQL, and requires no network round-trips at search time.

Here is the schema:

```sql
CREATE VIRTUAL TABLE embeddings USING vec0(
    document_id INTEGER PRIMARY KEY,
    embedding FLOAT[1536]
);

CREATE TABLE documents (
    id INTEGER PRIMARY KEY,
    title TEXT,
    content TEXT,
    source_path TEXT,
    modified_at TIMESTAMP
);
```

The sqlite-vec extension handles the vector operations. A query looks like this:

```sql
SELECT d.title, d.source_path, distance
FROM embeddings e
JOIN documents d ON e.document_id = d.id
WHERE embedding MATCH ?
ORDER BY distance
LIMIT 10;
```

The `?` is bound to a JSON array containing the query embedding. The whole thing runs in 40-90ms on my $5 VPS.

## The Indexing Pipeline

New and modified documents are detected by comparing file hashes. The indexer chunks large documents at paragraph boundaries (roughly 500 tokens per chunk), generates embeddings in batches of 100, and upserts to SQLite.

The chunking matters. Early versions indexed whole documents. A 5,000-word architecture decision record would get one embedding that poorly represented its specific sections. Chunking improved recall by 23% in my tests.

I also learned to deduplicate before embedding. I had 800 copies of meeting notes with the same template headers. Generating embeddings for identical text is literally burning money. A simple hash check saves about 15% of API costs.

## The Query Interface

I built a terminal interface with `rich` because that is where I live. It takes a query, embeds it via API call (60-120ms), runs the SQL search (40-90ms), and displays results with content snippets.

Total latency: 100-250ms end-to-end. Fast enough that I do not notice the delay.

I also exposed a simple HTTP API for integration with other tools. My Obsidian plugin can query it. So can a Raycast extension I wrote for quick desktop access.

## What I Measure

I track three metrics:

1. **Recall**: Did the right document appear in the top 5 results? Currently 87% on a held-out test set of 200 queries.
2. **Latency**: P95 query time is 180ms. P99 is 320ms.
3. **Cost**: Averaging $2.30/month in API calls plus the fixed $5 VPS.

I also log failed searches. When I query something and do not find what I need, I note what I was actually looking for. This feeds back into testing. Over three months, I have collected 47 failure cases that guide iterative improvements.

## The Tradeoffs I Accept

This setup is not perfect. I am sending document content to OpenAI, which is a privacy tradeoff I made consciously. If you are indexing sensitive material, local embeddings might be worth the cost despite the friction.

SQLite also has limits. It handles 12,000 documents fine. It would struggle with 12 million. At that scale, I would need a different tool. But scale limits that are 1000x above your actual usage are not real limits. They are theoretical constraints.

The system is also not distributed. If my VPS dies, search is down until I restore from backup. I accept this because the backup is a single SQLite file I copy to S3 nightly. Recovery takes 10 minutes, not 10 hours.

## What I Would Do Differently

If I started over today, I would skip the Pinecone and local model experiments. They taught me things, but I could have learned them from reading docs and doing back-of-the-envelope math. The time cost was real. I spent two weeks on approaches that were obviously wrong in retrospect.

I would also implement chunking from day one. It is not complex, and the quality improvement is significant. I wasted a month with subpar results because I was too lazy to handle document segmentation.

Finally, I would build the feedback logging immediately. The first version had no way to capture failures. I was flying blind, assuming search worked because it worked for me on the queries I happened to try. Systematic testing revealed the actual performance.

## The Bottom Line

You do not need ElasticSearch to search 12,000 documents. You do not need a managed vector database. You need embeddings, SQLite, and a few hundred lines of code.

The hard part is not the technology. It is accepting that simple solutions are valid, even when the industry is selling complexity. It is doing the math on actual costs instead of assuming managed services are cheaper. It is measuring whether your solution actually works instead of trusting architectural diagrams.

My $5 search setup is not impressive because it is cheap. It is impressive because it solves the problem completely, requires no maintenance, and leaves me alone to do actual work.

That is the real win. Not the technology. The absence of it.
