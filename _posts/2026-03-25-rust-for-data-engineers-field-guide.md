---
layout: post
title: "Rust for Data Engineers: A Python-to-Rust Field Guide"
date: 2026-03-25 12:00:00 -0500
tags: [rust, python, data-engineering, tutorial, api, performance]
---

I spent a decade writing Python for data pipelines. ETL scripts, API integrations, data transformations—Python was the obvious choice. Then I hit the wall: a pipeline processing 10M+ records daily that couldn't finish in its 4-hour window. I rewrote the bottleneck in Rust. It finished in 12 minutes.

This isn't a "Rust is better" post. Python and Rust solve different problems. But if you're a data engineer hitting performance ceilings, dealing with deployment headaches, or just curious about what Rust offers, this guide will get you productive without the usual systems programming detours.

**Update:** I originally wrote this as a reference. Then I decided to actually learn Rust properly. What follows is the expanded guide I wish I'd had—practical, thorough, and focused on the mental model shifts that actually matter.

---

## Before You Start: Installing Rust

```bash
# macOS/Linux
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# After installation, restart your shell or run:
source $HOME/.cargo/env

# Verify installation
rustc --version  # Should show something like rustc 1.76.0
cargo --version  # Cargo is Rust's build tool and package manager
```

Rust includes:
- `rustc`: The compiler
- `cargo`: Build tool, package manager, test runner, documentation generator
- `rustup`: Toolchain manager (like pyenv for Python)

Create a new project:
```bash
cargo new my_pipeline
cd my_pipeline
```

This creates:
```
my_pipeline/
├── Cargo.toml      # Like package.json or requirements.txt + setup.py
├── .gitignore
└── src/
    └── main.rs     # Entry point
```

Run it:
```bash
cargo run
```

Build for production:
```bash
cargo build --release
# Binary appears at: target/release/my_pipeline
```

---

## What This Guide Assumes

You know Python. You've written data pipelines. You're comfortable with pandas, requests, and maybe some SQL. You don't know C, don't care about memory management theory, and want practical examples you can use tomorrow.

We'll cover:
- The mental model shift from dynamic to static typing
- Ownership and borrowing—the core Rust concept
- Making HTTP requests and handling JSON
- Reading and writing CSV/Parquet files
- Building CLI tools that feel like Python scripts
- When to reach for Rust vs staying with Python

---

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

**Key insight:** In Python, immutability is a convention (using tuples, frozen dataclasses). In Rust, it's the default and enforced by the compiler.

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

---

## Part 2: Ownership and Borrowing—The Core Concept

This is where most Python developers get stuck. Not because it's hard, but because it's different. Stick with me.

### The Problem Rust Solves

In Python, objects live on the heap and are garbage collected:
```python
# Python
def process():
    data = fetch_data()  # Object created
    transform(data)      # Same object, different reference
    return data          # Returned to caller
# When 'data' goes out of scope, garbage collector cleans it up
```

This is convenient but has costs:
1. **Runtime overhead**: Garbage collection pauses
2. **Memory bloat**: Objects linger until GC runs
3. **Hidden complexity**: You don't know when memory is freed

Rust eliminates the garbage collector by tracking ownership at compile time.

### Ownership Rules

1. **Each value has an owner**
2. **There can only be one owner at a time**
3. **When the owner goes out of scope, the value is dropped**

```rust
fn main() {
    let s1 = String::from("hello");  // s1 owns the string
    let s2 = s1;                      // ownership moves to s2
    
    // println!("{}", s1);  // ERROR: borrow of moved value
    println!("{}", s2);      // This works
}  // s2 goes out of scope, string is freed
```

**This is the most important concept in Rust.** When you assign `s1` to `s2`, the string isn't copied—the ownership moves. `s1` is no longer valid.

### Borrowing: Temporary Access

Moving ownership every time is impractical. Rust lets you **borrow** references:

```rust
fn main() {
    let s = String::from("hello");
    
    print_length(&s);  // Borrow s (immutable reference)
    print_length(&s);  // Can borrow again
    
    println!("{}", s);  // s is still valid!
}

fn print_length(s: &String) {
    println!("Length: {}", s.len());
}  // Borrow ends here, but s in main is still valid
```

The `&` creates a reference. You can have unlimited immutable references, but:

