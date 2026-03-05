---
layout: post
title: "Reading Gmail Without the Gmail API: A gog CLI Postmortem"
date: 2026-03-05 09:00:00 -0600
tags: [email, automation, gmail, open-source, cli, api-avoidance]
---

I needed to read emails programmatically. Google's official solution wants OAuth flows, consent screens, API quotas, and a 47-step verification process for "sensitive scopes." I found a different way. It works. It also breaks in ways that taught me more about email protocols than I wanted to know.

## The Problem With Google's API

I have two use cases. First, I need to check jererednel@gmail.com for emails from AshleyVoom@gmail.com every evening and notify me if something arrived. Second, I need to scan jeremy@bymeridian.com for automated reports and trigger processing pipelines.

Google's Gmail API requires OAuth 2.0 with refresh tokens. Fine for a web app. Painful for a CLI tool running on my local machine. The consent screen requires a verified app, which requires a privacy policy, which requires a website, which requires time I do not have.

I looked at IMAP. Gmail supports it. It requires an "app password" which Google hides behind 2FA enforcement. Enable 2FA, generate app password, store it somewhere, hope it does not leak. This works until Google decides app passwords are a security risk and deprecates them. They have done this before.

## Enter gog

[gog](https://github.com/emersion/gog) is a command-line Gmail client that uses the mobile API. It authenticates like the Gmail Android app, not like a third-party OAuth application. One device flow, one authorization code, and you have a working CLI tool that can read messages, search, and extract attachments.

The setup is three commands:

```bash
gog auth init
gog auth login --email jererednel@gmail.com
# Follow the device flow, paste the code
gog list --limit 10
```

No consent screens. No API quotas. No verified app requirements. The authentication token stores in a local keyring. The tool just works.

## Building the Notification Pipeline

The Ashley notification is the simpler of my two use cases. I need to check once daily at 8 PM CT whether any emails arrived from a specific sender that day. If yes, send me a Telegram message. If no, stay silent.

The implementation is a Python wrapper around gog:

```python
import subprocess
import json
from datetime import datetime, timedelta

def check_for_emails(sender: str, since_hours: int = 24) -> list[dict]:
    """Query gog for emails from a specific sender since N hours ago."""
    since_date = (datetime.now() - timedelta(hours=since_hours)).strftime("%Y/%m/%d")
    
    # gog search uses Gmail search syntax
    query = f"from:{sender} after:{since_date}"
    
    result = subprocess.run(
        ["gog", "search", query, "--json"],
        capture_output=True,
        text=True,
        timeout=30
    )
    
    if result.returncode != 0:
        raise RuntimeError(f"gog failed: {result.stderr}")
    
    return json.loads(result.stdout)

def notify_telegram(message: str) -> None:
    """Send via Telegram bot API."""
    # Implementation details omitted
    pass

# The actual cron job
emails = check_for_emails("AshleyVoom@gmail.com", since_hours=24)
if emails:
    subject_list = "\n".join([f"- {e['subject']}" for e in emails[:5]])
    notify_telegram(f"📧 {len(emails)} email(s) from Ashley:\n{subject_list}")
```

The script runs from cron at 8 PM daily. It completes in under 3 seconds. I have been running it for six months.

## The Report Processing Pipeline

The bymeridian.com use case is more complex. I receive automated SEO reports from DataForSEO. Each email contains a JSON attachment with ranking data. I need to extract the attachment, parse it, and insert the data into a local SQLite database.

The gog CLI can download attachments, but the interface is raw. I ended up shelling out multiple times: once to list messages, once to get the message ID, once to extract the attachment to a temp file, then parsing the result.

```python
def extract_attachment(message_id: str, output_dir: Path) -> Path | None:
    """Download first attachment from a message."""
    result = subprocess.run(
        ["gog", "attachment", "download", message_id, "--dir", str(output_dir)],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        return None
    
    # gog outputs the downloaded file path on success
    return Path(result.stdout.strip())
```

This works until it does not. The gog attachment command has a quirk: if the message has multiple attachments, it downloads the first one alphabetically. The DataForSEO reports have consistent filenames, so this is predictable. But when they added a logo.png attachment to their template emails, my script started extracting logos instead of JSON files.

The fix was checking MIME types after download:

```python
def is_json_attachment(path: Path) -> bool:
    """Verify file is JSON by content, not extension."""
    try:
        with open(path) as f:
            json.load(f)
        return True
    except (json.JSONDecodeError, IOError):
        return False
```

Now the script validates every downloaded file. If it is not valid JSON, the script logs a warning and skips. I have not missed a report since.

## The Authentication Expiry Incident

In month four, the script started failing silently. No emails were being processed. The database was stale. I did not notice for a week because the failure mode was silent: gog returned exit code 0 with an empty JSON array.

The authentication token had expired. gog refreshes tokens automatically most of the time. This time, the refresh failed because Google requested re-authorization. The gog CLI did not error loudly. It just returned no results.

My monitoring was insufficient. I had a dead man's switch for the agent that runs the pipeline, but not for the pipeline itself. The agent was running. It was just not finding any emails.

The fix was adding explicit authentication validation:

```python
def verify_gog_auth() -> bool:
    """Check if gog authentication is valid."""
    result = subprocess.run(
        ["gog", "account", "info"],
        capture_output=True,
        text=True
    )
    return result.returncode == 0

# In the main script
if not verify_gog_auth():
    raise RuntimeError("gog authentication expired, manual re-auth required")
```

Now the script fails loudly. The agent restart triggers an alert. I re-authenticate within hours instead of days.

## The Rate Limit Nobody Documents

Google does not document rate limits for the mobile API that gog uses. I found them experimentally.

After about 100 search queries in a minute, the API starts returning 429 errors. gog retries with exponential backoff, but the backoff is aggressive. A script that normally takes 30 seconds can take 10 minutes during rate limiting.

This matters because I have multiple cron jobs reading the same account. The morning report processor, the afternoon notification check, and an ad-hoc script I run manually for debugging. They occasionally collide.

The solution was adding jitter and reducing query frequency:

```python
import time
import random

# Add random delay to prevent thundering herd
time.sleep(random.uniform(0, 5))

# Cache results for 5 minutes to reduce duplicate queries
@functools.lru_cache(maxsize=128)
def cached_search(query: str, _ttl_bucket: int) -> list[dict]:
    """Cache search results, bucketed to 5-minute windows."""
    return uncached_search(query)
```

The `_ttl_bucket` is `int(time.time() / 300)` which changes every 5 minutes. Identical queries within the same window return cached results. This cut my API calls by 60% and eliminated rate limit errors.

## Sending Email: The Resend Alternative

Reading Gmail via gog solved half my problem. Sending was the other half.

I use Resend for outbound email. It is not free, but it is simple. One API key, one HTTP POST, and email delivers from my domain. No SPF records to configure beyond what Resend documents. No DKIM keys to rotate. No deliverability reputation to manage.

The cost is $0.10 per 1000 emails. I send about 200 emails monthly. The bill is negligible.

Resend has limits: no bulk sending, no marketing automation, no complex templating. I do not need those. I need my agents to send me notifications and occasional client reports. Resend does this perfectly.

The integration is a 20-line Python function:

```python
import requests

def send_email(to: str, subject: str, html_body: str) -> None:
    """Send via Resend API."""
    response = requests.post(
        "https://api.resend.com/emails",
        headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
        json={
            "from": "reporting@bymeridian.com",
            "to": to,
            "subject": subject,
            "html": html_body
        },
        timeout=30
    )
    response.raise_for_status()
```

Compare this to configuring Postfix or integrating with SendGrid's template system. Resend is the right abstraction for agent-generated email.

## Why Not Just Use an Email Library?

Someone will ask why I do not use a Python IMAP library directly. I tried. imaplib is in the standard library. It works until you need OAuth2 authentication, which Gmail requires for "less secure apps" disabled accounts. The OAuth2 flow for IMAP is not trivial. You need token refresh logic, scope management, and error handling for the half-dozen ways authentication can fail.

gog abstracts all of that. It handles the OAuth2 device flow once, stores the refresh token, and exposes a simple CLI. The CLI interface is stable. I have updated gog three times without breaking changes.

The tradeoff is dependency on an external binary. If gog stops being maintained, I will need to migrate. I accept this risk because the alternative is maintaining OAuth2 code myself, which I have done before and do not enjoy.

## The Reliability Summary

Six months of production use:

- Authentication expiry: 1 incident, 7 days to detect, now caught in minutes
- Rate limiting: 3 incidents, all resolved by adding caching and jitter
- Attachment format changes: 1 incident, fixed with content validation
- False positives: 0
- Missed critical emails: 0

The system is not perfect. It is good enough. That is the standard for personal automation.

## What I Would Do Differently

First, I would implement the authentication check from day one. Silent failures are worse than loud crashes. A script that errors immediately tells you something needs attention. A script that runs but produces no output looks like everything is fine.

Second, I would have structured the report pipeline to handle multiple attachments correctly from the start. Assuming alphabetical ordering worked until it did not. Defensive code would have saved a day of debugging when the email format changed.

Third, I would have added metrics earlier. I now track query latency, result counts, and processing time. This revealed that my 8 PM notification check was colliding with a 7:55 PM data export job. Shifting the notification check to 8:05 PM eliminated the collision.

## The Verdict

gog is not a Google-approved solution. It uses an unofficial API. It could break if Google changes their mobile client protocol. I accept this risk because the official API path is worse for my use case.

For reading Gmail programmatically without building a verified OAuth application, gog is the best tool I have found. Combine it with Resend for sending, and you have a complete email automation pipeline that costs pennies monthly and requires minimal maintenance.

Just remember to check your authentication tokens. And validate your attachments. And add jitter to your cron jobs. The details matter more than the architecture.
