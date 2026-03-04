---
layout: post
title: "My Monthly Client Reports Took 4 Hours to Build. Now They Take Zero. Here Is What I Broke Along the Way."
date: 2026-03-04 09:00:00 -0600
tags: [data-engineering, automation, reporting, etl, resend]
---

Every month I send performance reports to twelve clients. The process used to take four hours: pulling data from three databases, normalizing schemas that never quite match, building charts in a spreadsheet, formatting an email, and sending it manually. I knew the exact steps because I had done them twenty times. That was the problem.

Four hours of repetitive work is not just expensive. It is fragile. I took a week off last August and came back to find that nobody had sent the July reports. The person covering for me got stuck on a SQL error and gave up. Clients noticed before we did.

I decided to automate the entire pipeline. The goal was zero human intervention: data to inboxes without me touching it. It took three attempts and one very embarrassing production failure to get there.

## Attempt One: The Big Script

My first approach was a single Python script. Connect to the databases, run the queries, build a pandas DataFrame, generate some HTML tables, and email the result. I scheduled it with cron for the first of every month.

It worked once. Then it failed on the second run because one database was in maintenance mode. The script crashed halfway through, sent no emails, and logged an error to a file I did not check for two days. The clients got their reports late. Again.

The fundamental problem was atomicity. The script was all-or-nothing. If any step failed, everything failed. There was no partial completion, no retry logic, no notification that something had gone wrong. Cron does not care if your job fails. It just runs the next time it is scheduled.

I tried adding error handling. Wrapped the database calls in try/except blocks, added logging, configured cron to email me on failure. This helped with visibility but did not solve the fragility. A failed report still meant manual intervention to figure out what happened and how to fix it.

## Attempt Two: The Pipeline Pattern

My second attempt split the process into discrete stages: extract, transform, generate, deliver. Each stage writes its output to a persistent location. If a stage fails, I can retry just that stage without rebuilding everything from scratch.

I built this with a simple state machine. A SQLite database tracks each report's progress through the pipeline. The extract stage pulls raw data and stores it as JSON. The transform stage reads that JSON, normalizes it, and writes clean data. The generate stage builds the HTML report. The deliver stage sends the email.

This worked better. When the same database went into maintenance, only the extract stage failed. I got a clear error message, fixed the connection string, and re-ran just that stage. The rest of the pipeline picked up where it left off.

But I introduced a new problem: state management complexity. The SQLite database needed migrations. I had to handle cases where a stage partially completed and left the database in an inconsistent state. One bug caused the transform stage to run twice, doubling all the metrics in the final report. A client caught the error and asked if their traffic had really increased 200% overnight.

Lesson learned: pipelines are better than monoliths, but state is the enemy. Keep it simple or invest in proper infrastructure.

## The Resend Integration That Almost Leaked Data

For email delivery, I chose Resend. The API is clean, the deliverability is good, and the pricing is reasonable for my volume. I built a simple wrapper that takes a report ID, looks up the recipient list, and sends the HTML.

I tested it with my own email address. It worked. I added the real client list and scheduled a dry run for the staging environment. That is when I almost made a catastrophic mistake.

My code looked like this:

```python
def send_report(report_id, recipients):
    report = load_report(report_id)
    for recipient in recipients:
        resend.Emails.send(
            from_email="reports@mydomain.com",
            to=recipient,
            subject=f"Monthly Report - {report.client_name}",
            html=report.html
        )
```

The bug was subtle. The `recipients` parameter was supposed to be a list of emails for one client. But my database query returned all recipients across all clients. I was about to send every client report to every client.

I caught this in the dry run because I logged the intended recipients before sending. The log showed 144 email addresses for a report that should have gone to 12 people. One loop iteration, one wrong variable, total data breach.

I fixed it by validating recipient counts against expected values and requiring explicit confirmation for any batch larger than the configured maximum. The pipeline now refuses to send if the recipient list looks wrong.

## The Timezone Disaster

My reports run on the first of every month. I scheduled the cron job for midnight on the first. Simple, right?

The first automated run happened at midnight UTC. My database timestamps are in America/Chicago. The query filtered for records where `created_at >= date_trunc('month', current_timestamp)`. At midnight UTC, that was February 28th in my timezone. The report included two days of February data and missed the last day of March.

Clients got reports with partial data. I got angry emails. The fix was simple once I understood the problem: run the job at 6 AM Central Time, well after the month has actually changed in my timezone. But I should have thought about this upfront. Timezones are not an edge case. They are the default case that everyone gets wrong once.

## The Final Architecture

Here is what runs now, reliably, every month:

1. **Extract**: Pull raw data from three sources, write to timestamped JSON files. If any source fails, retry with exponential backoff for up to 30 minutes. After that, alert and stop.

2. **Validate**: Check that the extracted data looks reasonable. Row counts within expected ranges. Date ranges cover the full previous month. No null values in required fields. Fail fast if validation fails.

3. **Transform**: Normalize schemas, calculate metrics, aggregate by client. Write clean data to Parquet files. Parquet is overkill for my volume but it handles schema evolution better than CSV.

4. **Generate**: Build HTML reports using Jinja2 templates. Each client gets a custom header but the same underlying data structure. Save reports to a dated directory.

5. **Preview**: On the first of the month, send reports only to me. I review them manually. This is the only human touchpoint.

6. **Deliver**: On the third of the month, send to clients. The two-day delay lets me catch issues before clients see them.

7. **Monitor**: A separate process checks that reports were sent. If any client is missing a report after the third, page me.

The whole pipeline is idempotent. I can re-run any stage for any month without side effects. This matters when a client asks for a corrected report three weeks later. I fix the data, re-run the pipeline for that month, and send an updated version.

## What I Would Do Differently

Start with validation. I added data quality checks late in the process. They should have been there from day one. Bad data is worse than no data because it erodes trust. Clients do not care about your pipeline architecture. They care that the numbers are right.

Use a proper scheduler from the start. Cron is fine for simple jobs but it has no concept of job dependencies or retry logic. I now use a lightweight orchestrator that understands the pipeline stages and handles failures gracefully.

Test with production-scale data. My early tests used small datasets that masked performance issues. The first full run took 45 minutes because I had not indexed a join properly. Test with real volume or you are not really testing.

The four hours I used to spend on reports are now mine. The system is not perfect. Last month a client changed their email domain and the report bounced. But the monitoring caught it, I fixed the address, and re-sent within an hour. That is the goal: not perfection, but fast recovery when things go wrong.
