---
name: async-best-practices
description: Learn MoonBit Async by running examples. Best practices for moonbitlang/async library including TaskGroup, timeout/retry, semaphore, queue, and structured concurrency patterns.
---

# MoonBit Async Best Practices

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Moon](https://img.shields.io/badge/moon-latest-orange)](https://www.moonbitlang.com/)

## Core Concepts

| Concept | Description |
|---------|-------------|
| **TaskGroup** | Basic unit of structured concurrency, managing the creation, waiting, and cancellation of a group of related tasks |
| **Timeout** | Set maximum execution time for async operations, automatically cancel and return `None` or `Err` on timeout |
| **Retry** | Automatically retry async operations on failure, supporting exponential backoff, fixed delay, and other strategies |
| **Semaphore** | Limit the number of concurrent tasks executing simultaneously, used for resource protection and rate limiting |
| **Queue** | Unbounded buffer queue for data transfer in producer-consumer patterns |

## Basic Usage

### Structured Concurrency

```moonbit no-check
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { fetch_user(uid) })
  let t2 = group.spawn(fn() { fetch_orders(uid) })
  (t1.wait(), t2.wait())
})
```

### Timeout Control

```moonbit no-check
let result = @async.with_timeout_opt(500, fn() {
  slow_operation()
})
match result {
  Some(v) => println("Success: \{v}")
  None => println("Timeout")
}
```

### Retry Mechanism

```moonbit no-check
let value = @async.retry(
  @async.ExponentialDelay(100, 2.0, 1000),
  fn() { unreliable_operation() },
  3
)
```

### Concurrency Control

```moonbit no-check
// Use Semaphore to limit concurrency
let sem = @semaphore.Semaphore::new(5)

@async.with_task_group(fn(group) {
  for item in items {
    group.spawn(fn() {
      sem.acquire()
      try {
        process_item(item)
      } finally {
        sem.release()
      }
    })
  }
})
```

### Producer-Consumer

```moonbit no-check
let q = @aqueue.Queue::new()
@async.with_task_group(fn(group) {
  group.spawn(fn() {
    for i in 0..<10 {
      q.put(i)
    }
  })
  group.spawn(fn() {
    for _ in 0..<10 {
      let item = q.get()
      process(item)
    }
  })
})
```

## Strategy Abstraction Pattern

Extract timeout, retry, and other strategies from business code and encapsulate them uniformly in a strategy abstraction layer.

```moonbit no-check
// Business layer code
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  for id in order_ids {
    match @src.call_payment_with_retry(id) {
      Ok(_) => log("order {id} success")
      Err(e) => log("order {id} failed: {e}")
    }
  }
}

// Strategy abstraction layer (src/Async_best_practices.mbt)
pub async fn call_with_timeout_and_retry(
  timeout_ms : Int,
  retry : @async.RetryMethod,
  f : async () -> X,
  max_retry? : Int,
) -> Result[X, String] {
  try {
    let out = @async.with_timeout_opt(timeout_ms, fn() {
      @async.retry(retry, f, max_retry?)
    })
    match out {
      Some(v) => Ok(v)
      None => Err("timeout")
    }
  } catch {
    err => Err(err.to_string())
  }
}
```

**Benefits**:
- Unified configuration: All timeout/retry strategies are centrally managed
- Easy to review: Strategy changes only require modification in one place
- Clean business code: Business code doesn't contain strategy details

## API Reference

### TaskGroup

| API | Description |
|-----|-------------|
| `with_task_group[T](f: (TaskGroup) -> T) -> T` | Create a task group to manage the creation, waiting, and cancellation of concurrent tasks |
| `group.spawn[T](f: async () -> T) -> Task[T]` | Create a new task within the task group |
| `group.spawn_bg(f: async () -> Unit) -> Unit` | Create a background task without waiting for the result |
| `task.wait() -> T` | Wait for the task to complete and get the result |

```moonbit no-check
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { task1() })
  let t2 = group.spawn(fn() { task2() })
  (t1.wait(), t2.wait())
})
```

### Timeout

| API | Description |
|-----|-------------|
| `with_timeout_opt[T](timeout_ms: Int, f: async () -> T) -> Option[T]` | Execute async operation, return `None` on timeout |
| `with_timeout[T](timeout_ms: Int, f: async () -> T) -> T` | Execute async operation, throw `TimeoutError` on timeout |

```moonbit no-check
let result = @async.with_timeout_opt(500, fn() { slow_operation() })
match result {
  Some(v) => println("Success")
  None => println("Timeout")
}
```

### Retry

| API | Description |
|-----|-------------|
| `retry[T](method: RetryMethod, f: async () -> T, max_retry?: Int) -> T` | Retry async operation |
| `ExponentialDelay(initial_ms: Int, multiplier: Float, max_ms: Int) -> RetryMethod` | Exponential backoff retry strategy |
| `FixedDelay(ms: Int) -> RetryMethod` | Fixed delay retry strategy |

```moonbit no-check
let value = @async.retry(
  @async.ExponentialDelay(100, 2.0, 1000),
  fn() { unreliable_operation() },
  3
)
```

### Semaphore

| API | Description |
|-----|-------------|
| `Semaphore::new(permits: Int) -> Semaphore` | Create a semaphore to limit concurrency |
| `acquire() -> Unit` | Acquire a permit, wait if no permits are available |
| `release() -> Unit` | Release a permit |

```moonbit no-check
let sem = @semaphore.Semaphore::new(5)
sem.acquire()
try {
  do_work()
} finally {
  sem.release()
}
```

### Queue

| API | Description |
|-----|-------------|
| `Queue::new[T]() -> Queue[T]` | Create an unbounded queue |
| `put(item: T) -> Unit` | Put an element into the queue |
| `get() -> T` | Get an element from the queue, block if queue is empty |

```moonbit no-check
let q = @aqueue.Queue::new()
q.put(item)
let item = q.get()
```

## Complete Examples

### Order Processing Flow

```moonbit no-check
pub async fn process_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  
  @async.with_task_group(fn(group) {
    for id in order_ids {
      group.spawn(fn() {
        match @src.call_payment_with_retry(id) {
          Ok(_) => log.write_string("order \{id} success\n")
          Err(e) => log.write_string("order \{id} failed: \{e}\n")
        }
      })
    }
  })
  
  log.to_string()
}
```

### API Gateway Rate Limiting

```moonbit no-check
pub struct Gateway {
  limiter : @semaphore.Semaphore
  mut total_requests : Int
}

pub fn Gateway::new(max_concurrent : Int) -> Gateway {
  {
    limiter: @semaphore.Semaphore::new(max_concurrent),
    total_requests: 0,
  }
}

pub async fn Gateway::handle_request(self : Gateway, req : Request) -> Response {
  self.limiter.acquire()
  try {
    self.total_requests = self.total_requests + 1
    call_backend(req)
  } finally {
    self.limiter.release()
  }
}
```

### Producer-Consumer Pipeline

```moonbit no-check
pub async fn pipeline_sum(n : Int, workers : Int) -> Int {
  let q = @aqueue.Queue::new()
  let sum = @std.ref::Ref::new(0)
  
  @async.with_task_group(fn(group) {
    group.spawn(fn() {
      for i in 1..=n {
        q.put(i)
      }
    })
    
    for _ in 0..<workers {
      group.spawn(fn() {
        for _ in 0..<n / workers {
          let item = q.get()
          sum.update(fn(x) { x + item })
        }
      })
    }
  })
  
  sum.get()
}
```

## Design Principles

### Structured Concurrency

All concurrent tasks are created within `TaskGroup` to ensure controllable task lifecycle. When a parent task is cancelled, child tasks are automatically cancelled, preventing resource leaks.

**Benefits**:
- Cancellation propagation: Child tasks are automatically cancelled when parent task is cancelled
- Lifecycle management: All tasks complete when the task group ends
- Error handling: Failures in any task within the group can be handled uniformly

### Dependency Tracking

`TaskGroup` uses dependency tracking to automatically manage task relationships:
- Record parent-child relationships when tasks are created
- Propagate cancellation from parent to all child tasks
- Wait for all tasks to complete when the task group ends

### Memory Management

- `Queue` uses unbounded buffers to avoid blocking caused by backpressure
- `Semaphore` uses atomic operations to avoid lock contention
- `TaskGroup` uses weak references to avoid memory leaks caused by circular dependencies

## FAQ

### Why do we need the strategy abstraction pattern?

Business code scattered with `@async.with_timeout_opt(500, ...)` makes it difficult to configure uniformly and review. The strategy abstraction layer encapsulates timeout, retry, and other strategies uniformly, allowing the business layer to focus only on business logic.

### Why use TaskGroup instead of direct spawn?

Wild `spawn` leads to uncontrolled tasks and cancellation signals cannot propagate. `TaskGroup` ensures controllable task lifecycle, and child tasks are automatically cancelled when parent task is cancelled.

### Queue is unbounded, won't it cause memory leaks?

`Queue` uses unbounded buffers to avoid blocking caused by backpressure. In real business scenarios, it's recommended to combine with Semaphore/rate limiting to avoid memory expansion from unlimited producer puts.

### How to choose the right retry strategy?

- **Exponential backoff**: Suitable for network requests, API calls, and other operations that may fail due to temporary faults
- **Fixed delay**: Suitable for scenarios requiring fixed interval retries

## Repository Structure

```
Async_best_practices/
├── src/                       # Strategy abstraction layer and API examples
│   ├── Async_best_practices.mbt
│   └── Async_best_practices_test.mbt
└── examples/                  # Business examples
    ├── checkout/              # Order processing
    ├── task_group/            # Structured concurrency
    ├── retry_timeout/         # Timeout and retry
    ├── semaphore_limiter/    # Concurrency control
    ├── pipeline_queue/        # Producer-consumer
    └── api-gateway/           # API gateway
```

## Usage

Add to `moon.pkg.json`:

```json
{
  "import": [
    "CGaaaaaa/async-best-practices/src"
  ]
}
```

Run tests:

```bash
moon check --target native
moon test --target native
```

## Related Resources

- [MoonBit Async Official Documentation](https://docs.moonbitlang.com/async)
- [Structured Concurrency](https://en.wikipedia.org/wiki/Structured_concurrency)
- [moonbitlang/async Source Code](https://github.com/moonbitlang/async)

## Contributing

Before submitting a PR, please ensure:

```bash
moon check --target native
moon test --target native
moon fmt
```

## License

[Apache 2.0](LICENSE)
