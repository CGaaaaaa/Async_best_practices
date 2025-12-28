# examples/ — 可运行的业务示例

> 从简单到复杂，6 个渐进式示例，展示如何在实际业务中使用 MoonBit Async

---

## 📋 示例索引（按推荐阅读顺序）

| 示例 | 核心知识点 | 代码行数 | 测试数 | 推荐时间 |
|------|-----------|---------|-------|---------|
| [1. checkout](#1-checkout---最小业务闭环) | 业务与 infra 分层 | ~20 | 1 | 10 分钟 |
| [2. task_group](#2-task_group---结构化并发) | TaskGroup、fail-fast | ~40 | 1 | 20 分钟 |
| [3. retry_timeout](#3-retry_timeout---超时与重试) | 统一超时/重试策略 | ~50 | 3 | 20 分钟 |
| [4. semaphore_limiter](#4-semaphore_limiter---并发限流) | 并发限流、资源保护 | ~30 | 1 | 15 分钟 |
| [5. pipeline_queue](#5-pipeline_queue---生产者-消费者) | 队列、并行消费 | ~40 | 1 | 20 分钟 |
| [6. api-gateway](#6-api-gateway---综合真实案例) | 生产级综合应用 | ~250 | 9 | 60 分钟 |

---

## 1. checkout — 最小业务闭环

> **推荐阅读顺序：第 1 个**（10 分钟上手）

### 核心知识点

- ✅ **业务与 infra 分层**：业务代码只处理 `Result`，策略在 `infra` 统一
- ✅ **快照测试**：用 `inspect` 验证完整输出
- ✅ **错误处理**：展示成功/失败两种路径

### 快速运行

```bash
cd examples/checkout
moon test --target native
```

### 关键代码

```moonbit
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  for id in order_ids {
    log.write_string("start order \{id}\n")
    
    // ✅ 业务层只调用 infra wrapper，不关心超时/重试细节
    let outcome = @infra.call_payment_with_retry(id)
    
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  log.to_string()
}
```

**要点**：业务代码只表达"处理订单列表，记录结果"，超时/重试策略都在 `infra/clients.mbt` 中。

---

## 2. task_group — 结构化并发

> **推荐阅读顺序：第 2 个**（理解并发任务管理）

### 核心知识点

- ✅ **结构化并发**：用 `TaskGroup` 管理任务生命周期
- ✅ **fail-fast 取消传播**：一个任务失败时，自动取消兄弟任务
- ✅ **任务等待**：用 `wait()` 获取任务结果

### 快速运行

```bash
cd examples/task_group
moon test --target native
```

### 关键代码

```moonbit
pub async fn demo_task_group() -> String {
  let log = StringBuilder::new()
  
  // ✅ 用 TaskGroup 管理并发任务
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
        raise Failure("Task 2 error")  // 模拟失败
        2
      })
      
      let task3 = group.spawn(fn() {
        @async.sleep(200)
        log.write_string("Task 3 finished\n")
        3
      })

      // 等待任务（如果其中一个失败，整个组会取消）
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

---

## 3. retry_timeout — 超时与重试

> **推荐阅读顺序：第 3 个**（理解策略封装）

### 核心知识点

- ✅ **统一超时封装**：所有外部调用都通过 `infra` 设置超时
- ✅ **重试策略**：区分瞬态失败（可重试）与逻辑错误（不可重试）
- ✅ **错误归一化**：返回 `Result[X, String]`，业务层统一处理

### 快速运行

```bash
cd examples/retry_timeout
moon test --target native
```

### 关键代码

```moonbit
// 场景 1：操作成功
pub async fn demo_retry_timeout_success() -> String {
  let result = @infra.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(100)  // 模拟操作耗时 100ms
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
  let result = @infra.call_with_timeout_and_retry(
    50,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(200)  // 操作耗时 200ms，超时 50ms
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

---

## 4. semaphore_limiter — 并发限流

> **推荐阅读顺序：第 4 个**（理解并发控制）

### 核心知识点

- ✅ **并发限流**：用 `Semaphore` 限制最大并发数
- ✅ **资源保护**：防止 DB 连接池、API 调用被打爆
- ✅ **背压机制**：任务自动等待，不会无限堆积

### 快速运行

```bash
cd examples/semaphore_limiter
moon test --target native
```

### 关键代码

```moonbit
pub async fn demo_semaphore_limiter() -> String {
  let log = StringBuilder::new()
  
  @async.with_task_group(fn(group) {
    let semaphore = @semaphore.Semaphore::new(2)  // ✅ 最大并发 2
    
    // 创建 5 个任务，但最多同时运行 2 个
    for i in 0..<5 {
      group.spawn_bg(fn() raise {
        semaphore.acquire()  // 阻塞等待槽位
        log.write_string("Task \{i} acquired semaphore\n")
        
        @async.sleep(100)  // 模拟工作
        
        semaphore.release()
        log.write_string("Task \{i} released semaphore\n")
      })
    }
    
    @async.sleep(500)  // 等待所有任务完成
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

---

## 5. pipeline_queue — 生产者-消费者

> **推荐阅读顺序：第 5 个**（理解队列与背压）

### 核心知识点

- ✅ **生产者-消费者模式**：用 `aqueue.Queue` 解耦生产与消费
- ✅ **并行消费**：多个 worker 并行处理数据
- ✅ **背压机制**：用 Semaphore 控制队列大小（防止内存爆炸）

### 快速运行

```bash
cd examples/pipeline_queue
moon test --target native
```

### 关键代码

```moonbit
pub async fn pipeline_sum(n_items : Int, workers : Int) -> Int {
  @async.with_task_group(fn(group) {
    let q = @aqueue.Queue::new()  // ✅ 创建队列

    // Producer：生产 1..n_items
    group.spawn_bg(fn() {
      for i in 1..(n_items + 1) {
        q.put(i)
      }
      // 发送终止信号
      for _ in 0..<workers {
        q.put(0)  // 0 表示结束
      }
    })

    // Consumers：多个 worker 并行消费
    let tasks = Array::new()
    for _ in 0..<workers {
      tasks.push(group.spawn(fn() -> Int raise {
        let mut acc = 0
        for {
          let v = q.get()  // ✅ 阻塞获取数据
          guard v != 0 else { break }  // 收到终止信号
          acc = acc + v
        }
        acc
      }))
    }

    // Aggregate：汇总所有 worker 的结果
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

**⚠️ 注意**：`aqueue.Queue` 是无界缓冲，生产速度 > 消费速度时会导致内存增长。实际项目中需要用 Semaphore 控制队列大小。

---

## 6. api-gateway — 综合真实案例

> **推荐阅读顺序：完成其他示例后**

### 核心知识点

- ✅ **TaskGroup + Semaphore + 超时 + 重试 + infra 层**：综合运用所有 Async 模式
- ✅ **真实场景**：API 网关的路由、限流、熔断、健康检查
- ✅ **并发处理**：批量请求并行处理
- ✅ **后台任务**：日志记录不阻塞主流程
- ✅ **统计监控**：请求计数、成功率统计

### 快速运行

```bash
cd examples/api-gateway
moon test --target native
```

### 功能清单

| 功能 | 实现方式 | Async 模式 |
|------|---------|-----------|
| **路由转发** | 根据路径分发到不同后端 | TaskGroup |
| **并发限流** | 最大并发请求数控制 | Semaphore |
| **超时保护** | 统一请求超时 | with_timeout_opt |
| **重试机制** | 瞬态失败自动重试 | infra 层封装 |
| **日志记录** | 后台异步日志 | spawn_bg |
| **批量处理** | 并行处理多个请求 | TaskGroup + spawn |
| **健康检查** | 成功率统计 | 状态管理 |

### 关键代码

```moonbit
// 请求处理流程（综合模式）
pub async fn Gateway::handle_request(
  self : Gateway,
  request : Request
) -> Response raise {
  self.total_requests = self.total_requests + 1
  
  // ✅ 模式 1：限流（Semaphore）
  self.limiter.acquire()
  
  // ✅ 模式 2：结构化并发（TaskGroup）
  @async.with_task_group(fn(group) {
    // 主任务：处理请求
    let response_task = group.spawn(fn() {
      self.handle_request_internal(request)
    })
    
    // ✅ 模式 3：后台任务（spawn_bg）
    group.spawn_bg(fn() {
      self.log_request(request)  // 日志不阻塞主流程
    })
    
    // 等待主任务 + 释放资源
    let response = response_task.wait()
    self.limiter.release()
    response
  })
}
```

**这是本仓库最复杂的示例，展示了生产级 Async 代码的完整形态！** 🎉

---

## 📚 学习建议

1. **按顺序学习**：从 checkout → task_group → retry_timeout → ... → api-gateway
2. **运行测试**：每个示例都运行 `moon test --target native` 验证行为
3. **修改代码**：尝试修改参数，观察结果变化
4. **参考文档**：
   - [`docs/best_practices.md`](../docs/best_practices.md) - 完整最佳实践
   - [`docs/quick-reference.md`](../docs/quick-reference.md) - API 速查表
   - [`docs/faq.md`](../docs/faq.md) - 常见问题

---

## 🔗 相关文档

- [主 README](../README.md) - 项目概览
- [最佳实践](../docs/best_practices.md) - 完整指南
- [快速参考](../docs/quick-reference.md) - API 速查
- [FAQ](../docs/faq.md) - 常见问题

