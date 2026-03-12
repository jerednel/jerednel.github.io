---
layout: post
title: "Persistent Agent Memory with Mem0 and Qdrant on a $6 VPS"
date: 2026-03-12
tags: [ai, memory, qdrant, infrastructure, agents]
---

Most AI agent setups treat memory as an afterthought. You get a context window, maybe a few files the agent can read, and then you start over every session. That is fine for demos. It falls apart when your agent needs to know what it did last Tuesday.

I spent the last few weeks integrating Mem0 with a local Qdrant instance on my Hetzner VPS. Here is what the system actually looks like, where it broke, and what I changed.

## Why Qdrant on the Same Box

The easy path is a managed vector DB. Pinecone, Weaviate Cloud, whatever. You get an API key, you call it, done.

I went with Qdrant running locally at `127.0.0.1:6333` for a few reasons. First, latency. Embedding lookups on every agent turn add up fast if you are making a round trip to a remote endpoint. Second, cost. My Hetzner CX21 is already paid for. Adding a managed vector DB for a side project felt wasteful. Third, I own the data.

Qdrant runs in Docker. The deployment is one line:

```bash
docker run -d -p 6333:6333 -v /data/qdrant:/qdrant/storage qdrant/qdrant
```

The volume mount is the part people skip and then regret. Without it your vectors evaporate on container restart.

## Mem0 as the Abstraction Layer

Qdrant is the storage engine. Mem0 sits on top and handles the actual memory logic: storing facts, deduplicating near-duplicates, searching by semantic similarity, and returning ranked results.

The embedding model is OpenAI's `text-embedding-3-small`. It is cheap enough that I do not think about the cost, and accurate enough that semantic search returns sensible results. I initially tested `text-embedding-ada-002` but switched because the newer model handles short factual statements better, which is most of what agent memory looks like.

A stored memory is just a string plus metadata. Something like: "Jeremy prefers concise summaries in Telegram, not full markdown reports." That gets embedded and stored. On future turns, the agent's incoming message gets embedded and the top 9 semantically similar memories get injected into context automatically.

## The Auto-Recall Problem

The first version of this had no filtering. Every turn retrieved the top 9 memories regardless of relevance. When I was asking about an SEO report, I would get memories about blog post preferences and shipping addresses. Technically all "my" memories, but useless noise for the task at hand.

The fix was not complicated. Mem0 already supports relevance scoring. The problem was I was not paying attention to which memories were getting injected. Once I started logging what the auto-recall was actually returning, the irrelevant retrievals were obvious. The embedding distance for off-topic memories was noticeably higher -- they were making the cutoff because the pool was small, not because they were relevant.

I added a threshold. Memories below a certain similarity score get dropped even if the top-9 count is not hit. The result is that some turns inject fewer memories, which is fine. Better to have 3 relevant facts than 9 that include noise.

## Manual Search vs Auto-Recall

The system has both. Auto-recall fires on every turn with no explicit call required. Manual search (`memory_search`) is for when you need to look something specific up -- a past decision, a date, a previous workflow configuration.

I learned not to use manual search as a substitute for auto-recall. It sounds like the same thing but the usage pattern is different. Auto-recall is ambient context. Manual search is targeted retrieval for a specific question. If I am writing a script that uses a tool and I want to check whether I have notes on that tool's configuration, that is a manual search. If the agent just needs general context about who I am and what I care about, that is what auto-recall is for.

The failure mode I hit early: the agent was calling `memory_search` on every single turn as a reflex, before doing anything else. This doubled the latency on simple tasks and cluttered the tool call log. I updated the system prompt to clarify when each mode is appropriate and the behavior corrected.

## What Gets Stored

Not everything. This was a judgment call and I probably have not gotten it fully right yet.

Things that get stored: preferences, recurring workflows, project-level decisions, tool configurations that change. Things that do not: transient state, one-off facts that will be stale in a week, anything already in a config file.

The duplication problem is real. If you are not careful you end up with five memories that all say the same thing slightly differently. Mem0 does some deduplication automatically but it is not perfect. I do a manual cleanup pass every few weeks -- run `memory_list`, scan for near-duplicates, delete the older or weaker versions. Takes about five minutes and keeps the quality high.

## Current State

The system works well enough that I stopped thinking about it, which is usually the sign that something is working. The agent remembers project context, tool preferences, and past decisions across sessions without me re-explaining everything.

The Qdrant container has been running for about a month with no restarts and no data issues. The volume mount has been doing its job. Total memory footprint on the VPS is minimal.

If you are running agents on a single machine and not using local vector storage, you are either spending money you do not need to or accepting latency you do not have to. Qdrant is not complicated to run. The hard part is deciding what is worth remembering.
