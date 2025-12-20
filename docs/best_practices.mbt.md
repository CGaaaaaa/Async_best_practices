# MoonBit Async 最佳实践指南

本文以可运行的示例为主线，系统总结 `moonbitlang/async` 在业务研发中的高频模式与建议。所有示例均在 `src/Async_best_practices.mbt` 中可运行、可测试，对应测试位于 `src/Async_best_practices_test.mbt`。

## 📖 关于本文档

本文档是 MoonBit Async 库的**系统化最佳实践指南**，旨在帮助开发者：

- **理解核心概念**：结构化并发、任务组、取消传播等
- **掌握常用模式**：超时控制、重试策略、并发限流等
- **避免常见陷阱**：任务泄漏、取消传播错误、资源竞争等
- **应用到实际项目**：通过业务综合场景学习如何组合使用

### 如何使用本文档

1. **初学者**：按顺序阅读，从基础概念开始
2. **有经验者**：直接跳转到需要的章节
3. **AI 代码助手**：参考本文档理解 Async 库的使用模式

### 文档结构

- **基础概念**：结构化并发、任务组、取消传播
- **核心功能**：超时控制、重试策略、错误处理
- **高级特性**：信号量、队列、任务句柄
- **业务应用**：综合场景示例

## 目录

1. [结构化并发与任务组](#结构化并发与任务组)
2. [超时与取消](#超时与取消)
3. [关键区防取消](#关键区防取消)
4. [重试策略与致命错误](#重试策略与致命错误)
5. [队列与流水线](#队列与流水线)
6. [并发限流（信号量）](#并发限流信号量)
7. [任务句柄与等待](#任务句柄与等待)
8. [持续服务循环与自动重试](#持续服务循环与自动重试)
9. [组级清理（defer/FILO）](#组级清理deferfilo)
10. [业务综合场景模板](#业务综合场景模板)
11. [落地建议清单](#落地建议清单)

---

## 结构化并发与任务组

### 核心概念

**结构化并发**（Structured Concurrency）是 Async 库的核心设计理念。所有异步任务都在一个明确的作用域（TaskGroup）内执行，任务的生命周期由作用域管理，确保：

- ✅ **自动清理**：作用域退出时，所有子任务自动等待或取消
- ✅ **取消传播**：父任务取消时，所有子任务也会被取消
- ✅ **无任务泄漏**：不会出现"孤儿任务"继续运行

### 基本用法

```moonbit
@async.with_task_group(fn(root) {
  // 所有异步任务都在这个作用域内
  let task1 = root.spawn(fn() {
    // 返回值的任务
    @async.sleep(100)
    42
  })
  
  root.spawn_bg(fn() {
    // 后台任务，不返回值
    @async.sleep(200)
  })
  
  // 等待任务完成
  let result = task1.wait()
})
```

### 关键 API

- **`@async.with_task_group(fn)`**：创建任务组作用域
- **`root.spawn(fn)`**：创建返回值的任务，返回 `Task[T]`
- **`root.spawn_bg(fn)`**：创建后台任务，不返回值
- **`Task::wait()`**：等待任务完成并获取结果
- **`Task::try_wait()`**：非阻塞尝试获取结果

### 最佳实践

1. **始终使用 `with_task_group`**：不要创建"野生"任务
2. **区分 `spawn` 和 `spawn_bg`**：
   - `spawn`：需要返回值时使用
   - `spawn_bg`：即发即弃的后台任务
3. **理解取消传播**：`spawn_bg` 的任务也会被取消传播控制

### 相关示例

- **示例 9**：`demo_spawn` - 结构化并发基础
- **示例 19**：`demo_task_wait_and_try_wait` - 任务句柄使用

## 超时与取消

### 核心概念

**超时控制**是异步编程中最重要的防御性编程手段。所有外部依赖（网络请求、数据库查询、第三方服务）都应该设置超时，避免：

- ❌ **无限等待**：服务挂起导致资源泄漏
- ❌ **级联故障**：一个慢服务拖垮整个系统
- ❌ **用户体验差**：用户等待时间过长

### 两种超时 API

#### 1. `with_timeout` - 抛出异常

```moonbit
try {
  @async.with_timeout(1000, fn() {
    // 可能长时间运行的操作
    @async.sleep(2000)
    "done"
  })
} catch {
  @async.TimeoutError => "操作超时"
  err => "其他错误: \{err}"
}
```

**适用场景**：需要区分超时和其他错误时使用

#### 2. `with_timeout_opt` - 返回 Option

```moonbit
let result = @async.with_timeout_opt(1000, fn() {
  @async.sleep(2000)
  "done"
})

match result {
  Some(value) => "成功: \{value}"
  None => "超时"
}
```

**适用场景**：超时是正常流程的一部分，不需要异常处理

### 取消传播

当超时发生时，Async 库会：

1. **取消当前任务**：抛出 `TimeoutError` 或返回 `None`
2. **传播取消**：所有子任务也会被取消
3. **清理资源**：defer 块会正常执行

### 最佳实践

1. **对外部依赖必设超时**：
   ```moonbit
   // ✅ 正确：设置超时
   @async.with_timeout(5000, fn() {
     call_external_api()
   })
   
   // ❌ 错误：没有超时保护
   call_external_api()
   ```

2. **超时时间要合理**：
   - 网络请求：1-5 秒
   - 数据库查询：500ms-2 秒
   - 文件操作：根据文件大小调整

3. **记录可行动的上下文**：
   ```moonbit
   try {
     @async.with_timeout(1000, fn() {
       call_api()
     })
   } catch {
    @async.TimeoutError => {
      log.error("API 调用超时: endpoint=\{endpoint}, timeout=1000ms")
      raise TimeoutError
    }
  }
   ```

### 相关示例

- **示例 3**：`timeout_example` - 基础超时处理
- **示例 10**：`demo_with_timeout` - 超时与取消传播
- **示例 14**：`demo_with_timeout_opt` - 可选超时

## 关键区防取消

### 核心概念

**关键区防取消**（`protect_from_cancel`）允许在任务被取消时，保护某些关键代码段必须执行完成。这对于保证数据一致性和资源清理至关重要。

### 适用场景

- ✅ **数据库事务提交/回滚**：必须完成，不能中途取消
- ✅ **资源释放**：文件句柄、网络连接等必须关闭
- ✅ **指标上报**：关键指标必须记录，即使任务被取消
- ✅ **状态同步**：关键状态变更必须完成

### 基本用法

```moonbit
@async.protect_from_cancel(fn() {
  // 这段代码即使在外层超时后也会执行
  commit_transaction()
  release_resources()
}) catch {
  err => {
    // 如果关键区本身失败，仍然会抛出异常
    log.error("关键操作失败: \{err}")
    raise err
  }
}
```

### 注意事项

⚠️ **谨慎使用**：`protect_from_cancel` 会打破外层超时抽象，可能导致：

- 任务实际执行时间超过预期
- 资源占用时间延长
- 取消传播失效

### 最佳实践

1. **关键区要短小**：
   ```moonbit
   // ✅ 正确：关键区只包含必要的原子操作
   @async.protect_from_cancel(fn() {
     db.commit()
   })
   
   // ❌ 错误：关键区包含大量逻辑
   @async.protect_from_cancel(fn() {
     process_data()  // 不应该在这里
     db.commit()
   })
   ```

2. **明确注释理由**：
   ```moonbit
   // 必须完成事务提交，即使超时也要保证数据一致性
   @async.protect_from_cancel(fn() {
     db.commit()
   })
   ```

3. **关键区后的代码仍可被取消**：
   ```moonbit
   @async.protect_from_cancel(fn() {
     db.commit()  // 这部分不会被取消
   })
   // 这部分仍然可以被取消
   send_notification()
   ```

### 相关示例

- **示例 12**：`demo_protect_from_cancel` - 关键区防取消

## 重试策略与致命错误

### 核心概念

**重试策略**是处理瞬态失败（transient failures）的重要手段。合理的重试策略可以：

- ✅ **提高成功率**：自动处理网络抖动、临时过载等
- ✅ **避免雪崩**：通过退避策略避免对服务造成压力
- ✅ **区分错误类型**：瞬态错误重试，致命错误立即失败

### 重试策略类型

#### 1. Immediate - 立即重试

```moonbit
@async.retry(Immediate, fn() {
  // 操作代码
})
```

**适用场景**：
- 内存操作、本地状态检查
- 重试成本极低的操作
- ⚠️ **不要用于外部服务**（可能导致雪崩）

#### 2. FixedDelay - 固定延迟

```moonbit
@async.retry(FixedDelay(200), fn() {
  // 操作代码
})
```

**适用场景**：
- 稳定但轻负载的场景
- 需要可预测的重试间隔
- 简单的瞬态失败处理

#### 3. ExponentialDelay - 指数退避

```moonbit
@async.retry(
  ExponentialDelay(initial=100, factor=2, maximum=1000),
  fn() {
    // 操作代码
  }
)
```

**适用场景**：
- **推荐默认使用**：大多数外部服务调用
- 网络请求、数据库重连
- 需要避免对服务造成压力的场景

**参数说明**：
- `initial`：初始延迟（毫秒）
- `factor`：每次失败后延迟倍数
- `maximum`：最大延迟上限

**延迟序列示例**：
- 第 1 次失败后：等待 100ms
- 第 2 次失败后：等待 200ms
- 第 3 次失败后：等待 400ms
- 第 4 次失败后：等待 800ms
- 第 5 次失败后：等待 1000ms（达到上限）

### 致命错误处理

使用 `fatal_error` 谓词区分瞬态错误和致命错误：

```moonbit
fn is_fatal(err) {
  // TimeoutError 是瞬态的，应该重试
  not(err is @async.TimeoutError)
}

@async.retry(
  ExponentialDelay(initial=100, factor=2, maximum=1000),
  fatal_error~is_fatal,
  fn() {
    // 操作代码
  }
)
```

**最佳实践**：
- `TimeoutError`：通常是瞬态的，应该重试
- 业务逻辑错误：通常是致命的，不应该重试
- 认证错误：通常是致命的，不应该重试

### 最佳实践

1. **默认使用指数退避**：
   ```moonbit
   // ✅ 推荐：指数退避
   @async.retry(
     ExponentialDelay(initial=100, factor=2, maximum=1000),
     fn() {
       call_api()
     }
   )
   ```

2. **设置合理的重试上限**：
   ```moonbit
   // 通过外层超时控制总重试时间
   @async.with_timeout(5000, fn() {
     @async.retry(ExponentialDelay(...), fn() {
       call_api()
     })
   })
   ```

3. **区分错误类型**：
   ```moonbit
   fn should_retry(err) {
     match err {
       @async.TimeoutError => true  // 重试
       Failure("transient") => true  // 重试
       _ => false  // 不重试
     }
   }
   ```

### 相关示例

- **示例 6**：`retry_example` - 手动重试实现
- **示例 13**：`demo_retry_fixed` - 固定延迟重试
- **示例 16**：`demo_retry_exponential` - 指数退避重试
- **示例 22**：`demo_retry_immediate` - 立即重试
- **示例 23**：`demo_retry_fatal_error` - 致命错误处理

## 队列与流水线

### 核心概念

**队列**（Queue）是异步编程中解耦生产者和消费者的重要工具。Async 库提供了 `@aqueue.Queue`，支持：

- ✅ **非阻塞写入**：`put()` 永远不会阻塞
- ✅ **阻塞读取**：`get()` 会阻塞直到有数据，但可以被取消
- ✅ **FIFO 语义**：先入先出，保证顺序
- ✅ **MPMC 支持**：天然支持多生产者多消费者

### 基本用法

#### 单生产者单消费者

```moonbit
let queue = @aqueue.Queue::new()

// 生产者
root.spawn_bg(fn() {
  for i in 0..<10 {
    queue.put(i)
    @async.sleep(100)
  }
})

// 消费者
root.spawn_bg(fn() {
  for _ in 0..<10 {
    let value = queue.get()  // 阻塞直到有数据
    process(value)
  }
})
```

#### 多生产者多消费者

```moonbit
let queue = @aqueue.Queue::new()

// 多个生产者
for i in 0..<3 {
  root.spawn_bg(fn() {
    for j in 0..<10 {
      queue.put(i * 10 + j)
    }
  })
}

// 多个消费者
for _ in 0..<3 {
  root.spawn_bg(fn() {
    for _ in 0..<10 {
      let value = queue.get()
      process(value)
    }
  })
}
```

### 非阻塞读取

使用 `try_get()` 实现非阻塞读取：

```moonbit
loop {
  match queue.try_get() {
    Some(value) => {
      process(value)
      break
    }
    None => {
      // 队列为空，让出 CPU 避免忙等待
      @async.pause()
      continue
    }
  }
}
```

### 最佳实践

1. **写端永不阻塞**：`put()` 总是立即返回
2. **读端选择合适方式**：
   - `get()`：需要等待数据时使用
   - `try_get()`：需要轮询或降级处理时使用
3. **避免忙等待**：使用 `@async.pause()` 让出 CPU
4. **队列操作可被取消**：`get()` 可以被任务取消中断

### 应用场景

- **工作队列**：任务分发和处理
- **数据流水线**：生产者-消费者模式
- **缓冲队列**：平滑处理速度差异
- **事件队列**：解耦事件产生和处理

### 相关示例

- **示例 15**：`demo_queue_pipeline` - 单生产者单消费者
- **示例 18**：`demo_queue_mpmc` - 多生产者多消费者
- **示例 24**：`demo_queue_try_get_nonblocking` - 非阻塞读取

## 并发限流（信号量）

### 核心概念

**信号量**（Semaphore）用于限制同时访问某个资源的任务数量。这是控制并发度的标准工具，比自制计数器更可靠。

### 基本用法

```moonbit
let semaphore = @semaphore.Semaphore::new(2)  // 最多 2 个并发

@async.with_task_group(fn(root) {
  for i in 0..<10 {
    root.spawn_bg(fn() {
      semaphore.acquire()  // 获取资源
      defer semaphore.release()  // 确保释放
      
      // 使用资源
      do_work()
    })
  }
})
```

### 非阻塞获取

使用 `try_acquire()` 实现快速失败/降级：

```moonbit
if semaphore.try_acquire() {
  defer semaphore.release()
  do_work()
} else {
  // 资源被占用，执行降级逻辑
  fallback()
}
```

### 最佳实践

1. **优先使用信号量**：不要自制计数器
   ```moonbit
   // ✅ 正确：使用信号量
   let sem = @semaphore.Semaphore::new(10)
   sem.acquire()
   
   // ❌ 错误：自制计数器（容易出错）
   let mut count = 0
   if count < 10 {
     count = count + 1
     // 容易忘记释放，或者异常时没有释放
   }
   ```

2. **关键区要短小**：
   ```moonbit
   // ✅ 正确：关键区只包含必要的操作
   semaphore.acquire()
   defer semaphore.release()
   use_resource()
   
   // ❌ 错误：关键区包含大量逻辑
   semaphore.acquire()
   process_data()  // 不应该持有信号量
   use_resource()
   semaphore.release()
   ```

3. **使用 defer 确保释放**：
   ```moonbit
   semaphore.acquire()
   defer semaphore.release()  // 即使异常也会释放
   do_work()
   ```

### 应用场景

- **API 限流**：限制对外部 API 的并发请求数
- **数据库连接池**：限制同时打开的连接数
- **文件操作**：限制同时打开的文件数
- **资源保护**：保护共享资源不被过度并发访问

### 相关示例

- **示例 11**：`demo_semaphore` - 信号量基础用法
- **示例 17**：`demo_semaphore_try_acquire` - 非阻塞获取

## 任务句柄与等待

### 核心概念

**任务句柄**（Task Handle）是 `spawn()` 返回的对象，用于管理任务的生命周期和获取结果。

### 基本用法

```moonbit
let task = root.spawn(fn() {
  @async.sleep(100)
  42
})

// 阻塞等待结果
let result = task.wait()  // 返回 42

// 非阻塞尝试获取
match task.try_wait() {
  Some(value) => "已完成: \{value}"
  None => "还在运行中"
}
```

### API 对比

| API | 行为 | 返回值 | 适用场景 |
|-----|------|--------|----------|
| `wait()` | 阻塞直到完成 | `T` | 需要结果时使用 |
| `try_wait()` | 非阻塞检查 | `Option[T]` | 轮询任务状态 |

### 最佳实践

1. **需要结果时使用 `wait()`**：
   ```moonbit
   let task = root.spawn(fn() {
     fetch_data()
   })
   let data = task.wait()  // 等待结果
   ```

2. **轮询状态时使用 `try_wait()`**：
   ```moonbit
   loop {
     match task.try_wait() {
       Some(result) => break result
       None => {
         @async.sleep(100)  // 短暂等待后重试
         continue
       }
     }
   }
   ```

3. **任务完成前 `try_wait()` 返回 `None`**：
   ```moonbit
   let task = root.spawn(fn() {
     @async.sleep(1000)
     42
   })
   
   // 立即检查，返回 None
   assert_eq(task.try_wait(), None)
   
   // 等待后检查，返回 Some(42)
   @async.sleep(1100)
   assert_eq(task.try_wait(), Some(42))
   ```

### 相关示例

- **示例 19**：`demo_task_wait_and_try_wait` - 任务句柄使用

## 持续服务循环与自动重试

### 核心概念

**持续服务循环**（`spawn_loop`）用于实现需要持续运行的服务，如：

- 定时任务
- 消息队列消费者
- 监控服务
- 后台清理任务

`spawn_loop` 自动处理重试逻辑，异常时会根据配置的重试策略自动重试。

### 基本用法

```moonbit
root.spawn_loop(
  retry=ExponentialDelay(initial=100, factor=2, maximum=1000),
  fn() {
    // 执行一次循环
    do_work()
    
    // 控制循环生命周期
    if should_continue() {
      IterContinue  // 继续循环
    } else {
      IterEnd  // 退出循环
    }
  }
)
```

### 循环控制

- **`IterContinue`**：继续下一次循环
- **`IterEnd`**：退出循环
- **异常**：根据重试策略自动重试

### 最佳实践

1. **使用指数退避**：避免热循环
   ```moonbit
   // ✅ 推荐：指数退避
   root.spawn_loop(
     retry=ExponentialDelay(initial=100, factor=2, maximum=1000),
     fn() {
       poll_queue()
       IterContinue
     }
   )
   ```

2. **明确退出条件**：
   ```moonbit
   root.spawn_loop(
     retry=...,
     fn() {
       match process_next_item() {
         Some(_) => IterContinue
         None => IterEnd  // 没有更多项目，退出
       }
     }
   )
   ```

3. **处理致命错误**：
   ```moonbit
   root.spawn_loop(
     retry=...,
     fatal_error~is_fatal,
     fn() {
       // 瞬态错误会重试
       // 致命错误会退出循环
       do_work()
       IterContinue
     }
   )
   ```

### 相关示例

- **示例 20**：`demo_spawn_loop_retry_exponential` - 持续服务循环

## 组级清理（defer/FILO）

### 核心概念

**组级清理**（Group Defer）允许在任务组退出时执行清理逻辑。清理顺序遵循 FILO（First In Last Out）原则，与任务内的 `defer` 协作，确保资源正确释放。

### 清理顺序

1. **任务内 defer**：按 FILO 顺序执行
2. **组级 defer**：按 FILO 顺序执行（后注册的先执行）

### 基本用法

```moonbit
@async.with_task_group(fn(root) {
  // 注册组级清理（后注册的先执行）
  root.add_defer(() => log.write_string("清理 2\n"))
  root.add_defer(() => log.write_string("清理 1\n"))
  
  root.spawn_bg(fn() {
    defer log.write_string("任务 defer\n")
    do_work()
  })
  
  // 退出时执行顺序：
  // 1. 任务 defer
  // 2. 清理 1（后注册）
  // 3. 清理 2（先注册）
})
```

### 最佳实践

1. **使用 defer 确保清理**：
   ```moonbit
   root.add_defer(() => {
     close_connection()
     release_resources()
   })
   ```

2. **理解执行顺序**：
   ```moonbit
   root.add_defer(() => log.write_string("A\n"))  // 第 3 个执行
   root.add_defer(() => log.write_string("B\n"))  // 第 2 个执行
   root.add_defer(() => log.write_string("C\n"))  // 第 1 个执行
   ```

3. **即使任务被取消，defer 也会执行**：
   ```moonbit
   root.spawn_bg(no_wait=true, fn() {
     defer cleanup()  // 即使任务被取消，也会执行
     long_running_task()
   })
   ```

### 相关示例

- **示例 21**：`demo_group_defer` - 组级清理

## 业务综合场景模板

### 核心思路

在实际业务开发中，我们需要**组合使用**多种异步模式：

1. **超时控制**：防止外部依赖无限等待
2. **重试策略**：处理瞬态失败
3. **错误处理**：区分可恢复和不可恢复的错误
4. **结构化并发**：管理任务生命周期

### 示例：下单+支付流程

```moonbit
pub async fn demo_business_checkout_flow() -> String {
  let orders = [101, 102]
  
  for order_id in orders {
    // 组合使用：超时 + 重试
    let outcome = @async.with_timeout_opt(500, fn() {
      @async.retry(
        ExponentialDelay(initial=50, factor=2, maximum=200),
        fn() {
          // 调用支付网关
          call_payment_gateway(order_id)
        }
      )
    })
    
    match outcome {
      Some(_) => log.success("订单 \{order_id} 支付成功")
      None => log.error("订单 \{order_id} 支付超时")
    }
  }
}
```

### 设计模式

#### 1. 基础设施层封装

将超时和重试封装为基础设施函数：

```moonbit
// payment_client.mbt
pub async fn call_payment_with_retry(order_id : Int) -> Result[String, String] {
  @async.with_timeout_opt(5000, fn() {
    @async.retry(
      ExponentialDelay(initial=100, factor=2, maximum=1000),
      fn() {
        call_payment_gateway(order_id)
      }
    )
  })
  match result {
    Some(value) => Ok(value)
    None => Err("支付超时")
  }
}
```

#### 2. 业务层简化

业务层只关心业务逻辑：

```moonbit
// order_service.mbt
pub async fn process_order(order_id : Int) -> Result[Unit, String] {
  match call_payment_with_retry(order_id) {
    Ok(_) => {
      update_order_status(order_id, "paid")
      Ok(())
    }
    Err(err) => {
      update_order_status(order_id, "failed")
      Err(err)
    }
  }
}
```

### 最佳实践

1. **基础设施层统一处理**：
   - 超时控制
   - 重试策略
   - 错误转换

2. **业务层关注业务逻辑**：
   - 订单状态更新
   - 业务规则验证
   - 用户通知

3. **可配置的策略**：
   ```moonbit
   struct PaymentConfig {
     timeout : Int
     retry_strategy : RetryStrategy
   }
   
   fn call_payment(config : PaymentConfig, order_id : Int) {
     @async.with_timeout_opt(config.timeout, fn() {
       @async.retry(config.retry_strategy, fn() {
         call_payment_gateway(order_id)
       })
     })
   }
   ```

### 相关示例

- **示例 25**：`demo_business_checkout_flow` - 业务综合场景

---

## 落地建议清单（Checklist）

### ✅ 必须遵守的原则

1. **对外部交互必设超时**
   - [ ] 所有网络请求设置超时
   - [ ] 所有数据库查询设置超时
   - [ ] 所有文件操作设置超时
   - [ ] 封装为基础设施函数统一使用

2. **重试策略配置**
   - [ ] 默认使用指数退避
   - [ ] 对致命错误设置 `fatal_error` 终止条件
   - [ ] 设置合理的重试上限（通过外层超时）

3. **结构化并发**
   - [ ] 所有异步任务都在 `with_task_group` 内
   - [ ] 避免创建"野生"任务
   - [ ] 使用 `spawn` 或 `spawn_bg` 创建任务

4. **并发控制**
   - [ ] 使用信号量限制并发度
   - [ ] 关键区尽量短小（acquire → work → release）
   - [ ] 使用 `defer` 确保资源释放

5. **错误处理**
   - [ ] 区分瞬态错误和致命错误
   - [ ] 记录可行动的上下文信息
   - [ ] 使用 `allow_failure=true` 处理非关键任务

6. **资源清理**
   - [ ] 使用 `defer` 清理资源
   - [ ] 使用 `add_defer` 注册组级清理
   - [ ] 理解 FILO 执行顺序

### 📋 代码审查清单

在代码审查时，检查以下问题：

- [ ] 是否有未设置超时的外部调用？
- [ ] 是否有未使用结构化并发的异步任务？
- [ ] 是否有未处理的重试场景？
- [ ] 是否有资源泄漏的风险？
- [ ] 是否有并发竞争的问题？
- [ ] 是否有错误处理不完善的地方？

### 🎯 常见陷阱

1. **任务泄漏**
   ```moonbit
   // ❌ 错误：创建了"野生"任务
   @async.spawn(fn() { ... })
   
   // ✅ 正确：在任务组内
   @async.with_task_group(fn(root) {
     root.spawn_bg(fn() { ... })
   })
   ```

2. **忘记设置超时**
   ```moonbit
   // ❌ 错误：没有超时保护
   call_api()
   
   // ✅ 正确：设置超时
   @async.with_timeout(5000, fn() {
     call_api()
   })
   ```

3. **重试所有错误**
   ```moonbit
   // ❌ 错误：重试所有错误
   @async.retry(..., fn() {
     call_api()
   })
   
   // ✅ 正确：区分错误类型
   @async.retry(..., fatal_error~is_fatal, fn() {
     call_api()
   })
   ```

---

## 📚 参考资源

### 项目内资源

- **代码示例**：`src/Async_best_practices.mbt` - 25 个完整示例
- **测试用例**：`src/Async_best_practices_test.mbt` - 所有示例的测试
- **项目文档**：`README.mbt.md` - 项目概览和快速开始

### 外部资源

- **MoonBit 官方文档**：[https://docs.moonbitlang.com](https://docs.moonbitlang.com)
- **Async 库源码**：`.mooncakes/moonbitlang/async/` - 更高级的示例和实现
- **MoonBit 社区**：参与社区讨论，获取帮助

---

## 💡 总结

本文档系统介绍了 MoonBit Async 库的最佳实践，从基础概念到高级模式，从单个功能到业务综合场景。通过遵循这些最佳实践，你可以：

- ✅ 编写更可靠的异步代码
- ✅ 避免常见的陷阱和错误
- ✅ 提高代码的可维护性
- ✅ 构建高性能的异步应用

记住：**实践是最好的老师**。建议你：

1. 阅读示例代码
2. 运行测试查看效果
3. 在自己的项目中应用
4. 遇到问题时查阅本文档

祝你使用愉快！🎉



