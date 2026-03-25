---
layout: post
title: "Rust for Data Engineers: A Python-to-Rust Field Guide"
date: 2026-03-25 12:00:00 -0500
tags: [rust, python, data-engineering, tutorial, api, performance]
---

I spent a decade writing Python for data pipelines. ETL scripts, API integrations, data transformations—Python was the obvious choice. Then I hit the wall: a pipeline processing 10M+ records daily that couldn't finish in its 4-hour window. I rewrote the bottleneck in Rust. It finished in 12 minutes.

This isn't a "Rust is better" post. Python and Rust solve different problems. But if you're a data engineer hitting performance ceilings, dealing with deployment headaches, or just curious about what Rust offers, this guide will get you productive without the usual systems programming detours.

## What This Guide Assumes

You know Python. You've written data pipelines. You're comfortable with pandas, requests, and maybe some SQL. You don't know C, don't care about memory management theory, and want practical examples you can use tomorrow.

We'll cover:
- The mental model shift from dynamic to static typing
- Making HTTP requests and handling JSON
- Reading and writing CSV/Parquet files
- Building CLI tools that feel like Python scripts
- When to reach for Rust vs staying with Python

## Part 1: The Basics - From Python to Rust Syntax

### Variables and Types

In Python, you don't think about types:

```python
# Python
count = 42
name = "Meridian"
records = [{"id": 1, "value": 100}, {"id": 2, "value": 200}]
```

Rust requires explicit types, but the compiler usually infers them:

```rust
// Rust
let count = 42;                    // i32 (signed 32-bit integer)
let name = "Meridian";             // &str (string slice)
let records: Vec<Record> = vec![   // Vec is like Python's list
    Record { id: 1, value: 100 },
    Record { id: 2, value: 200 },
];
```

The `let` keyword declares a variable. By default, variables are **immutable**:

```rust
let count = 42;
count = 43;  // ERROR: cannot assign twice to immutable variable

let mut count = 42;  // 'mut' makes it mutable
count = 43;          // This works
```

This feels restrictive coming from Python, but it eliminates an entire class of bugs. Data pipelines often have configuration objects that shouldn't change mid-run—Rust enforces this at compile time.

### Functions

Python:
```python
def process_records(records, threshold=100):
    filtered = [r for r in records if r["value"] > threshold]
    return sum(r["value"] for r in filtered)
```

Rust:
```rust
fn process_records(records: &[Record], threshold: i32) -> i32 {
    records
        .iter()
        .filter(|r| r.value > threshold)
        .map(|r| r.value)
        .sum()
}
```

Key differences:
- `fn` instead of `def`
- Types on parameters: `records: &[Record]` (slice of Records)
- Return type after arrow: `-> i32`
- No `return` keyword needed for the last expression (but you can use it)

The `&[Record]` type is a **slice**—a view into an array or vector. It's like passing a Python list, but Rust knows at compile time what type of data it contains.

### Structs: Python Dictionaries with Teeth

Python dataclasses (or dictionaries):
```python
from dataclasses import dataclass

@dataclass
class Record:
    id: int
    value: int
    name: str = ""

record = Record(id=1, value=100, name="test")
```

Rust structs:
```rust
struct Record {
    id: i32,
    value: i32,
    name: String,  // Owned string (heap-allocated)
}

let record = Record {
    id: 1,
    value: 100,
    name: String::from("test"),
};
```

Rust has no default values in structs. If a field exists, you must provide it. For optional fields, use `Option<T>`:

```rust
struct Record {
    id: i32,
    value: i32,
    name: String,
    metadata: Option<String>,  // Might be None/Some
}

let record = Record {
    id: 1,
    value: 100,
    name: String::from("test"),
    metadata: None,  // or Some(String::from("extra data"))
};
```

## Part 2: Making HTTP Requests

Python's `requests` library sets a high bar for ergonomics. Rust's ecosystem is more fragmented, but `reqwest` comes closest:

```toml
# Cargo.toml
[dependencies]
reqwest = { version = "0.11", features = ["json"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### A Simple GET Request

Python:
```python
import requests

