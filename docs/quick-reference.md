# MoonBit Async 快速参考

常用 Async API、模式和解决方案的快速查询。

---

## 目录

- [常用 API 速查表](#常用-api-速查表)
- [典型模式速查](#典型模式速查)
- [常见错误与解决方案](#常见错误与解决方案)
- [性能优化速查](#性能优化速查)
- [调试技巧](#调试技巧)

---

## 常用 API 速查表

### 超时控制

| API | 超时行为 | 返回类型 | 使用场景 |
|-----|---------|---------|---------|
| `@async.with_timeout_opt(ms, fn)` | 返回 `None` | `T?` | 超时后需要降级处理 ⭐ 推荐 |
| `@async.with_timeout(ms, fn)` | 抛出 `Failure` | `T` | 超时即失败的关键操作 |

```moonbit
// 推荐：返回 Option
@async.with_timeout_opt(1000, fn() { ... }) match {
  Some(v) => Ok(v)
  None => Err("timeout")
}

// 关键操作：超时抛异常
@async.with_timeout(1000, fn() { ... })  // 超时会 raise Failure
```

### 重试策略

| 策略 | 适用场景 | 参数示例 |
|------|---------|---------|
| `ExponentialDelay` | 服务过载、rate limit | `initial=100, factor=2, maximum=2000` |
| `FixedDelay` | 快速瞬态失败、网络抖动 | `delay=100, max_retry=3` |

```moonbit
// 指数退避（推荐）
@async.retry(ExponentialDelay(initial=100, factor=2, maximum=2000), fn() {
  call_api()
})

// 固定延迟（快速重试）
@async.retry(FixedDelay(delay=100, max_retry=3), fn() {
  call_api()
})
```

### 结构化并发

| API | 用途 | 失败行为 |
|-----|------|---------|
| `group.spawn(fn)` | 关键任务 | fail-fast（一个失败，全部取消）|
| `group.spawn_bg(fn)` | 后台任务 | 允许失败，不影响主流程 |
| `task.wait()` | 等待任务完成 | 返回任务结果或传播错误 |

```moonbit
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { ... })         // 关键任务
  group.spawn_bg(fn() { log_metrics() })     // 后台任务
  t1.wait()                                  // 等待结果
})
```

### 并发控制

| API | 用途 | 阻塞行为 |
|-----|------|---------|
| `Semaphore::new(n)` | 创建信号量 | - |
| `semaphore.acquire()` | 阻塞获取 | 等待直到有空闲槽位 |
| `semaphore.try_acquire()` | 非阻塞获取 | 立即返回 `Option` |
| `semaphore.release()` | 释放槽位 | - |

```moonbit
let sem = @semaphore.Semaphore::new(10)  // 最大 10 并发

// 阻塞获取（推荐）
sem.acquire()
process()
sem.release()

// 非阻塞获取（可降级场景）
match sem.try_acquire() {
  Some(_) => { process(); sem.release() }
  None => log("too busy")
}
```

### 队列与流水线

| API | 用途 | 特点 |
|-----|------|------|
| `@aqueue.Queue::new()` | 创建队列 | 无界缓冲 ⚠️ 需要背压 |
| `queue.put(item)` | 放入数据 | 非阻塞 |
| `queue.get()` | 取出数据 | 阻塞等待 |

```moonbit
let queue = @aqueue.Queue::new()
let sem = @semaphore.Semaphore::new(100)  // ✅ 用 Semaphore 控制队列大小

// Producer
sem.acquire()
queue.put(item)

// Consumer
let item = queue.get()
process(item)
sem.release()
```

---

## 典型模式速查

### 模式 1：外部 API 调用

```moonbit
// src/Async_best_practices.mbt
pub async fn call_api(url : String) -> Result[String, String] {
  @async.with_timeout_opt(3000, fn() {
    @async.retry(ExponentialDelay(initial=100, factor=2, maximum=1000), fn() {
      http_get(url)
    })
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}

// 业务层
let result = @src.call_with_timeout_and_retry(3000, @async.ExponentialDelay(...), fn() {
  http_get("https://api.example.com/data")
})
```

### 模式 2：并行查询多个数据源

```moonbit
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { @src.call_with_timeout_and_retry(1000, ..., fn() { fetch_user(uid) }) })
  let t2 = group.spawn(fn() { @src.call_with_timeout_and_retry(1000, ..., fn() { fetch_orders(uid) }) })
  let t3 = group.spawn(fn() { @src.call_with_timeout_and_retry(1000, ..., fn() { fetch_recommendations(uid) }) })
  
  (t1.wait(), t2.wait(), t3.wait())  // 任一失败会取消其他
})
```

### 模式 3：批量处理（有限并发）

```moonbit
let sem = @semaphore.Semaphore::new(20)  // 最大 20 并发
@async.with_task_group(fn(group) {
  for item in items {
    group.spawn_bg(fn() raise {
      sem.acquire()
      process(item)
      sem.release()
    })
  }
})
```

### 模式 4：生产者-消费者流水线

```moonbit
let queue = @aqueue.Queue::new()
let sem = @semaphore.Semaphore::new(100)

@async.with_task_group(fn(group) {
  // Producer
  group.spawn_bg(fn() raise {
    for item in items {
      sem.acquire()
      queue.put(item)
    }
    queue.put(STOP_SIGNAL)
  })
  
  // Consumers
  for _ in 0..<workers {
    group.spawn_bg(fn() {
      for {
        let item = queue.get()
        guard item != STOP_SIGNAL else { break }
        process(item)
        sem.release()
      }
    })
  }
})
```

---

## 常见错误与解决方案

### ❌ 错误 1：野生 spawn

**症状**：任务失控，取消信号不传播

```moonbit
// ❌ 错误
let t1 = @async.spawn(fn() { ... })  // 没有 TaskGroup 管理
let t2 = @async.spawn(fn() { ... })
```

**解决方案**：

```moonbit
// ✅ 正确
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { ... })
  let t2 = group.spawn(fn() { ... })
})
```

---

### ❌ 错误 2：没有超时保护

**症状**：外部服务挂了，永远等待

```moonbit
// ❌ 错误
async fn call_api() -> String {
  http_get("https://api.example.com")  // 无超时
}
```

**解决方案**：

```moonbit
// ✅ 正确
async fn call_api() -> Result[String, String] {
  @async.with_timeout_opt(3000, fn() {
    http_get("https://api.example.com")
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}
```

---

### ❌ 错误 3：无限并发

**症状**：DB 连接池耗尽、API 被限流

```moonbit
// ❌ 错误
@async.with_task_group(fn(group) {
  for item in 10000_items {
    group.spawn_bg(fn() { db_update(item) })  // 10000 并发！
  }
})
```

**解决方案**：

```moonbit
// ✅ 正确
let sem = @semaphore.Semaphore::new(20)
@async.with_task_group(fn(group) {
  for item in 10000_items {
    group.spawn_bg(fn() raise {
      sem.acquire()
      db_update(item)
      sem.release()
    })
  }
})
```

---

### ❌ 错误 4：对逻辑错误重试

**症状**：参数错误重试 10 次，浪费时间

```moonbit
// ❌ 错误
@async.retry(ExponentialDelay(...), fn() {
  validate_and_process(data)  // 参数错误不应该重试
})
```

**解决方案**：

```moonbit
// ✅ 正确
validate(data)?  // 先验证参数
@async.retry(ExponentialDelay(...), fn() {
  process(data)  // 只重试网络/瞬态错误
})
```

---

### ❌ 错误 5：滥用 protect_from_cancel

**症状**：取消信号失效，资源泄漏

```moonbit
// ❌ 错误
@async.protect_from_cancel(fn() {
  let user = fetch_user()      // 可以被取消
  let order = fetch_order()    // 可以被取消
  update_db(user, order)       // 不可中断
})
```

**解决方案**：

```moonbit
// ✅ 正确
let user = fetch_user()        // 可以被取消
let order = fetch_order()      // 可以被取消
@async.protect_from_cancel(fn() {
  update_db(user, order)       // 只保护关键区
})
```

---

### ❌ 错误 6：无界队列 + 无限生产

**症状**：内存持续增长，最终 OOM

```moonbit
// ❌ 错误
let queue = @aqueue.Queue::new()
for i in 0..<1_000_000 {
  queue.put(i)  // 队列无界，内存爆炸
}
```

**解决方案**：

```moonbit
// ✅ 正确
let queue = @aqueue.Queue::new()
let sem = @semaphore.Semaphore::new(100)  // 队列最多 100 条

// Producer
sem.acquire()
queue.put(item)

// Consumer
let item = queue.get()
process(item)
sem.release()
```

---

## 性能优化速查

### 1. 并发数调优

| 场景 | 推荐并发数 | 理由 |
|------|-----------|------|
| DB 查询 | 连接池大小 - 10 | 留余量，避免打满 |
| 第三方 API | QPS 限制 / 平均耗时 | 遵守对方限制 |
| CPU 密集 | CPU 核心数 × 1.5 ~ 2 | 充分利用 CPU |
| IO 密集 | 根据响应时间动态调整 | 平衡吞吐与延迟 |

### 2. 超时时间设置

| 依赖类型 | 推荐超时 | 说明 |
|---------|---------|------|
| 内部 RPC | 500ms - 1s | 同机房延迟低 |
| 第三方 API | 3s - 5s | 网络不稳定 |
| DB 查询 | 1s - 2s | 慢查询可能阻塞 |
| 文件上传 | 10s - 30s | 大文件传输慢 |

### 3. 重试策略选择

| 场景 | 策略 | 参数建议 |
|------|------|---------|
| 网络抖动 | FixedDelay | `delay=100, max_retry=3` |
| 服务过载 | ExponentialDelay | `initial=100, factor=2, max=2000` |
| Rate limit | ExponentialDelay | `initial=1000, factor=2, max=10000` |

### 4. 内存优化

- ✅ 用 Semaphore 控制队列大小
- ✅ 分批处理大数据集
- ✅ 及时释放资源（连接、文件）
- ❌ 避免在循环中创建大量 TaskGroup

---

## 调试技巧

### 1. 打印时序日志

```moonbit
let log = StringBuilder::new()
log.write_string("Task 1 start\n")
@async.sleep(100)
log.write_string("Task 1 end\n")
println(log.to_string())
```

### 2. 用 inspect 验证输出

```moonbit
test "verify_behavior" {
  let result = my_async_function()
  inspect(result, content=(#|Expected output|))
}
```

### 3. 减少并发排查问题

```moonbit
// 调试时：改为串行
let sem = @semaphore.Semaphore::new(1)  // 只允许 1 个并发
```

### 4. 观测最大并发数

```moonbit
let active_count = @ref.new(0)
let max_count = @ref.new(0)

sem.acquire()
active_count.val = active_count.val + 1
if active_count.val > max_count.val {
  max_count.val = active_count.val
}
// ... 处理
active_count.val = active_count.val - 1
sem.release()

println("Max concurrency: \{max_count.val}")
```

### 5. 追踪取消传播

```moonbit
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() {
    println("Task 1 start")
    @async.sleep(100)
    println("Task 1 end")  // 如果被取消，不会打印
  })
  
  let t2 = group.spawn(fn() {
    println("Task 2 start")
    raise Failure("error")  // 触发取消
  })
  
  t1.wait()
})
```

---

## 快速决策树

### 何时使用 TaskGroup？

```
需要并发执行多个任务？
├─ 是 → 用 TaskGroup
└─ 否 → 直接顺序调用
```

### 何时使用 spawn vs spawn_bg？

```
任务失败时应该取消其他任务？
├─ 是（关键任务）→ group.spawn()
└─ 否（后台任务）→ group.spawn_bg()
```

### 何时使用 Semaphore？

```
是否调用外部依赖（DB/API）或 CPU 密集？
├─ 是 → 必须用 Semaphore 限流
└─ 否 → 不需要
```

### 何时使用重试？

```
错误类型是？
├─ 网络抖动/服务过载 → 重试
├─ 参数错误/权限错误 → 不重试
└─ 逻辑错误 → 不重试
```

---

## 完整 API 索引

> 以下 API 索引来自 `src/Async_best_practices.mbt`，包含 17 个系统化示例函数，每个都有可运行的测试代码。

### 基础异步操作

#### 1. `hello_async` — 基本超时

```moonbit
pub async fn hello_async() -> String
```

**功能**：演示基本的超时功能

**关键 API**：`@async.with_timeout_opt(timeout_ms, fn() { ... })`

**学习重点**：理解 `with_timeout_opt` 的基本用法，超时时返回 `None`

---

#### 2. `concurrent_tasks` — 并发执行多个任务

```moonbit
pub async fn concurrent_tasks() -> Array[Int]
```

**功能**：演示 `TaskGroup` 的用法，并发执行多个任务

**关键 API**：
- `@async.with_task_group(fn(group) { ... })`
- `group.spawn(fn() { ... })`
- `task.wait()`

**学习重点**：用 `TaskGroup` 管理并发任务，所有任务都在 group 内，生命周期可控

---

#### 3. `timeout_example` — 超时处理

```moonbit
pub async fn timeout_example() -> String
```

**功能**：演示超时场景（任务耗时超过超时时间）

**关键 API**：`@async.with_timeout_opt(timeout_ms, fn() { ... })` + `@async.sleep(ms)`

**学习重点**：超时时返回 `None`，业务层可以根据 `None` 做降级处理

---

### 并发模式

#### 4. `sequential_pipeline` — 顺序流水线

```moonbit
pub async fn sequential_pipeline() -> Int
```

**功能**：顺序执行异步操作，构建数据处理流水线

**学习重点**：链式调用多个 `async fn`

---

#### 5. `race_example` — 竞争条件

```moonbit
pub async fn race_example() -> String
```

**功能**：演示多个任务竞争，第一个完成者胜出

**关键 API**：`@async.race([task1, task2, task3])`

**学习重点**：用 `race` 实现"最快响应"场景

---

#### 6. `retry_example` — 重试机制

```moonbit
pub async fn retry_example() -> Result[String, String]
```

**功能**：演示瞬态失败的重试机制

**关键 API**：`@async.retry(ExponentialDelay(...), fn() { ... })`

**学习重点**：区分瞬态错误（可重试）与逻辑错误（不可重试）

---

#### 7. `error_handling_example` — 错误处理

```moonbit
pub async fn error_handling_example() -> String
```

**功能**：异步任务中的错误处理与取消传播

**学习重点**：TaskGroup 的 fail-fast 行为

---

#### 8. `batch_processing` — 批量处理

```moonbit
pub async fn batch_processing() -> Array[Int]
```

**功能**：批量处理任务，结合并发与限流

**学习重点**：用 Semaphore 控制批量处理的并发数

---

### TaskGroup 详解

#### 9. `demo_spawn` — spawn vs spawn_bg

```moonbit
pub async fn demo_spawn() -> String
```

**功能**：演示 `TaskGroup.spawn` 和 `spawn_bg` 的区别

**关键 API**：
- `group.spawn(fn() { ... })`：关键任务，失败会取消兄弟任务
- `group.spawn_bg(fn() { ... })`：后台任务，允许失败

**学习重点**：何时用 `spawn`（关键任务），何时用 `spawn_bg`（后台任务）

---

#### 10. `demo_with_timeout` — 超时机制

```moonbit
pub async fn demo_with_timeout() -> String
```

**功能**：演示 `with_timeout` 的超时机制和取消传播

**关键 API**：`@async.with_timeout(ms, fn() { ... })`

**学习重点**：`with_timeout` 会抛出 `Failure`，会取消父任务

---

#### 11. `demo_with_timeout_opt` — 超时返回 Option

```moonbit
pub async fn demo_with_timeout_opt() -> String
```

**功能**：`with_timeout_opt` 返回 `Option` 类型

**关键 API**：`@async.with_timeout_opt(ms, fn() { ... })`

**学习重点**：推荐使用 `with_timeout_opt`，超时返回 `None`，不取消父任务

---

### 并发控制

#### 12. `demo_semaphore` — 信号量限流

```moonbit
pub async fn demo_semaphore() -> String
```

**功能**：信号量限流

**关键 API**：
- `@semaphore.Semaphore::new(n)`：创建信号量
- `semaphore.acquire()`：阻塞获取
- `semaphore.release()`：释放槽位

**学习重点**：用 Semaphore 限制最大并发数

---

#### 13. `demo_semaphore_try_acquire` — 非阻塞获取

```moonbit
pub async fn demo_semaphore_try_acquire() -> String
```

**功能**：信号量非阻塞获取

**关键 API**：`semaphore.try_acquire()`：立即返回 `Option`

**学习重点**：何时用 `acquire()`（必须执行），何时用 `try_acquire()`（可降级）

---

### 重试策略

#### 14. `demo_retry_fixed_delay` — 固定延迟重试

```moonbit
pub async fn demo_retry_fixed_delay() -> String
```

**功能**：固定延迟重试

**关键 API**：`@async.retry(FixedDelay(delay=100, max_retry=3), fn() { ... })`

**学习重点**：适用于快速瞬态失败

---

#### 15. `demo_retry_exponential` — 指数退避重试

```moonbit
pub async fn demo_retry_exponential() -> String
```

**功能**：指数退避重试

**关键 API**：`@async.retry(ExponentialDelay(initial=100, factor=2, maximum=2000), fn() { ... })`

**学习重点**：适用于服务过载、rate limit 等场景

---

### 队列与流水线

#### 16. `demo_queue_pipeline` — 队列流水线

```moonbit
pub async fn demo_queue_pipeline() -> String
```

**功能**：队列流水线（生产者-消费者）

**关键 API**：
- `@aqueue.Queue::new()`：创建队列
- `queue.put(item)`：放入数据
- `queue.get()`：取出数据

**学习重点**：用队列解耦生产与消费，注意背压控制

---

### 关键区保护

#### 17. `demo_protect_from_cancel` — 关键区防取消

```moonbit
pub async fn demo_protect_from_cancel() -> String
```

**功能**：关键区防取消

**关键 API**：`@async.protect_from_cancel(fn() { ... })`

**学习重点**：只保护关键区（如 DB 提交），不要滥用

---

## 如何查找 API

### 按功能查找

| 需求 | 推荐 API | 所在函数 |
|------|---------|---------|
| 超时 | `with_timeout_opt` | `hello_async`, `demo_with_timeout_opt` |
| 重试 | `retry` | `retry_example`, `demo_retry_exponential` |
| 并发 | `TaskGroup` | `concurrent_tasks`, `demo_spawn` |
| 限流 | `Semaphore` | `demo_semaphore`, `batch_processing` |
| 队列 | `Queue` | `demo_queue_pipeline` |

### 运行测试

所有 API 示例都有对应的测试，运行：

```bash
moon test --target native src/
```

---

## 相关文档

- [最佳实践详解](./best_practices.mbt.md)
- [常见问题 FAQ](./faq.md)
- [示例代码](../examples/)

---

**快速参考更新时间**: 2025-12-28