```rust
fn main() {
    let mut s = String::from("hello");
    
    change(&mut s);  // Mutable borrow
    
    println!("{}", s);  // Works: s is now "hello world"
}

fn change(s: &mut String) {
    s.push_str(" world");
}
```

**Mutable borrow rules:**
- You can have **one** mutable reference **OR** any number of immutable references
- Not both at the same time
- This prevents data races at compile time

### Why This Matters for Data Engineers

Consider this Python code:
```python
# Python
def process_records(records):
    filtered = records  # Both point to same list!
    filtered.append({"new": "record"})
    return records  # Original is modified!
```

In Rust, this is caught at compile time:
```rust
fn process_records(records: &mut Vec<Record>) {
    // Explicitly mutable, caller knows it might change
    records.push(Record { ... });
}

// Or if you don't want to modify:
fn process_records(records: &[Record]) -> Vec<Record> {
    // Can't modify records, must return new Vec
    records.iter().filter(...).collect()
}
```

**The borrow checker forces you to be explicit about:**
- Who owns the data
- Who can modify it
- When it's safe to read

This feels restrictive until you realize it catches bugs before they reach production.

### The `String` vs `&str` Distinction

This confuses every Python developer:

```rust
let s1: String = String::from("hello");  // Owned, heap-allocated, mutable
let s2: &str = "hello";                   // Borrowed, immutable, static

let s3: &str = &s1;        // String can become &str
let s4: String = s3;       // ERROR: can't convert &str to String directly
let s5: String = s3.to_string();  // Must explicitly allocate
```

**Rule of thumb:**
- Use `String` when you need to own/modify the data
- Use `&str` for function parameters that only need to read
- Accept `&str` in public APIs (callers can pass either type)

---

## Part 3: Error Handling

Python uses exceptions. Rust uses `Result<T, E>` and `Option<T>`.

### The Option Type: Handling Absence

Python:
```python
user = find_user(user_id)  # Might return None
if user is not None:
    print(user.name)
else:
    print("User not found")
```

Rust:
```rust
let user = find_user(user_id);

match user {
    Some(u) => println!("{}", u.name),
    None => println!("User not found"),
}

// Or more concisely:
if let Some(u) = find_user(user_id) {
    println!("{}", u.name);
}

// Or with a default:
let name = find_user(user_id).map(|u| u.name).unwrap_or("Unknown");
```

### The Result Type: Handling Failure

Python:
```python
try:
    data = fetch_from_api()
    result = parse_json(data)
except RequestException as e:
    print(f"Request failed: {e}")
except JSONDecodeError as e:
    print(f"Invalid JSON: {e}")
```

Rust:
```rust
match fetch_from_api() {
    Ok(data) => match parse_json(&data) {
        Ok(result) => println!("{:?}", result),
        Err(e) => println!("Invalid JSON: {}", e),
    },
    Err(e) => println!("Request failed: {}", e),
}
```

Verbose, yes. But explicit. You can't forget to handle an error.

### The ? Operator: Propagating Errors

The `?` operator is syntactic sugar for "if this failed, return the error":

```rust
fn process_data() -> Result<ProcessedData, Box<dyn std::error::Error>> {
    let data = fetch_from_api()?;   // If Err, return Err immediately
    let parsed = parse_json(&data)?; // If Err, return Err immediately
    let processed = transform(parsed)?; // If Err, return Err immediately
    Ok(processed)
}
```

This is equivalent to:
```rust
fn process_data() -> Result<ProcessedData, Box<dyn std::error::Error>> {
    let data = match fetch_from_api() {
        Ok(d) => d,
        Err(e) => return Err(e.into()),
    };
    // ... same for each step
}
```

