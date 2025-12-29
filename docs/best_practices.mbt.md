---
name: async-best-practices-guide
description: Best practices for MoonBit Async library. Learn structured concurrency, timeout/retry patterns, semaphore rate limiting, queue pipelines, and error handling strategies.
---

## MoonBit Async 最佳实践

本文档提供可执行的原则，每条规则都配有正例/反例代码对比。

---

## 目录

- [0. 总原则（评审时逐条对照）](#0-总原则评审时逐条对照)
- [1. 推荐的学习路径](#1-推荐的学习路径)
- [2. 业务代码应该长什么样](#2-业务代码应该长什么样)
- [3. TaskGroup：结构化并发与取消传播](#3-taskgroup结构化并发与取消传播)
- [4. 超时与重试：务必统一封装](#4-超时与重试务必统一封装)
- [5. 限流：Semaphore 是最小可用方案](#5-限流semaphore-是最小可用方案)
- [6. 队列/流水线：默认要考虑背压](#6-队列流水线默认要考虑背压)
- [7. 取消传播与关键区](#7-取消传播与关键区)
- [8. 测试策略](#8-测试策略)
- [9. PR 检查清单（上线必备）](#9-pr-检查清单上线必备)
- [10. 常见反模式与修复方案](#10-常见反模式与修复方案)

---

## 0. 总原则

| 原则 | 说明 | 检查方法 |
|------|------|----------|
| **策略统一收口到 infra** | 超时/重试/限流/错误归一化不要散落在业务代码里 | 搜索业务代码中的 `@async.with_timeout`，应该很少 |
| **结构化并发（TaskGroup）** | 任务必须"有父亲"，生命周期可控，取消可传播 | 搜索 `@async.spawn`，应该为 0（都用 `group.spawn`） |
| **有限并发与背压** | 对外部依赖（DB/第三方）必须限流；队列默认需要背压策略 | 检查是否有 `Semaphore` 限流 |
| **失败要可见** | 明确区分关键任务（fail-fast）与允许失败的后台任务 | 检查 `spawn_bg` 是否只用于后台任务 |
| **测试要覆盖策略** | 至少覆盖成功/超时/瞬态失败重试成功/取消传播 | 运行 `moon test`，检查覆盖率 |

---

## 1. API 索引

| 主题 | API/函数 | 位置 |
|------|---------|------|
| **超时** | `with_timeout_opt`, `with_timeout` | `src/Async_best_practices.mbt`: `hello_async`, `timeout_example` |
| **结构化并发** | `with_task_group`, `spawn`, `spawn_bg` | `src/Async_best_practices.mbt`: `concurrent_tasks`, `demo_spawn` |
| **重试** | `retry`, `ExponentialDelay`, `FixedDelay` | `src/Async_best_practices.mbt`: `call_with_timeout_and_retry` |
| **限流** | `Semaphore::new`, `acquire`, `try_acquire` | `src/Async_best_practices.mbt`: `demo_semaphore` |
| **队列** | `Queue::new`, `put`, `get` | `src/Async_best_practices.mbt`: `demo_queue_pipeline` |

运行所有示例：

```bash
moon test --target native src/
```

---

## 2. 业务代码应该长什么样

### 目标形态

- **业务层**：只表达"我要调用什么/如何组合结果"
- **infra 层**：统一处理"怎么调用"（超时/重试/限流/错误归一化/观测）

### 反例（不推荐）❌

```moonbit no-check
// 业务代码 checkout.mbt
async fn checkout_order(id : Int) -> Result[String, String] {
  // ❌ 超时参数散落在业务代码中
  @async.with_timeout_opt(500, fn() {
    // ❌ 重试逻辑耦合在业务里
    @async.retry(ExponentialDelay(initial=100, factor=2, maximum=1000), fn() {
      call_payment_api(id)  // 真实调用
    })
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}
```

**问题**：
1. 超时参数（500ms）硬编码在业务代码中，难以统一调整
2. 重试策略（ExponentialDelay）分散在各处，难以审查
3. 业务代码混杂了策略细节，可读性差

### 正例（推荐）✅

```moonbit no-check
// src/Async_best_practices.mbt
pub async fn call_payment_with_retry(id : Int) -> Result[String, String] {
  call_with_timeout_and_retry(500, fn() {
    call_payment_api(id)  // 真实调用
  })
}

// 业务代码 checkout.mbt
async fn checkout_order(id : Int) -> Result[String, String] {
  // ✅ 业务层只处理 Result，不关心超时/重试细节
  @src.call_payment_with_retry(id)
}
```

**好处**：
1. 超时/重试策略都在 `src/`，一处修改全局生效
2. 业务代码简洁，只关注业务逻辑
3. 测试时 mock `infra` 即可，不需要真实 sleep

---

## 3. TaskGroup：结构化并发与取消传播

### 核心原则

- 用 `@async.with_task_group` 把"这一段业务"包起来
- 用 `group.spawn`/`group.spawn_bg` 创建子任务
- 默认 `allow_failure=false` 形成 fail-fast：关键任务失败时自动取消兄弟任务

### 反例：野生 spawn ❌

```moonbit no-check
async fn bad_parallel_fetch() -> (User, Order) {
  // ❌ 野生 spawn，没有 TaskGroup 管理
  let t1 = @async.spawn(fn() { fetch_user() })
  let t2 = @async.spawn(fn() { fetch_order() })
  
  // 问题：
  // 1. 如果 t1 失败，t2 还在跑（浪费资源）
  // 2. 如果父任务被取消，t1/t2 不会被取消
  // 3. 难以追踪任务的生命周期
  (t1.wait(), t2.wait())
}
```

### 正例：用 TaskGroup 管理 ✅

```moonbit no-check
async fn good_parallel_fetch() -> (User, Order) {
  // ✅ 用 TaskGroup 管理生命周期
  @async.with_task_group(fn(group) {
    let t1 = group.spawn(fn() { fetch_user() })
    let t2 = group.spawn(fn() { fetch_order() })
    
    // 好处：
    // 1. 如果 t1 失败，t2 自动取消（fail-fast）
    // 2. 父任务取消时，t1/t2 也被取消
    // 3. group 退出时，所有子任务保证结束
    (t1.wait(), t2.wait())
  })
}
```

### 什么时候用 `allow_failure=true`

只在**后台可选任务**时使用：

```moonbit no-check
@async.with_task_group(fn(group) {
  let main_task = group.spawn(fn() { 
    // 关键任务：处理订单
    process_order()
  })
  
  // ✅ 后台任务：打点日志（允许失败）
  group.spawn_bg(fn() {
    log_metrics()  // 即使失败也不影响主流程
  })
  
  main_task.wait()
})
```

**什么是"后台可选任务"**：
- 打点/监控日志
- 非关键缓存预热
- 异步通知（失败了用户也能继续操作）

---

## 4. 超时与重试：务必统一封装

**为什么需要 infra 层？**

在真实业务中，异步调用的常见问题：

| 问题 | 症状 | 后果 |
|------|------|------|
| **策略散落** | 每个业务文件都写自己的超时/重试逻辑 | 难以统一调参、代码审查困难 |
| **参数不一致** | A 文件超时 500ms，B 文件超时 300ms | 无法统一治理（例如"所有第三方调用改为 3 秒"） |
| **测试困难** | 业务代码耦合了 `@async.with_timeout_opt` | 测试时需要真实 sleep，难以 mock |

**infra 层的职责**：

```
┌─────────────────────────────────────────┐
│  业务层 (examples/checkout.mbt)          │
│                                         │
│  @src.call_payment_with_retry(101)     │  ← 只调用 wrapper
│  match result {                         │
│    Ok(v) => ...                         │
│    Err(e) => ...                        │
│  }                                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  策略收口层 (src/Async_best_practices.mbt)│
│                                         │
│  call_with_timeout_and_retry(...)      │  ← 统一超时/重试策略
│  └─> @async.with_timeout_opt(500, ...) │
│  └─> @async.retry(ExponentialDelay)    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  底层 Async 库 (moonbitlang/async)       │
└─────────────────────────────────────────┘
```

**核心价值**：
1. **策略集中**：所有超时/重试参数都在 `src/`，一处修改全局生效
2. **业务简洁**：业务代码只处理 `Result[X, String]`，不关心策略细节
3. **易于测试**：业务层测试时 mock `infra`，不需要真实 sleep

### 4.2 infra 层核心 API

**`call_with_timeout_and_retry`**：

```moonbit no-check
pub async fn[X] call_with_timeout_and_retry(
  timeout_ms : Int,
  retry : @async.RetryMethod,
  f : async () -> X,
  max_retry? : Int,
) -> Result[X, String]
```

**功能**：统一封装"超时 + 重试"策略

**使用示例**：

```moonbit no-check
// src/Async_best_practices.mbt
pub async fn call_payment_api(order_id : Int) -> Result[String, String] {
  call_with_timeout_and_retry(
    3000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      http_post("/api/pay", order_id)  // 真实 HTTP 调用
    }
  )
}

// 业务层
let result = @src.call_payment_with_retry(101)
match result {
  Ok(txn_id) => log("success")
  Err(e) => log("failed: {e}")
}
```

**参数说明**：
- `timeout_ms`：超时时间（毫秒），超时返回 `Err("timeout")`
- `retry`：重试策略（`ExponentialDelay` 或 `FixedDelay`）
- `f`：要执行的操作（async 函数）
- `max_retry?`：最大重试次数（可选）

### 4.3 如何在项目中使用 infra 层

**步骤 1**：从 `src/Async_best_practices.mbt` 复制以下函数到你的项目：
- `call_with_timeout_and_retry`
- `call_payment_with_retry`（或改为你的业务函数）

**步骤 2**：修改函数实现，替换为真实调用

```moonbit no-check
// 示例：封装支付 API
pub async fn call_payment_api(order_id : Int, amount : Int) -> Result[String, String] {
  call_with_timeout_and_retry(
    3000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      http_post("https://payment-gateway.com/api/charge", json!{...})
    }
  )
}
```

**步骤 3**：业务层引入 `infra`

```json
{
  "import": ["your-username/your-project/infra"]
}
```


### 核心原则

- **所有外部依赖**都必须有超时（避免无界等待）
- 重试只用于"瞬态错误"，不要对逻辑错误/权限错误/参数错误重试
- 重试必须可调参（initial/factor/max_retry），便于不同依赖差异化治理

### 反例：没有超时 ❌

```moonbit no-check
async fn bad_call_api() -> String {
  // ❌ 没有超时保护
  http_get("https://slow-api.com/data")  // 如果 API 挂了，会永远等待
}
```

### 正例：统一超时封装 ✅

```moonbit no-check
// src/Async_best_practices.mbt
pub async fn call_api_with_timeout(url : String) -> Result[String, String] {
  @async.with_timeout_opt(3000, fn() {  // 3 秒超时
    http_get(url)
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout after 3s")
  }
}
```

### `with_timeout` vs `with_timeout_opt`

| API | 超时行为 | 适用场景 |
|-----|---------|---------|
| `with_timeout` | 抛出 `Failure("timeout")`，会取消父任务 | 超时即失败的关键操作 |
| `with_timeout_opt` | 返回 `None`，不影响父任务 | 超时后需要降级处理的场景 |

**推荐**：在 infra 层用 `with_timeout_opt`，转为 `Result` 给业务层。

### infra 层设计思想

**为什么需要 infra 层？**

在真实业务中，异步调用的常见问题：

| 问题 | 症状 | 后果 |
|------|------|------|
| **策略散落** | 每个业务文件都写自己的超时/重试逻辑 | 难以统一调参、代码审查困难 |
| **参数不一致** | A 文件超时 500ms，B 文件超时 300ms | 无法统一治理（例如"所有第三方调用改为 3 秒"） |
| **测试困难** | 业务代码耦合了 `@async.with_timeout_opt` | 测试时需要真实 sleep，难以 mock |

**infra 层的职责**：

```
┌─────────────────────────────────────────┐
│  业务层 (examples/checkout.mbt)          │
│  @src.call_payment_with_retry(101)     │  ← 只调用 wrapper
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  策略收口层 (src/Async_best_practices.mbt)│
│  call_with_timeout_and_retry(...)       │  ← 统一超时/重试策略
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  底层 Async 库 (moonbitlang/async)       │
└─────────────────────────────────────────┘
```

**核心价值**：
1. **策略集中**：所有超时/重试参数都在 `src/`，一处修改全局生效
2. **业务简洁**：业务代码只处理 `Result[X, String]`，不关心策略细节
3. **易于测试**：业务层测试时 mock `infra`，不需要真实 sleep

**如何在项目中使用**：

```bash
# 步骤 1：从 src/Async_best_practices.mbt 复制策略收口层代码到你的项目
# 复制 call_with_timeout_and_retry 等函数

# 步骤 2：修改 clients.mbt，替换为真实调用
# 步骤 3：业务层引入 infra 包
```

### 重试策略选择

#### 固定延迟（Fixed Delay）

```moonbit no-check
@async.retry(FixedDelay(delay=100, max_retry=3), fn() {
  call_api()
})
```

**适用场景**：
- 快速瞬态失败（例如网络抖动）
- 重试间隔短（< 200ms）

#### 指数退避（Exponential Backoff）

```moonbit no-check
@async.retry(ExponentialDelay(initial=100, factor=2, maximum=2000), fn() {
  call_api()
})
```

**重试时序**：100ms → 200ms → 400ms → 800ms → 1600ms → 2000ms（上限）

**适用场景**：
- 外部服务过载（需要给对方恢复时间）
- 重试次数多（> 3 次）

### 什么错误不应该重试

```moonbit no-check
async fn should_not_retry_example(id : Int) -> Result[String, String] {
  call_api(id) catch {
    // ❌ 不要对这些错误重试：
    "permission_denied" => Err("no permission")    // 权限错误
    "invalid_param" => Err("bad request")          // 参数错误
    "not_found" => Err("resource not found")       // 资源不存在
    
    // ✅ 只对这些错误重试：
    "network_error" => retry_call_api(id)          // 网络抖动
    "timeout" => retry_call_api(id)                // 超时
    "503" => retry_call_api(id)                    // 服务暂时不可用
  }
}
```

---

## 5. 限流：Semaphore 是最小可用方案

### 核心原则

- 对 DB 连接、第三方 API 调用、CPU 密集任务都加并发上限
- 先用 Semaphore（简单、好审查），复杂场景再引入更高级的 rate limiter

### 反例：无限并发 ❌

```moonbit no-check
async fn bad_batch_process(orders : Array[Order]) {
  @async.with_task_group(fn(group) {
    // ❌ 如果 orders 有 10000 个，会同时发起 10000 个 DB 连接
    for order in orders {
      group.spawn_bg(fn() {
        db_update(order)  // DB 连接池被打爆
      })
    }
  })
}
```

**问题**：
- DB 连接池耗尽（例如 MySQL 默认最大连接 151）
- 第三方 API 限流（返回 429 Too Many Requests）
- 服务器 CPU/内存耗尽

### 正例：用 Semaphore 限流 ✅

```moonbit no-check
async fn good_batch_process(orders : Array[Order]) {
  let sem = @semaphore.Semaphore::new(20)  // 最大 20 并发
  
  @async.with_task_group(fn(group) {
    for order in orders {
      group.spawn_bg(fn() raise {
        sem.acquire()  // 阻塞等待槽位
        db_update(order)
        sem.release()
      })
    }
  })
}
```

**好处**：
- 最多 20 个并发，保护 DB 连接池
- 自动背压：新任务等待旧任务完成

### 阻塞 vs 非阻塞获取

#### `acquire()`：阻塞等待

```moonbit no-check
let sem = @semaphore.Semaphore::new(5)
sem.acquire()  // 如果没有槽位，会一直等
// ... 关键区操作
sem.release()
```

**适用场景**：必须执行的任务（例如订单处理）

#### `try_acquire()`：非阻塞尝试

```moonbit no-check
let sem = @semaphore.Semaphore::new(5)
match sem.try_acquire() {
  Some(_) => {
    // ... 关键区操作
    sem.release()
  }
  None => {
    // 快速失败，或者加入队列稍后重试
    log("too busy, skip this task")
  }
}
```

**适用场景**：可降级的任务（例如实时推荐，繁忙时跳过）

---

## 6. 队列/流水线：默认要考虑背压

### 核心原则

- `aqueue.Queue` 是**无界缓冲**：生产者一直 put 会导致内存增长
- 业务中一般需要"背压策略"（例如：用 Semaphore 控制 producer、分批 put、或引入有界队列）

### 反例：无界队列 + 无限生产 ❌

```moonbit no-check
async fn bad_pipeline() {
  let queue = @aqueue.Queue::new()
  
  @async.with_task_group(fn(group) {
    // ❌ 生产者无限 put，消费者处理慢时内存爆炸
    group.spawn_bg(fn() {
      for i in 0..<1_000_000 {
        queue.put(i)  // 内存持续增长
      }
    })
    
    // 消费者处理慢
    group.spawn_bg(fn() {
      for {
        let item = queue.get()
        @async.sleep(100)  // 每个任务 100ms
      }
    })
  })
}
```

**问题**：
- 生产速度 >> 消费速度，队列堆积 100 万条数据
- 内存耗尽（OOM）

### 正例：用 Semaphore 控制生产速度 ✅

```moonbit no-check
async fn good_pipeline() {
  let queue = @aqueue.Queue::new()
  let sem = @semaphore.Semaphore::new(100)  // 最多 100 条数据在队列中
  
  @async.with_task_group(fn(group) {
    // 生产者：用 Semaphore 控制速度
    group.spawn_bg(fn() raise {
      for i in 0..<1_000_000 {
        sem.acquire()  // 队列满时，生产者阻塞
        queue.put(i)
      }
      queue.put(-1)  // 终止信号
    })
    
    // 消费者
    group.spawn_bg(fn() {
      for {
        let item = queue.get()
        guard item != -1 else { break }
        process(item)
        sem.release()  // 处理完后释放槽位
      }
    })
  })
}
```

**好处**：
- 队列最多 100 条数据，内存可控
- 生产速度自动匹配消费速度（背压）

---

## 7. 取消传播与关键区

### 核心原则

- 取消信号应该能传播到所有子任务
- 只在"不可中断的关键区"使用 `protect_from_cancel`

### 什么时候用 `protect_from_cancel`

**反例：滥用保护** ❌

```moonbit no-check
async fn bad_use_protect() {
  // ❌ 整个业务逻辑都保护，取消信号失效
  @async.protect_from_cancel(fn() {
    let user = fetch_user()
    let order = fetch_order()
    update_db(user, order)
  })
}
```

**正例：只保护关键区** ✅

```moonbit no-check
async fn good_use_protect() {
  let user = fetch_user()      // 可以被取消
  let order = fetch_order()    // 可以被取消
  
  // ✅ 只保护"写 DB"的关键操作
  @async.protect_from_cancel(fn() {
    update_db(user, order)  // 不可中断，避免数据不一致
  })
}
```

**什么是"关键区"**：
- 数据库事务（中途取消会导致数据不一致）
- 文件写入（中途取消会导致文件损坏）
- 支付扣款（中途取消会导致金额错误）

---

## 8. 测试策略

### 核心原则

本仓库所有示例都配套 `async test`，覆盖以下场景：

| 场景 | 测试方法 | 示例 |
|------|---------|------|
| **正常流程** | 验证成功输出 | `examples/checkout`: 订单处理成功 |
| **超时** | 模拟慢操作，验证超时错误 | `examples/retry_timeout`: `demo_retry_timeout_fail` |
| **瞬态失败** | 模拟重试后成功 | `src/Async_best_practices_test.mbt`: order 101/102 |
| **取消传播** | 模拟子任务失败，验证兄弟任务被取消 | `examples/task_group`: fail-fast |
| **并发限制** | 观测最大并发数 | `examples/semaphore_limiter` |

### 快照测试（Snapshot Testing）

用 `inspect` 验证完整输出：

```moonbit no-check
async test "checkout_flow" {
  let out = checkout_orders([101, 102])
  inspect(
    out,
    content=(
      #|start order 101
      #|order 101 success
      #|start order 102
      #|order 102 success
      #|
    ),
  )
}
```

**好处**：
- 一眼看懂预期行为
- 输出格式变化时，测试会失败（防止意外修改）

### 如何测试超时

```moonbit no-check
async test "timeout_returns_err" {
  let result = @src.call_with_timeout_and_retry(50, fn() {
    @async.sleep(200)  // 操作耗时 200ms，超时 50ms
    "ok"
  })
  
  inspect(result, content=(#|Err("timeout")|))
}
```

### 如何测试重试

```moonbit no-check
async test "retry_then_success" {
  let mut attempts = 0
  let result = @src.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 3 {
      raise Failure("transient")  // 前 2 次失败
    }
    "ok"  // 第 3 次成功
  })
  
  inspect(result, content=(#|Ok("ok")|))
  assert_eq!(attempts, 3)  // 验证重试了 3 次
}
```

---

## 9. PR 检查清单

在提交 PR 前，逐条检查：

### 外部调用

- ☑️ 是否都通过 infra wrapper？（搜索业务代码中的 `@async.with_timeout`，应该为 0）
- ☑️ 是否设置超时？（所有外部调用必须有超时保护）
- ☑️ 重试策略是否合理？（不对逻辑错误重试、指数退避参数合理）

### 并发

- ☑️ 是否使用 TaskGroup？（搜索 `@async.spawn`，应该为 0）
- ☑️ 是否避免野生 spawn？（所有并发都在 `with_task_group` 内）
- ☑️ 是否有限流？（DB/API 调用是否用 Semaphore 限制并发）

### 取消

- ☑️ 入口取消能否传播到子任务？（用 TaskGroup 保证传播）
- ☑️ 是否滥用 `protect_from_cancel`？（只在关键区使用）

### 测试

- ☑️ 是否覆盖超时场景？
- ☑️ 是否覆盖重试场景？
- ☑️ 是否覆盖取消传播？
- ☑️ 测试是否能稳定复现？（不依赖真实外部服务）

---

## 10. 常见反模式与修复方案

### 反模式 1：业务代码中散落超时参数

**症状**：
```moonbit no-check
// 文件 A
@async.with_timeout_opt(500, ...)

// 文件 B
@async.with_timeout_opt(300, ...)

// 文件 C
@async.with_timeout_opt(500, ...)
```

**问题**：无法统一调整（例如"所有第三方调用改为 3 秒"）

**修复**：
```moonbit no-check
// src/Async_best_practices.mbt
pub const THIRD_PARTY_TIMEOUT : Int = 3000

pub async fn call_third_party_api[X](op : () -> X) -> Result[X, String] {
  @async.with_timeout_opt(THIRD_PARTY_TIMEOUT, op) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}
```

### 反模式 2：野生 spawn

**症状**：
```moonbit no-check
let t1 = @async.spawn(fn() { ... })
let t2 = @async.spawn(fn() { ... })
```

**问题**：取消传播失效、资源泄漏

**修复**：
```moonbit no-check
@async.with_task_group(fn(group) {
  let t1 = group.spawn(fn() { ... })
  let t2 = group.spawn(fn() { ... })
  ...
})
```

### 反模式 3：对逻辑错误重试

**症状**：
```moonbit no-check
@async.retry(ExponentialDelay(...), fn() {
  validate_input(data) raise {  // 参数错误不应该重试
    err => raise err
  }
})
```

**问题**：参数错误重试 10 次浪费时间

**修复**：
```moonbit no-check
// 先验证参数，再重试网络调用
validate_input(data) raise { err => return Err(err) }

@async.retry(ExponentialDelay(...), fn() {
  call_api(data)  // 只重试网络调用
})
```

### 反模式 4：无界队列 + 无限生产

**症状**：内存持续增长，最终 OOM

**修复**：用 Semaphore 控制队列大小（见第 6 节）

---

## 总结

遵循这些原则，你的异步代码将：
- ✅ **可维护**：策略集中在 infra，易于调整
- ✅ **可测试**：业务逻辑与策略分离，测试简单
- ✅ **可靠**：超时/重试/限流保护，避免资源耗尽
- ✅ **高性能**：结构化并发 + 限流，充分利用资源

**下一步**：
1. 运行所有 `examples/` 示例
2. 用 PR 检查清单审查代码
3. 从 `src/Async_best_practices.mbt` 复制策略收口层代码到项目