response = requests.get("https://api.example.com/data")
data = response.json()
print(f"Got {len(data)} records")
```

Rust:
```rust
use reqwest;
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct ApiResponse {
    records: Vec<Record>,
    total: i32,
}

#[derive(Deserialize, Debug)]
struct Record {
    id: i32,
    value: i32,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = reqwest::Client::new();
    
    let response: ApiResponse = client
        .get("https://api.example.com/data")
        .send()
        .await?
        .json()
        .await?;
    
    println!("Got {} records (total: {})", response.records.len(), response.total);
    
    Ok(())
}
```

Yes, there's more boilerplate. But notice:
- `#[derive(Deserialize)]` automatically maps JSON to your struct
- The `?` operator propagates errors—like Python exceptions, but explicit
- `async`/`await` works similarly to Python's asyncio

### Error Handling: The ? Operator

In Python, you handle errors with try/except:
```python
try:
    response = requests.get(url)
    response.raise_for_status()
    data = response.json()
except requests.RequestException as e:
    print(f"Request failed: {e}")
    return None
```

Rust uses `Result<T, E>` for operations that can fail. The `?` operator is syntactic sugar for "if this failed, return the error immediately":

```rust
let response: ApiResponse = client
    .get(url)
    .send()           // Returns Result<Response, reqwest::Error>
    .await?          // If Err, return Err; if Ok, continue
    .json()          // Returns Result<ApiResponse, reqwest::Error>
    .await?;         // If Err, return Err; if Ok, continue
```

This is more verbose than Python, but you always know what can fail. In a data pipeline, this matters—you want to distinguish between "API is down" (retry) and "response format changed" (alert).

### POST Requests with JSON Body

Python:
```python
payload = {"records": records, "batch_id": "abc123"}
response = requests.post(url, json=payload)
```

Rust:
```rust
use serde::Serialize;

#[derive(Serialize)]
struct BatchPayload {
    records: Vec<Record>,
    batch_id: String,
}

let payload = BatchPayload {
    records: records_to_send,
    batch_id: String::from("abc123"),
};

let response = client
    .post(url)
    .json(&payload)  // Automatically serializes to JSON
    .send()
    .await?;
```

## Part 3: Reading and Writing Data

### CSV Files

Add to `Cargo.toml`:
```toml
csv = "1.3"
```

Reading CSV (Python):
```python
import csv

with open("data.csv", "r") as f:
    reader = csv.DictReader(f)
    records = [row for row in reader]
```

Reading CSV (Rust):
```rust
use csv::Reader;
use serde::Deserialize;

#[derive(Deserialize, Debug)]
struct CsvRecord {
    id: i32,
    name: String,
    value: f64,
}

fn read_csv(path: &str) -> Result<Vec<CsvRecord>, Box<dyn std::error::Error>> {
    let mut reader = Reader::from_path(path)?;
    let mut records = Vec::new();
    
    for result in reader.deserialize() {
        let record: CsvRecord = result?;
        records.push(record);
    }
    
    Ok(records)
}
```

Writing CSV (Rust):
```rust
use csv::Writer;

fn write_csv(path: &str, records: &[CsvRecord]) -> Result<(), Box<dyn std::error::Error>> {
    let mut writer = Writer::from_path(path)?;
    
    for record in records {
        writer.serialize(record)?;
    }
    
    writer.flush()?;
    Ok(())
}
```

### Parquet Files

For data engineers, Parquet is essential. The `arrow` and `parquet` crates provide native support:

```toml
[dependencies]
arrow = "50.0"
parquet = "50.0"
```

Writing a Parquet file:
```rust
use arrow::array::{Int32Array, StringArray, Float64Array};
use arrow::record_batch::RecordBatch;
use parquet::arrow::arrow_writer::ArrowWriter;
use std::fs::File;
use std::sync::Arc;

fn write_parquet(path: &str, records: &[Record]) -> Result<(), Box<dyn std::error::Error>> {
    // Convert Vec<Record> to Arrow arrays
    let ids: Vec<i32> = records.iter().map(|r| r.id).collect();
    let names: Vec<&str> = records.iter().map(|r| r.name.as_str()).collect();
    let values: Vec<f64> = records.iter().map(|r| r.value).collect();
    
    let id_array = Int32Array::from(ids);
    let name_array = StringArray::from(names);
    let value_array = Float64Array::from(values);
    
    // Create record batch
    let batch = RecordBatch::try_from_iter(vec![
        ("id", Arc::new(id_array) as Arc<dyn arrow::array::Array>),
        ("name", Arc::new(name_array) as Arc<dyn arrow::array::Array>),
        ("value", Arc::new(value_array) as Arc<dyn arrow::array::Array>),
    ])?;
    
    // Write to file
    let file = File::create(path)?;
    let mut writer = ArrowWriter::try_new(file, batch.schema(), None)?;
    writer.write(&batch)?;
    writer.close()?;
    
    Ok(())
}
```

