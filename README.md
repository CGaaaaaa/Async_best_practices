---
name: async-best-practices
description: Learn MoonBit Async by running examples. Best practices for moonbitlang/async library including TaskGroup, timeout/retry, semaphore, queue, and structured concurrency patterns.
---

# MoonBit Async 最佳实践示例库

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Moon](https://img.shields.io/badge/moon-latest-orange)](https://www.moonbitlang.com/)

## 核心概念

| 概念 | 描述 |
|------|------|
| **TaskGroup** | 结构化并发的基本单元，管理一组相关任务的创建、等待和取消 |
| **Timeout** | 为异步操作设置最大执行时间，超时后自动取消并返回 `None` 或 `Err` |
| **Retry** | 在失败时自动重试异步操作，支持指数退避、固定延迟等策略 |
| **Semaphore** | 限制同时执行的并发任务数量，用于资源保护和限流 |
| **Queue** | 无界缓冲队列，用于生产者-消费者模式的数据传递 |

## 基本用法

### 结构化并发

```moonbit no-check
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { fetch_user(uid) })
  let t2 = group.spawn(fn() { fetch_orders(uid) })
  (t1.wait(), t2.wait())
})
```

### 超时控制

```moonbit no-check
let result = @async.with_timeout_opt(500, fn() {
  slow_operation()
})
match result {
  Some(v) => println("成功: \{v}")
  None => println("超时")
}
```

### 重试机制

```moonbit no-check
let value = @async.retry(
  @async.ExponentialDelay(100, 2.0, 1000),
  fn() { unreliable_operation() },
  3
)
```

### 并发控制

```moonbit no-check
// 使用 Semaphore 限制并发
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

### 生产者-消费者

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

## 策略收口模式

将超时、重试等策略从业务代码中抽离，统一封装在策略收口层。

```moonbit no-check
// 业务层代码
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  for id in order_ids {
    match @src.call_payment_with_retry(id) {
      Ok(_) => log("order {id} success")
      Err(e) => log("order {id} failed: {e}")
    }
  }
}

// 策略收口层（src/Async_best_practices.mbt）
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

**优势**：
- 统一调参：所有超时/重试策略集中管理
- 易于审查：策略变更只需修改一处
- 业务简洁：业务代码不包含策略细节

## API 参考

### TaskGroup

| API | 描述 |
|-----|------|
| `with_task_group[T](f: (TaskGroup) -> T) -> T` | 创建任务组，管理并发任务的创建、等待和取消 |
| `group.spawn[T](f: async () -> T) -> Task[T]` | 在任务组中创建新任务 |
| `group.spawn_bg(f: async () -> Unit) -> Unit` | 创建后台任务，不等待结果 |
| `task.wait() -> T` | 等待任务完成并获取结果 |

```moonbit no-check
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { task1() })
  let t2 = group.spawn(fn() { task2() })
  (t1.wait(), t2.wait())
})
```

### Timeout

| API | 描述 |
|-----|------|
| `with_timeout_opt[T](timeout_ms: Int, f: async () -> T) -> Option[T]` | 执行异步操作，超时返回 `None` |
| `with_timeout[T](timeout_ms: Int, f: async () -> T) -> T` | 执行异步操作，超时抛出 `TimeoutError` |

```moonbit no-check
let result = @async.with_timeout_opt(500, fn() { slow_operation() })
match result {
  Some(v) => println("成功")
  None => println("超时")
}
```

### Retry

| API | 描述 |
|-----|------|
| `retry[T](method: RetryMethod, f: async () -> T, max_retry?: Int) -> T` | 重试异步操作 |
| `ExponentialDelay(initial_ms: Int, multiplier: Float, max_ms: Int) -> RetryMethod` | 指数退避重试策略 |
| `FixedDelay(ms: Int) -> RetryMethod` | 固定延迟重试策略 |

```moonbit no-check
let value = @async.retry(
  @async.ExponentialDelay(100, 2.0, 1000),
  fn() { unreliable_operation() },
  3
)
```

### Semaphore

| API | 描述 |
|-----|------|
| `Semaphore::new(permits: Int) -> Semaphore` | 创建信号量，限制并发数 |
| `acquire() -> Unit` | 获取许可，如果没有可用许可则等待 |
| `release() -> Unit` | 释放许可 |

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

| API | 描述 |
|-----|------|
| `Queue::new[T]() -> Queue[T]` | 创建无界队列 |
| `put(item: T) -> Unit` | 向队列放入元素 |
| `get() -> T` | 从队列获取元素，队列为空时阻塞 |

```moonbit no-check
let q = @aqueue.Queue::new()
q.put(item)
let item = q.get()
```

## 业务示例

