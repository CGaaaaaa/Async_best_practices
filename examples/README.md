# examples/ — 业务示例

## 示例索引

| 示例 | 核心知识点 | 代码行数 | 测试数 |
|------|-----------|---------|-------|
| [checkout](#checkout) | 业务与 infra 分层 | ~20 | 1 |
| [task_group](#task_group) | TaskGroup、fail-fast | ~40 | 1 |
| [retry_timeout](#retry_timeout) | 统一超时/重试策略 | ~50 | 3 |
| [semaphore_limiter](#semaphore_limiter) | 并发限流、资源保护 | ~30 | 1 |
| [pipeline_queue](#pipeline_queue) | 队列、并行消费 | ~40 | 1 |
| [api-gateway](#api-gateway) | 生产级综合应用 | ~250 | 9 |

## checkout

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

## task_group

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

## retry_timeout

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

## semaphore_limiter

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

## pipeline_queue

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

## api-gateway

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

## 相关文档

- [主 README](../README.mbt.md) - 项目概览