This is more verbose than `pandas.to_parquet()`, but you get:
- Zero-copy conversions where possible
- Explicit control over encoding
- No GIL limitations for parallel processing

## Part 4: Building CLI Tools

Python's `argparse` is fine. Rust's `clap` is exceptional:

```toml
[dependencies]
clap = { version = "4.0", features = ["derive"] }
```

```rust
use clap::Parser;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "data-pipeline")]
#[command(about = "Process data from various sources")]
struct Cli {
    /// Input file path
    #[arg(short, long, value_name = "FILE")]
    input: PathBuf,
    
    /// Output file path
    #[arg(short, long, value_name = "FILE")]
    output: PathBuf,
    
    /// Processing mode
    #[arg(short, long, default_value = "transform")]
    mode: String,
    
    /// Verbose output
    #[arg(short, long, action = clap::ArgAction::Count)]
    verbose: u8,
}

fn main() {
    let cli = Cli::parse();
    
    if cli.verbose > 0 {
        println!("Processing {} -> {}", cli.input.display(), cli.output.display());
    }
    
    // Process based on mode
    match cli.mode.as_str() {
        "transform" => transform(&cli.input, &cli.output),
        "validate" => validate(&cli.input),
        _ => eprintln!("Unknown mode: {}", cli.mode),
    }
}
```

Run with:
```bash
data-pipeline -i input.csv -o output.parquet --verbose
```

`clap` automatically generates help text, handles errors, and supports shell completions. It's the nicest CLI library I've used in any language.

## Part 5: A Complete Pipeline Example

Here's a full data pipeline that:
1. Reads configuration from a JSON file
2. Fetches data from an API
3. Transforms the data
4. Writes to Parquet

```rust
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Deserialize)]
struct Config {
    api_url: String,
    api_key: String,
    batch_size: usize,
    output_path: String,
}

#[derive(Deserialize, Debug)]
struct ApiRecord {
    id: i64,
    timestamp: String,
    value: f64,
    metadata: Option<serde_json::Value>,
}

#[derive(Serialize)]
struct TransformedRecord {
    id: i64,
    date: String,
    value: f64,
    value_squared: f64,
    has_metadata: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load configuration
    let config: Config = serde_json::from_str(
        &fs::read_to_string("config.json")?
    )?;
    
    // Setup HTTP client
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(30))
        .build()?;
    
    // Fetch data
    println!("Fetching data from API...");
    let response = client
        .get(&config.api_url)
        .header("Authorization", format!("Bearer {}", config.api_key))
        .send()
        .await?;
    
    if !response.status().is_success() {
        return Err(format!("API request failed: {}", response.status()).into());
    }
    
    let records: Vec<ApiRecord> = response.json().await?;
    println!("Fetched {} records", records.len());
    
    // Transform data
    let transformed: Vec<TransformedRecord> = records
        .into_iter()
        .map(|r| TransformedRecord {
            id: r.id,
            date: r.timestamp.split('T').next().unwrap_or(&r.timestamp).to_string(),
            value: r.value,
            value_squared: r.value * r.value,
            has_metadata: r.metadata.is_some(),
        })
        .collect();
    
    // Write to Parquet
    println!("Writing to Parquet...");
    write_parquet(&config.output_path, &transformed)?;
    
    println!("Pipeline complete. Output: {}", config.output_path);
    Ok(())
}

fn write_parquet(
    path: &str,
    records: &[TransformedRecord],
) -> Result<(), Box<dyn std::error::Error>> {
    use arrow::array::{BooleanArray, Float64Array, Int64Array, StringArray};
    use arrow::record_batch::RecordBatch;
    use parquet::arrow::arrow_writer::ArrowWriter;
    
    let ids: Vec<i64> = records.iter().map(|r| r.id).collect();
    let dates: Vec<&str> = records.iter().map(|r| r.date.as_str()).collect();
    let values: Vec<f64> = records.iter().map(|r| r.value).collect();
    let squared: Vec<f64> = records.iter().map(|r| r.value_squared).collect();
    let has_meta: Vec<bool> = records.iter().map(|r| r.has_metadata).collect();
    
    let batch = RecordBatch::try_from_iter(vec![
        ("id", Arc::new(Int64Array::from(ids)) as Arc<dyn arrow::array::Array>),
        ("date", Arc::new(StringArray::from(dates)) as Arc<dyn arrow::array::Array>),
        ("value", Arc::new(Float64Array::from(values)) as Arc<dyn arrow::array::Array>),
        ("value_squared", Arc::new(Float64Array::from(squared)) as Arc<dyn arrow::array::Array>),
        ("has_metadata", Arc::new(BooleanArray::from(has_meta)) as Arc<dyn arrow::array::Array>),
    ])?;
    
    let file = std::fs::File::create(path)?;
    let mut writer = ArrowWriter::try_new(file, batch.schema(), None)?;
    writer.write(&batch)?;
    writer.close()?;
    
    Ok(())
}
```