**Key insight:** `?` only works in functions that return `Result`. It converts error types automatically using `From` trait (like Python's exception chaining).

### Practical Error Handling

For data pipelines, you often want to:
1. Log errors but continue processing
2. Collect errors for a final report
3. Fail fast on critical errors

```rust
use std::collections::VecDeque;

struct PipelineResult<T> {
    data: Vec<T>,
    errors: Vec<String>,
}

fn process_batch(items: Vec<Input>) -> PipelineResult<Output> {
    let mut results = Vec::new();
    let mut errors = Vec::new();
    
    for item in items {
        match process_item(item) {
            Ok(output) => results.push(output),
            Err(e) => {
                eprintln!("Failed to process item: {}", e);
                errors.push(format!("Item {}: {}", item.id, e));
                // Continue with next item
            }
        }
    }
    
    PipelineResult { data: results, errors }
}
```

---

## Part 4: Making HTTP Requests

Python's `requests` library sets a high bar for ergonomics. Rust's ecosystem is more fragmented, but `reqwest` comes closest:

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

---

## Part 5: Reading and Writing Data

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

---

## Part 6: Building CLI Tools

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

---

## Part 7: A Complete Pipeline Example

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

---

## Part 8: When to Use Rust vs Python

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

---

## Part 9: Common Pitfalls for Python Developers

### 1. Fighting the Borrow Checker

You'll spend your first week battling errors like:
```
error[E0382]: borrow of moved value: `s`
```

**Don't fight it. Understand it.** The compiler isn't being pedantic—it's catching bugs that would cause crashes in C or subtle bugs in Python.

**Common fix:** If you need to use a value after passing it, pass a reference (`&s`) instead of the value (`s`).

### 2. Expecting Implicit Conversions

Python: `"count: " + 42` works (becomes `"count: 42"`)
Rust: `format!("count: {}", 42)` or `"count: ".to_string() + &42.to_string()`

Rust is explicit about type conversions. This is verbose but prevents bugs.

### 3. Forgetting Mutability

```rust
let items = vec![1, 2, 3];
items.push(4);  // ERROR: cannot borrow as mutable

let mut items = vec![1, 2, 3];  // 'mut' required
items.push(4);  // This works
```

### 4. String vs &str Confusion

```rust
fn takes_string(s: String) { }      // Takes ownership
fn takes_str(s: &str) { }           // Borrows

let s = String::from("hello");
takes_string(s);     // s is moved, can't use s after this
takes_str(&s);       // s is borrowed, can still use s
```

**Rule:** Accept `&str` in function parameters. Only require `String` if you need to store it long-term.

### 5. Ignoring Results

This compiles but warns:
```rust
std::fs::remove_file("temp.txt");  // Warning: unused Result
```

Always handle Results:
```rust
match std::fs::remove_file("temp.txt") {
    Ok(_) => println!("File removed"),
    Err(e) => eprintln!("Failed to remove file: {}", e),
}
// Or: std::fs::remove_file("temp.txt")?; if in a function returning Result
```

---

## Part 10: The Learning Path—A Practical Curriculum

Here's how I'd learn Rust if I were starting today:

### Week 1: The Fundamentals

**Goal:** Understand ownership, borrowing, and basic syntax.

**Resources:**
- [The Rust Book](https://doc.rust-lang.org/book/) chapters 1-8
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/) (supplemental)

**Exercises:**
1. Write a program that reads a CSV file and prints summary statistics
2. Implement a simple string reverser that doesn't use `.reverse()`
3. Build a CLI tool that counts lines, words, and bytes (like `wc`)

**Focus areas:**
- `let` vs `let mut`
- `String` vs `&str`
- References and borrowing
- The `Result` type

### Week 2: Collections and Iterators

**Goal:** Be comfortable with Rust's collection types and iterator patterns.

**Resources:**
- The Rust Book chapters 8-13

**Exercises:**
1. Implement a word frequency counter using `HashMap`
2. Build a simple ETL: read CSV, filter rows, write JSON
3. Parse a log file and aggregate by hour

**Focus areas:**
- `Vec<T>`, `HashMap<K, V>`, `HashSet<T>`
- Iterator methods: `.map()`, `.filter()`, `.collect()`, `.fold()`
- Pattern matching with `match`

### Week 3: Error Handling and APIs

**Goal:** Build programs that interact with the real world.

**Resources:**
- The Rust Book chapter 9
- `reqwest` documentation

**Exercises:**
1. Build a CLI tool that fetches weather data from an API
2. Create a program that downloads files with progress bars
3. Implement retry logic with exponential backoff

**Focus areas:**
- The `?` operator
- Custom error types
- Async/await basics
- HTTP requests

### Week 4: Real Data Engineering

**Goal:** Build something you'd actually use at work.

**Project ideas:**
1. **CSV Validator:** Check file format, column types, constraints
2. **API Cache:** Fetch data periodically, store in Parquet, serve via small HTTP API
3. **Log Analyzer:** Parse application logs, aggregate metrics, output to CSV
4. **Data Diff:** Compare two datasets and output differences

**Focus areas:**
- CSV and Parquet I/O
- CLI argument parsing with `clap`
- Configuration management
- Logging with `tracing` or `log`

### Week 5+: Deepening

**Pick your path:**

**Performance path:**
- Zero-copy parsing with `nom`
- SIMD with `std::simd`
- Memory-mapped files with `memmap2`

**Async path:**
- `tokio` runtime deep dive
- Streaming data processing
- Building small services with `axum` or `actix-web`

**Data path:**
- `polars` (Rust DataFrames, faster than pandas)
- `arrow` ecosystem
- `datafusion` (query engine)

---

## Part 11: Debugging and Troubleshooting

### Reading Compiler Errors

Rust's compiler is helpful, but the errors can be verbose. Focus on:

1. **The error message** (first line after `error[EXXXX]:`)
2. **The label** (`-->` pointing to your code)
3. **The help text** (often suggests the fix)

Example:
```
error[E0596]: cannot borrow `x` as mutable, as it is not declared as mutable
 --> src/main.rs:3:5
  |
2 |     let x = 5;
  |         - help: consider changing this to be mutable: `mut x`
3 |     x += 1;
  |     ^^^^^^ cannot borrow as mutable
```

The compiler literally tells you the fix: change `let x` to `let mut x`.

### Common Error Codes

| Code | Meaning | Fix |
|------|---------|-----|
| E0382 | Use of moved value | Pass reference (`&x`) instead of value (`x`) |
| E0596 | Cannot borrow as mutable | Add `mut`: `let mut x` |
| E0308 | Mismatched types | Check type annotations, use `as` for casting |
| E0277 | Trait not implemented | Import the trait or implement it for your type |
| E0433 | Undeclared crate/module | Add to `Cargo.toml` or `use` statement |

### Debugging Tools

**Print debugging (yes, really):**
```rust
println!("{:?}", my_struct);  // Debug format
println!("{:#?}", my_struct); // Pretty-printed debug
```

**The `dbg!` macro:**
```rust
let x = dbg!(calculate_value());  // Prints file:line and value
```

**Using a debugger:**
```bash
# Install rust-gdb or rust-lldb
cargo install rust-gdb

# Build with debug symbols
cargo build

# Run with debugger
rust-gdb target/debug/my_program
```

---

## Part 12: Testing

Rust has built-in testing that's better than Python's `unittest`:

```rust
// In src/lib.rs or src/main.rs

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_addition() {
        assert_eq!(2 + 2, 4);
    }

    #[test]
    fn test_failing() {
        assert_ne!(2 + 2, 5);
    }

    #[test]
    #[should_panic(expected = "divide by zero")]
    fn test_divide_by_zero() {
        let _ = 1 / 0;
    }
}
```

Run tests:
```bash
cargo test              # Run all tests
cargo test test_add     # Run tests matching pattern
cargo test -- --nocapture  # Show println! output
```

**Property-based testing** with `proptest`:
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_reverse_reverse(s in "[a-zA-Z0-9]*") {
        let reversed: String = s.chars().rev().collect();
        let reversed_again: String = reversed.chars().rev().collect();
        assert_eq!(s, reversed_again);
    }
}
```

---

## Conclusion

Rust won't replace Python for data engineering. The ecosystems serve different needs. But for the 20% of code that consumes 80% of runtime—API clients, format converters, validation tools—Rust offers genuine advantages.

The learning curve is real. The first week feels like fighting the compiler. By week three, you start appreciating that the compiler caught a bug that would have taken hours to debug in production.

Start small. Rewrite one CLI tool. See how it feels. You might find, like I did, that some problems are just better solved with a systems language.

**Recommended next steps:**
1. Install Rust and run through [The Rust Book](https://doc.rust-lang.org/book/)
2. Build the CSV validator from Week 1
3. Join the [Rust Discord](https://discord.gg/rust-lang) or [users.rust-lang.org](https://users.rust-lang.org) when you get stuck
4. Check out [Rust Data Engineering](https://github.com/jerednel/rust-data-engineering-examples) for more examples

---

*Questions? Find me on [Twitter/X](https://twitter.com/jerednel) or the [Meridian Discord](https://discord.gg/meridianseo).*
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