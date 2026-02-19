---
layout: post
title: "How I Cut Our dbt Runtime by 80% Using These 3 Patterns"
date: 2026-02-19 15:00:00 -0600
tags: [dbt, data-engineering, sql, performance, optimization]
---

Our dbt project had a problem. A 6-hour runtime problem.

Every morning, the data team would kick off our dbt run at 5 AM and cross our fingers that it finished before the CEO's 9 AM dashboard check. Most days it worked. Some days it didn't. And the worst part? We were only processing about 2 TB of data. This shouldn't have been that hard.

Here's how I cut our runtime from 6 hours to 72 minutes—and the three patterns that made the biggest difference.

---

## Pattern 1: Pre-Aggregate Before You Join

This was our biggest sin. We had a core `fct_orders` model that joined orders, line items, customers, products, and promotions. It was the Swiss Army knife of models—everyone used it, and it took 47 minutes to build.

The problem? We were joining 50 million line items to 2 million orders *before* aggregating. Classic fan-out problem.

**Before (47 minutes):**

```sql
SELECT 
    orders.order_id,
    orders.customer_id,
    customers.customer_name,
    products.category,
    promotions.promotion_name,
    SUM(order_items.quantity) as total_quantity,
    SUM(order_items.sale_price) as total_revenue,
    COUNT(DISTINCT order_items.product_id) as unique_products
FROM orders
LEFT JOIN order_items ON orders.order_id = order_items.order_id
LEFT JOIN customers ON orders.customer_id = customers.customer_id
LEFT JOIN products ON order_items.product_id = products.product_id
LEFT JOIN promotions ON orders.promotion_id = promotions.promotion_id
GROUP BY 1, 2, 3, 4, 5
```

**After (3 minutes):**

```sql
-- Aggregate first, join after
WITH order_metrics AS (
    SELECT 
        order_id,
        SUM(quantity) as total_quantity,
        SUM(sale_price) as total_revenue,
        COUNT(DISTINCT product_id) as unique_products
    FROM order_items
    GROUP BY 1
),

order_products AS (
    SELECT DISTINCT
        order_id,
        FIRST_VALUE(product_id) OVER (
            PARTITION BY order_id 
            ORDER BY sale_price DESC
        ) as primary_product_id
    FROM order_items
)

SELECT 
    orders.order_id,
    orders.customer_id,
    customers.customer_name,
    products.category,
    promotions.promotion_name,
    order_metrics.total_quantity,
    order_metrics.total_revenue,
    order_metrics.unique_products
FROM orders
LEFT JOIN order_metrics ON orders.order_id = order_metrics.order_id
LEFT JOIN order_products ON orders.order_id = order_products.order_id
LEFT JOIN customers ON orders.customer_id = customers.customer_id
LEFT JOIN products ON order_products.primary_product_id = products.product_id
LEFT JOIN promotions ON orders.promotion_id = promotions.promotion_id
```

By aggregating `order_items` before joining, we reduced the row count from 50 million to 2 million for the main join. That one change saved 44 minutes.

---

## Pattern 2: Smart Incremental Lookback Windows

We'd been burned by late-arriving data before. An API delay would mean yesterday's orders wouldn't show up, and someone would notice when their morning report looked wrong.

Our "solution" was to rebuild everything from scratch every day. Safe? Yes. Fast? Absolutely not.

The fix was a smarter incremental strategy with a lookback window:

```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        partition_by={
            'field': 'created_at',
            'data_type': 'timestamp',
            'granularity': 'day'
        }
    )
}}

WITH source_data AS (
    SELECT *
    FROM {{ source('sales', 'orders') }}
    
    {% if is_incremental() %}
    -- Look back 3 days to catch late arrivals
    WHERE updated_at >= (
        SELECT DATEADD(day, -3, MAX(updated_at)) 
        FROM {{ this }}
    )
    {% endif %}
),

-- rest of model...
```

Yes, we reprocess 3 days of data every run. But that's ~6,000 rows instead of 2 million. The trade-off is obvious.

---

## Pattern 3: The Staging → Intermediate → Mart Pipeline

Our DAG used to look like a bowl of spaghetti. Models referenced other models that referenced other models in a tangled mess. Changing one staging model would trigger 40 downstream models—not because they needed to rebuild, but because the dependencies were a mess.

We restructured everything into three clear layers:

**Staging models** (`stg_*`): Thin, 1:1 transformations on source tables. No joins, no aggregations, just clean column names and types.

```sql
-- stg_orders.sql
SELECT
    id as order_id,
    user_id as customer_id,
    created_at,
    updated_at,
    status,
    total_amount,
    promotion_id
FROM {{ source('sales', 'orders') }}
WHERE deleted_at IS NULL
```

**Intermediate models** (`int_*`): Business logic, complex joins, aggregations. These are internal building blocks.

```sql
-- int_order_enriched.sql
SELECT
    orders.*,
    customers.customer_name,
    customers.customer_segment
FROM {{ ref('stg_orders') }} orders
LEFT JOIN {{ ref('stg_customers') }} customers 
    ON orders.customer_id = customers.customer_id
```

**Mart models** (`fct_*`, `dim_*`): Final, user-facing tables. Clean, simple, purpose-built.

This separation meant we could run staging models independently, cache intermediate results, and parallelize much more effectively. Our DAG went from 40 models running in a messy sequence to 12 parallel tracks that converged at the end.

---

## The Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Total runtime | 6h 12m | 1h 12m | **-81%** |
| Longest model | 47m | 4m | **-91%** |
| Models >5 min | 8 | 1 | **-88%** |
| Daily cost | ~$45 | ~$9 | **-80%** |

The best part? These changes were mostly structural, not algorithmic. We didn't need to rewrite everything or buy a bigger warehouse. We just stopped doing obviously inefficient things.

---

## One Last Thing

The temptation after a win like this is to keep optimizing. Shave another 10 minutes! Get it under an hour!

I stopped at 72 minutes. Why? Because the data is ready before the CEO checks it. Because the team trusts the incremental loads now. Because 72 minutes of well-structured, maintainable code beats 60 minutes of clever hacks that nobody understands.

Sometimes good enough is exactly right.