Cargo.toml for this project:
```toml
[package]
name = "data-pipeline"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1", features = ["full"] }
reqwest = { version = "0.11", features = ["json"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
arrow = "50.0"
parquet = "50.0"
```

## Part 6: When to Use Rust vs Python

### Use Rust When:

**Performance matters.** That 10M record pipeline I mentioned? Python took 4 hours. Rust took 12 minutes. The difference is memory efficiency—Rust processes streams without loading everything into RAM.

**Deployment simplicity matters.** A Rust binary is self-contained. No Python version conflicts, no dependency hell, no virtualenv. `scp` the binary and run it.

**Type safety prevents errors.** Data pipelines often have implicit contracts: "this field is always an integer." Rust enforces this at compile time. Python enforces it at runtime—maybe.

**Concurrency is complex.** Python's GIL limits true parallelism. Rust's ownership model makes safe concurrency possible without garbage collection pauses.

### Stick With Python When:

**Exploration matters.** Jupyter notebooks, pandas, and rapid iteration are unmatched for understanding new datasets.

**The ecosystem matters.** `pandas`, `numpy`, `scikit-learn`, `polars`—Python's data science stack is unmatched.

**Team velocity matters.** Everyone knows Python. Rust has a learning curve that affects delivery timelines.

**The bottleneck is elsewhere.** If your pipeline spends 90% of its time waiting for a database, rewriting in Rust won't help.

## The Learning Path

If this post piqued your interest, here's how I'd learn Rust as a data engineer:

1. **Read [The Rust Book](https://doc.rust-lang.org/book/)** chapters 1-10. Skip the advanced stuff for now.

2. **Build something real.** Not a todo app—something that solves a real problem. A CLI tool that validates CSV files, or a small API client.

3. **Embrace the compiler.** The borrow checker feels adversarial at first. It's actually a very thorough code reviewer that catches bugs before production.

4. **Use `clap`, `serde`, `reqwest`, and `polars`.** These crates feel Pythonic and cover 80% of data engineering use cases.

5. **Don't rewrite everything.** Use Rust for the performance-critical pieces. Keep Python for exploration and glue code.

## Conclusion

Rust won't replace Python for data engineering. The ecosystems serve different needs. But for the 20% of code that consumes 80% of runtime—API clients, format converters, validation tools—Rust offers genuine advantages.

The learning curve is real. The first week feels like fighting the compiler. By week three, you start appreciating that the compiler caught a bug that would have taken hours to debug in production.

Start small. Rewrite one CLI tool. See how it feels. You might find, like I did, that some problems are just better solved with a systems language.

---

*The code examples in this post are available [on GitHub](https://github.com/jerednel/rust-for-data-engineers-examples).*