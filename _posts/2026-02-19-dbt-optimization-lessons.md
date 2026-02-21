---
layout: post
title: "The dbt Model That Taught Me Everything About Optimization"
date: 2026-02-19 14:00:00 -0600
tags: [dbt, data-engineering, sql, performance]
---

I once had a dbt model that took 47 minutes to run. It wasn't even doing anything complicated—just joining a few large tables, some aggregations, the usual stuff. But 47 minutes. For a single model.

That model became my optimization obsession. And the lessons I learned from fixing it have stuck with me through every dbt project since.

## The Usual Suspects Aren't Always the Problem

When a model is slow, most of us reach for the obvious fixes: add indexes, partition large tables, maybe switch to incremental materialization. These help, sure. But that 47-minute model? It already had all of that.

The real problem was hiding in plain sight: I was joining on the wrong grain.

I'd written something like this:

```sql
SELECT 
    orders.id,
    customers.name,
    SUM(order_items.amount) as total_amount
FROM orders
LEFT JOIN customers ON orders.customer_id = customers.id
LEFT JOIN order_items ON orders.id = order_items.order_id
GROUP BY 1, 2
```

Seems fine, right? Except `order_items` had 50 million rows, and `orders` had 2 million. The join was exploding my dataset before the aggregation could even happen.

The fix was embarrassingly simple:

```sql
WITH item_totals AS (
    SELECT 
        order_id,
        SUM(amount) as total_amount
    FROM order_items
    GROUP BY 1
)

SELECT 
    orders.id,
    customers.name,
    COALESCE(item_totals.total_amount, 0) as total_amount
FROM orders
LEFT JOIN customers ON orders.customer_id = customers.id
LEFT JOIN item_totals ON orders.id = item_totals.order_id
```

Runtime: 47 minutes → 3 minutes.

## Incremental Isn't Free

Incremental models feel like magic. "Only process new data!" But they're also the easiest way to build technical debt in dbt.

Here's what I learned the hard way: incremental models need to handle late-arriving data gracefully. If you're just appending rows based on `updated_at`, you're going to have bad data.

Now, every incremental model I write includes a lookback window:

```sql
{% raw %}
{% if is_incremental() %}
WHERE updated_at >= (SELECT MAX(updated_at) - INTERVAL '3 days' FROM {{ this }})
{% endif %}
{% endraw %}
```

Yes, you're reprocessing some rows. But you're also catching the ones that trickle in late because of API delays, timezone issues, or that one microservice that takes its sweet time.

## The `ref()` Trap

Early in my dbt journey, I treated `ref()` as just a way to reference other models. I'd chain models together without much thought—model A refs B, B refs C, C refs D.

Then I noticed my DAG looked like a plate of spaghetti and my runs were taking forever because everything was bottlenecked through a few central models.

The fix? I started thinking about my DAG as an actual data pipeline, not just a dependency graph.

- **Staging models** should be thin transformations directly on sources
- **Intermediate models** handle complex joins and business logic
- **Mart models** are clean, final outputs for end users

If a model has more than 3-4 `ref()` calls, I pause and ask: should this be split? Am I cramming too much logic into one place?

## Test Everything, But Test Smart

I used to write tests like this:

```yaml
- name: id
  tests:
    - unique
    - not_null
```

On every single column. In every model. My test suite took 25 minutes to run.

Now I'm more surgical:

- **Unique/not_null** only on primary keys and truly critical fields
- **Relationships** tests only where referential integrity actually matters
- **Custom tests** for business rules that will break things if they fail

The goal isn't perfect test coverage—it's catching the bugs that would actually hurt someone.

## The 80/20 Rule of Model Performance

After optimizing dozens of models, I've noticed a pattern: 80% of your runtime comes from 20% of your models. You can spend hours shaving seconds off small models, or you can find the big ones and fix them.

Use `dbt run --profile-target dev` and look at the execution times. If a model takes more than 5 minutes, it deserves attention. Not because 5 minutes is too long, but because models that slow usually have fundamental issues—bad joins, missing partitions, or logic that belongs elsewhere.

## Final Thought

That 47-minute model taught me that dbt optimization isn't about memorizing tricks or following a checklist. It's about understanding your data: its shape, its size, how it flows through your pipeline.

The best dbt models I've written aren't the cleverest ones. They're the ones that get the job done simply, run fast enough that nobody complains, and can be understood by the next engineer who has to maintain them at 2 AM during an outage.

Sometimes boring is the ultimate optimization.