`examples/` 目录包含 6 个可运行的业务示例，每个示例都配有测试代码。

### 示例索引

| 示例 | 核心知识点 | 代码行数 | 测试数 |
|------|-----------|---------|-------|
| [checkout](#checkout) | 业务与 infra 分层 | ~20 | 1 |
| [task_group](#task_group) | TaskGroup、fail-fast | ~40 | 1 |
| [retry_timeout](#retry_timeout) | 统一超时/重试策略 | ~50 | 3 |
| [semaphore_limiter](#semaphore_limiter) | 并发限流、资源保护 | ~30 | 1 |
| [pipeline_queue](#pipeline_queue) | 队列、并行消费 | ~40 | 1 |
| [api-gateway](#api-gateway) | 生产级综合应用 | ~250 | 9 |

### checkout

业务与 infra 分层示例。

```moonbit no-check
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  for id in order_ids {
    log.write_string("start order \{id}\n")
    
    let outcome = @src.call_payment_with_retry(id)
    
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  log.to_string()
}
```

**要点**：业务代码只表达"处理订单列表，记录结果"，超时/重试策略在 `src/Async_best_practices.mbt` 中封装。

运行测试：

```bash
cd examples/checkout
moon test --target native
```

### task_group

结构化并发示例。

```moonbit no-check
pub async fn demo_task_group() -> String {
  let log = StringBuilder::new()
  
  ignore(
    @async.with_task_group(fn(group) {
      let task1 = group.spawn(fn() {
        @async.sleep(100)
        log.write_string("Task 1 finished\n")
        1
      })
      
      let task2 = group.spawn(fn() {
        @async.sleep(50)
        log.write_string("Task 2 failed\n")
        raise Failure("Task 2 error")
        2
      })
      
      let task3 = group.spawn(fn() {
        @async.sleep(200)
        log.write_string("Task 3 finished\n")
        3
      })

      let res1 = task1.wait()
      let res3 = task3.wait()
      log.write_string("All tasks completed: \{res1}, \{res3}\n")
    })
  ) catch {
    err => log.write_string("TaskGroup failed: \{err}\n")
  }
  
  log.to_string()
}
```

**要点**：
- `group.spawn()` 创建关键任务（失败会取消兄弟任务）
- `task.wait()` 等待任务完成
- TaskGroup 退出时自动清理所有子任务

运行测试：

```bash
cd examples/task_group
moon test --target native
```

### retry_timeout

超时与重试示例。

```moonbit no-check
// 场景 1：操作成功
pub async fn demo_retry_timeout_success() -> String {
  let result = @src.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(100)
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}

// 场景 2：操作超时
pub async fn demo_retry_timeout_fail() -> String {
  let result = @src.call_with_timeout_and_retry(
    50,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(200)
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**要点**：
- 超时保护避免无界等待
- 重试只用于瞬态错误（网络抖动、服务过载）
- 逻辑错误（参数错误、权限错误）不应该重试

运行测试：

```bash
cd examples/retry_timeout
moon test --target native
```

### semaphore_limiter

并发限流示例。

```moonbit no-check
pub async fn demo_semaphore_limiter() -> String {
  let log = StringBuilder::new()
  
  @async.with_task_group(fn(group) {
    let semaphore = @semaphore.Semaphore::new(2)
    
    for i in 0..<5 {
      group.spawn_bg(fn() raise {
        semaphore.acquire()
        log.write_string("Task \{i} acquired semaphore\n")
        
        @async.sleep(100)
        
        semaphore.release()
        log.write_string("Task \{i} released semaphore\n")
      })
    }
    
    @async.sleep(500)
  })
  
  log.to_string()
}
```

**要点**：
- `Semaphore::new(2)` 表示最多 2 个并发
- `acquire()` 会阻塞直到有空闲槽位
- `release()` 释放槽位，让等待的任务继续

**真实场景**：
- 批量处理 10000 个订单，但 DB 连接池只有 20 个
- 调用第三方 API，对方限制 QPS 100
- CPU 密集任务（图片处理），避免 CPU 100%

运行测试：

```bash
cd examples/semaphore_limiter
moon test --target native
```

### pipeline_queue

生产者-消费者示例。

```moonbit no-check
pub async fn pipeline_sum(n_items : Int, workers : Int) -> Int {
  @async.with_task_group(fn(group) {
    let q = @aqueue.Queue::new()

    group.spawn_bg(fn() {
      for i in 1..(n_items + 1) {
        q.put(i)
      }
      for _ in 0..<workers {
        q.put(0)
      }
    })

    let tasks = Array::new()
    for _ in 0..<workers {
      tasks.push(group.spawn(fn() -> Int raise {
        let mut acc = 0
        for {
          let v = q.get()
          guard v != 0 else { break }
          acc = acc + v
        }
        acc
      }))
    }

    let mut sum = 0
    for task in tasks {
      sum = sum + task.wait()
    }
    sum
  })
}
```

**要点**：
- `q.put(item)` 放入数据（非阻塞）
- `q.get()` 阻塞获取数据
- 用特殊值（0）作为终止信号
- 多个 worker 并行消费，提升吞吐量

**注意**：`aqueue.Queue` 是无界缓冲，生产速度 > 消费速度时会导致内存增长。实际项目中需要用 Semaphore 控制队列大小。

运行测试：

```bash
cd examples/pipeline_queue
moon test --target native
```

### api-gateway

综合真实案例。

| 功能 | 实现方式 | Async 模式 |
|------|---------|-----------|
| 路由转发 | 根据路径分发到不同后端 | TaskGroup |
| 并发限流 | 最大并发请求数控制 | Semaphore |
| 超时保护 | 统一请求超时 | with_timeout_opt |
| 重试机制 | 瞬态失败自动重试 | infra 层封装 |
| 日志记录 | 后台异步日志 | spawn_bg |
| 批量处理 | 并行处理多个请求 | TaskGroup + spawn |
| 健康检查 | 成功率统计 | 状态管理 |

```moonbit no-check
pub async fn Gateway::handle_request(
  self : Gateway,
  request : Request
) -> Response raise {
  self.total_requests = self.total_requests + 1
  
  self.limiter.acquire()
  
  @async.with_task_group(fn(group) {
    let response_task = group.spawn(fn() {
      self.handle_request_internal(request)
    })
    
    group.spawn_bg(fn() {
      self.log_request(request)
    })
    
    let response = response_task.wait()
    self.limiter.release()
    response
  })
}
```

运行测试：

```bash
cd examples/api-gateway
moon test --target native
```

## 设计原理

### 结构化并发

所有并发任务都在 `TaskGroup` 内创建，确保任务生命周期可控。父任务取消时，子任务自动取消，避免资源泄漏。

**优势**：
- 取消传播：父任务取消时子任务自动取消
- 生命周期管理：任务组结束时所有任务完成
- 错误处理：任务组内任一任务失败可统一处理

### 依赖追踪

`TaskGroup` 使用依赖追踪机制自动管理任务关系：
- 任务创建时记录父子关系
- 父任务取消时传播到所有子任务
- 任务组结束时等待所有任务完成

### 内存管理

- `Queue` 使用无界缓冲，避免背压导致的阻塞
- `Semaphore` 使用原子操作，避免锁竞争
- `TaskGroup` 使用弱引用，避免循环依赖导致的内存泄漏

## 常见问题

### 为什么需要策略收口模式？

业务代码散落大量 `@async.with_timeout_opt(500, ...)`，难以统一调参、难以审查。策略收口层将超时、重试等策略统一封装，业务层只关心业务逻辑。

### 为什么使用 TaskGroup 而不是直接 spawn？

野生 `spawn` 导致任务失控，取消信号无法传播。`TaskGroup` 确保任务生命周期可控，父任务取消时子任务自动取消。

### Queue 是无界的，会不会导致内存泄漏？

`Queue` 使用无界缓冲，避免背压导致的阻塞。真实业务里建议结合 Semaphore/限速，避免生产者无限制 put 导致内存膨胀。

### 如何选择合适的重试策略？

- **指数退避**：适用于网络请求、API 调用等可能因临时故障失败的操作
- **固定延迟**：适用于需要固定间隔重试的场景

## 仓库结构

```
Async_best_practices/
├── src/                       # 策略收口层和 API 示例
│   ├── Async_best_practices.mbt
│   └── Async_best_practices_test.mbt
└── examples/                  # 业务示例
    ├── checkout/              # 订单处理
    ├── task_group/            # 结构化并发
    ├── retry_timeout/         # 超时重试
    ├── semaphore_limiter/    # 并发控制
    ├── pipeline_queue/        # 生产者-消费者
    └── api-gateway/           # API 网关
```

## 使用方式

在 `moon.pkg.json` 中引入：

```json
{
  "import": [
    "CGaaaaaa/async-best-practices/src"
  ]
}
```

运行测试：

```bash
moon check --target native
moon test --target native
```

## 相关资源

- [MoonBit Async 官方文档](https://docs.moonbitlang.com/async)
- [Structured Concurrency](https://en.wikipedia.org/wiki/Structured_concurrency)
- [moonbitlang/async 源码](https://github.com/moonbitlang/async)

## 贡献

提交 PR 前请确保：

```bash
moon check --target native
moon test --target native
moon fmt
```

## 许可证

[Apache 2.0](LICENSE)
