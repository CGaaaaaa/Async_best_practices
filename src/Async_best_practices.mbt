///|
/// 示例 1: 简单的异步函数 - 演示基本的超时功能
/// 
/// 展示如何使用 `@async.with_timeout_opt` 对异步操作设置超时。
/// 该函数返回 `Some(value)` 表示成功，`None` 表示超时。
/// 
/// # 最佳实践
/// - 对所有外部交互设置合理的超时时间
/// - 使用 `with_timeout_opt` 简化超时处理逻辑
/// 
/// # 示例
/// ```moonbit no-check
/// let result = hello_async()
/// // result 将是 "Hello, Async!" 因为 50ms < 100ms
/// ```
pub async fn hello_async() -> String {
  let result = @async.with_timeout_opt(100, fn() {
    @async.sleep(50)
    "Hello, Async!"
  })
  match result {
    Some(msg) => msg
    None => "Timeout"
  }
}

///|
/// 示例 2: 并发执行多个异步任务
/// 
/// 演示如何使用 `@async.with_task_group` 和 `spawn` 并发执行多个任务。
/// 所有子任务都在任务组的作用域内，确保结构化并发。
/// 
/// # 最佳实践
/// - 使用 `TaskGroup` 管理并发任务的生命周期
/// - `spawn` 返回 `Task` 句柄，可用 `wait()` 获取结果
/// - 任务组退出时会自动等待所有 spawn 的任务完成
/// 
/// # 示例
/// ```moonbit no-check
/// let results = concurrent_tasks()
/// // results = [1, 2, 3]，按照 wait() 的顺序而非完成顺序
/// ```
pub async fn concurrent_tasks() -> Array[Int] {
  @async.with_task_group(fn(group) {
    let task1 = group.spawn(fn() {
      @async.sleep(10)
      1
    })
    let task2 = group.spawn(fn() {
      @async.sleep(20)
      2
    })
    let task3 = group.spawn(fn() {
      @async.sleep(15)
      3
    })

    // 等待所有任务完成
    [task1.wait(), task2.wait(), task3.wait()]
  })
}

///|
/// 示例 3: 超时处理长时间运行的任务
/// 
/// 演示当任务执行时间超过设定阈值时如何处理。
/// 与示例 1 不同，这里任务会超时（100ms > 50ms）。
/// 
/// # 最佳实践
/// - 为可能延迟的操作设置明确的超时上限
/// - 提供有意义的超时错误消息，便于排障
/// 
/// # 示例
/// ```moonbit no-check
/// let result = timeout_example()
/// // result = "Task timed out after 50ms"
/// ```
pub async fn timeout_example() -> String {
  let result = @async.with_timeout_opt(50, fn() {
    @async.sleep(100) // 这个会超时
    "Completed"
  })
  match result {
    Some(msg) => msg
    None => "Task timed out after 50ms"
  }
}

///|
/// 示例 4: 顺序执行异步操作（数据处理流水线）
/// 
/// 演示如何将多个异步操作串联成流水线。每个步骤的输出
/// 作为下一个步骤的输入，保持数据流的顺序性。
/// 
/// # 最佳实践
/// - 将复杂的异步流程分解为清晰的步骤
/// - 每个步骤独立封装，便于测试和复用
/// - 适用于 ETL、数据转换等场景
/// 
/// # 示例
/// ```moonbit no-check
/// let result = sequential_pipeline()
/// // 流程：fetch(42) -> process(42*2=84) -> save(84)
/// // result = 84
/// ```
pub async fn sequential_pipeline() -> Int {
  // 步骤 1: 获取数据
  let data = fetch_data()

  // 步骤 2: 处理数据
  let processed = process_data(data)

  // 步骤 3: 保存结果
  save_result(processed)
  processed
}

///|
async fn fetch_data() -> Int {
  @async.sleep(10)
  42
}

///|
async fn process_data(data : Int) -> Int {
  @async.sleep(10)
  data * 2
}

///|
async fn save_result(_data : Int) -> Unit {
  @async.sleep(10)
  // 模拟保存操作
}

///|
/// 示例 5: 竞速模式 - 返回最快完成的任务
/// 
/// 演示 "race" 模式：多个任务并发执行，第一个完成的任务
/// 通过 `return_immediately` 立即返回结果并取消其他任务。
/// 
/// # 最佳实践
/// - 适用于多个数据源查询、冗余请求等场景
/// - `return_immediately` 会触发任务组的提前退出
/// - 其他未完成的任务会被自动取消
/// 
/// # 示例
/// ```moonbit no-check
/// let result = race_example()
/// // Task 2 最快完成（10ms），result = "Task 2 finished"
/// ```
pub async fn race_example() -> String {
  @async.with_task_group(fn(group) {
    group.spawn_bg(fn() {
      @async.sleep(30)
      group.return_immediately("Task 1 finished")
    })
    group.spawn_bg(fn() {
      @async.sleep(10)
      group.return_immediately("Task 2 finished") // 这个会先完成
    })
    group.spawn_bg(fn() {
      @async.sleep(20)
      group.return_immediately("Task 3 finished")
    })

    // 等待第一个完成的任务
    @async.sleep(100) // 不会真正等到这里，因为第一个任务会提前返回
    "All tasks completed"
  })
}

///|
/// 示例 6: 重试机制 - 手动实现指数退避
/// 
/// 演示如何手动实现带重试的异步操作。这个示例使用简单的
/// 循环和指数退避策略，第 2 次尝试会成功。
/// 
/// # 最佳实践
/// - 对瞬态失败（网络抖动、临时过载）使用重试
/// - 实现指数退避避免雪崩效应
/// - 设置最大重试次数防止无限循环
/// - 更推荐使用 `@async.retry` API（见 examples/core）
/// 
/// # 示例
/// ```moonbit no-check
/// let result = retry_example()
/// // 第1次失败，等待10ms，第2次成功
/// // result = Ok("Success on attempt 2")
/// ```
pub async fn retry_example() -> Result[String, String] {
  let max_retries = 3
  let mut attempts = 0
  while attempts < max_retries {
    attempts = attempts + 1
    let result = attempt_operation(attempts)
    match result {
      Ok(value) => return Ok(value)
      Err(_) =>
        if attempts < max_retries {
          @async.sleep(10 * attempts) // 指数退避
          continue
        }
    }
  }
  Err("Failed after \{max_retries} attempts")
}

///|
async fn attempt_operation(attempt : Int) -> Result[String, String] {
  @async.sleep(5)
  if attempt >= 2 {
    Ok("Success on attempt \{attempt}")
  } else {
    Err("Failed attempt \{attempt}")
  }
}

///|
// 自定义错误类型用于演示
pub suberror CustomTaskError derive(Show)

///|
/// 示例 7: 错误隔离 - 允许部分任务失败
/// 
/// 演示如何使用 `allow_failure=true` 让某些任务的失败
/// 不影响整个任务组。这对于可选的后台任务很有用。
/// 
/// # 最佳实践
/// - 对非关键路径任务使用 `allow_failure=true`
/// - 关键任务失败应该让整个组失败（结构化并发）
/// - 适用于日志记录、指标上报等辅助任务
/// 
/// # 示例
/// ```moonbit no-check
/// let result = error_handling_example()
/// // 后台任务抛出 CustomTaskError 但被隔离
/// // result = "Main task completed successfully"
/// ```
pub async fn error_handling_example() -> String {
  @async.with_task_group(fn(group) {
    // 这个任务允许失败，不会影响整个组
    group.spawn_bg(allow_failure=true, fn() {
      @async.sleep(10)
      raise CustomTaskError
    })

    // 这个任务正常完成
    let task = group.spawn(fn() {
      @async.sleep(20)
      "Main task completed successfully"
    })
    task.wait()
  })
}

///|
/// 示例 8: 批量处理 - 并发处理集合元素
/// 
/// 演示如何批量创建异步任务并收集所有结果。这是 map-reduce
/// 模式的异步版本，适用于批量 IO 操作。
/// 
/// # 最佳实践
/// - 使用数组收集 Task 句柄，统一等待
/// - 结果顺序与任务创建顺序一致（非完成顺序）
/// - 考虑使用信号量限制并发度，避免资源耗尽
/// - 大批量处理建议分批次执行
/// 
/// # 示例
/// ```moonbit no-check
/// let results = batch_processing()
/// // 并发计算 [1,2,3,4,5] 的平方
/// // results = [1, 4, 9, 16, 25]
/// ```
pub async fn batch_processing() -> Array[Int] {
  @async.with_task_group(fn(group) {
    let items = [1, 2, 3, 4, 5]
    let tasks = []

    // 为每个项目创建异步任务
    for item in items {
      let task = group.spawn(fn() {
        @async.sleep(item * 5)
        item * item
      })
      tasks.push(task)
    }

    // 收集所有结果
    let final_results = []
    for task in tasks {
      final_results.push(task.wait())
    }
    final_results
  })
}

///|
/// 示例 9: 结构化并发 - 任务组管理
/// 
/// 演示使用 `@async.with_task_group` 和 `spawn_bg` 管理任务作用域。
/// 即使是"即发即弃"的后台任务，也会受到取消传播的约束。
/// 
/// # 最佳实践
/// - 所有异步任务都在 TaskGroup 的作用域内
/// - 任务组退出时会自动等待所有 spawn_bg 的任务
/// - 取消会传播到所有子任务
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_spawn()
/// // 两个任务交替执行，每个任务 3 个 tick
/// ```
pub async fn demo_spawn() -> String {
  let buf = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.spawn_bg(fn() {
      @async.sleep(100)
      buf.write_string("task 1, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 3\n")
    })
    root.spawn_bg(fn() {
      @async.sleep(200)
      buf.write_string("task 2, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 3\n")
    })
  })
  buf.to_string()
}

///|
/// 示例 10: 超时与取消传播
/// 
/// 演示 `@async.with_timeout` 的超时机制和取消传播。
/// 当超时发生时，所有子任务都会被取消。
/// 
/// # 最佳实践
/// - 使用 `with_timeout` 设置异步操作的上限
/// - 捕获 `TimeoutError` 提供有意义的错误信息
/// - 记录取消事件便于排障
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_with_timeout()
/// // 400ms 任务被 200ms 超时取消
/// // 输出显示取消传播链
/// ```
pub async fn demo_with_timeout() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        @async.sleep(300)
        log.write_string("300ms tick\n")
      })
      @async.with_timeout(200, fn() {
        @async.sleep(400) catch {
          _ => log.write_string("task cancelled\n")
        }
      }) catch {
        _ => log.write_string("`with_timeout` fail with TimeoutError\n")
      }
      log.write_string("main task finished\n")
    }),
  )
  log.to_string()
}

///|
/// 示例 11: 信号量限流
/// 
/// 演示使用 `@semaphore.Semaphore` 限制并发度。
/// 信号量确保同时只有指定数量的任务可以访问资源。
/// 
/// # 最佳实践
/// - 优先使用信号量而非自制计数器
/// - 关键区应短小：acquire → work → release
/// - 避免在持有信号量时执行长时间操作
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_semaphore()
/// // 6 个任务竞争 2 个资源槽位
/// // 每批次 2 个任务同时执行
/// ```
pub async fn demo_semaphore() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let semaphore = @semaphore.Semaphore::new(2)
    for i in 0..<6 {
      root.spawn_bg(fn() {
        semaphore.acquire()
        log.write_string("task \{i} obtained resource\n")
        @async.sleep(200)
        semaphore.release()
      })
    }
    @async.sleep(100)
    for _ in 0..<3 {
      log.write_string("tick\n")
      @async.sleep(200)
    }
  })
  log.to_string()
}

///|
/// 示例 12: 关键区防取消
/// 
/// 演示使用 `@async.protect_from_cancel` 保护关键代码段不被取消。
/// 适用于提交/回滚、持久化指标、资源交接等原子操作。
/// 
/// # 最佳实践
/// - 仅在必要时使用，因为会打破外层超时抽象
/// - 关键区应尽可能短小
/// - 关键区之后的代码仍可被取消
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_protect_from_cancel()
/// // 关键任务在超时发生后仍能完成
/// // 非关键部分被取消
/// ```
pub async fn demo_protect_from_cancel() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.spawn_bg(fn() {
      @async.protect_from_cancel(fn() {
        @async.sleep(300) catch {
          err => {
            log.write_string("critical job cancelled with error \{err}\n")
            raise err
          }
        }
        log.write_string("critical job finished\n")
      }) catch {
        _ => log.write_string("job cancelled after critical part\n")
      }
      @async.sleep(150)
      log.write_string("non-critical part finished\n")
    })
    // Cause timeout after 200ms to cancel the group
    @async.with_timeout(200, fn() { @async.sleep(1000) })
  }) catch {
    err => log.write_object(err)
  }
  log.to_string()
}

///|
/// 示例 13: 固定延迟重试
/// 
/// 演示使用 `@async.retry(FixedDelay(...), fn)` 实现固定间隔的重试策略。
/// 适用于瞬态失败场景，如网络抖动、临时过载。
/// 
/// # 最佳实践
/// - 对瞬态失败使用重试，对永久性错误不要重试
/// - 设置合理的重试延迟避免热循环
/// - 可视化 backoff 时间线便于调试
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_retry_fixed()
/// // 前两次失败，每次等待 200ms 后重试
/// // 第三次成功
/// ```
pub async fn demo_retry_fixed() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    // timeline logger to visualize delays
    root.spawn_bg(fn() {
      for i in 0..<3 {
        @async.sleep(200)
        log.write_string("tick \{i}\n")
      }
    })
    @async.sleep(100)
    let mut i = 0
    @async.retry(FixedDelay(200), fn() {
      log.write_string("loop \{i}\n")
      i = i + 1
      if i < 3 {
        raise Failure("transient")
      }
    })
  })
  log.to_string()
}

///|
/// 示例 14: 可选超时
/// 
/// 演示 `@async.with_timeout_opt` 返回 `Option` 类型，
/// 便于直接使用 `match` 分支处理超时情况。
/// 
/// # 最佳实践
/// - 使用 `with_timeout_opt` 简化超时处理逻辑
/// - `Some(value)` 表示成功，`None` 表示超时
/// - 避免使用异常处理超时的常规流程
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_with_timeout_opt()
/// // 300ms 任务在 200ms 超时后返回 None
/// ```
pub async fn demo_with_timeout_opt() -> String {
  let log = StringBuilder::new()
  let out = @async.with_timeout_opt(200, fn() {
    @async.sleep(300)
    "done"
  })
  match out {
    Some(v) => log.write_string("value=\{v}\n")
    None => log.write_string("timeout -> None\n")
  }
  log.to_string()
}

///|
/// 示例 15: 队列流水线
/// 
/// 演示使用 `@aqueue.Queue` 构建生产者-消费者流水线。
/// 队列支持非阻塞写、阻塞读，先到先服务。
/// 
/// # 最佳实践
/// - 使用队列解耦生产者和消费者
/// - `put()` 非阻塞，`get()` 阻塞直到有数据
/// - 队列操作可被取消
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_queue_pipeline()
/// // 生产者每 100ms 生产一个值
/// // 消费者立即消费
/// ```
pub async fn demo_queue_pipeline() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer
    root.spawn_bg(fn() {
      for i in 0..<3 {
        q.put(i)
        log.write_string("produced \{i}\n")
        @async.sleep(100)
      }
    })
    // consumer
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    @async.sleep(500)
  })
  log.to_string()
}

///|
/// 示例 16: 指数退避重试
/// 
/// 演示使用 `@async.retry(ExponentialDelay(...), fn)` 实现指数退避策略。
/// 初始延迟为 200ms，每次失败后延迟翻倍，最大延迟 600ms。
/// 
/// # 最佳实践
/// - 指数退避避免雪崩效应
/// - 设置 maximum 防止延迟过长
/// - 适用于外部服务调用、数据库重连等场景
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_retry_exponential()
/// // 延迟序列：200ms, 400ms, 600ms（达到上限）
/// // 第 4 次成功
/// ```
pub async fn demo_retry_exponential() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        for i in 0..<7 {
          @async.sleep(200)
          log.write_string("tick \{i}\n")
        }
      })
      @async.sleep(100)
      let mut i = 0
      @async.retry(ExponentialDelay(initial=200, factor=2, maximum=600), fn() {
        log.write_string("loop \{i}\n")
        i = i + 1
        if i < 4 {
          raise Failure("transient")
        }
      })
      log.write_string("retry completed\n")
    }),
  )
  log.to_string()
}

///|
/// 示例 17: 信号量非阻塞获取
/// 
/// 演示使用 `Semaphore.try_acquire()` 实现非阻塞的资源获取。
/// 适合"快速失败/降级"场景，避免等待。
/// 
/// # 最佳实践
/// - `try_acquire()` 返回 `true` 表示获取成功，`false` 表示失败
/// - 与阻塞式 `acquire()` 搭配，构建灵活的限流策略
/// - 适用于可选功能、降级服务等场景
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_semaphore_try_acquire()
/// // 资源被占用时返回 false
/// // 资源释放后返回 true
/// ```
pub async fn demo_semaphore_try_acquire() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let semaphore = @semaphore.Semaphore::new(1)
    // occupy once so try_acquire initially fails
    root.spawn_bg(fn() {
      semaphore.acquire()
      log.write_string("occupied\n")
      @async.sleep(300)
      semaphore.release()
      log.write_string("released\n")
    })
    @async.sleep(100)
    log.write_object(semaphore.try_acquire())
    log.write_string("\n")
    @async.sleep(300)
    log.write_object(semaphore.try_acquire())
    log.write_string("\n")
  })
  log.to_string()
}

///|
/// 示例 18: 多生产者/多消费者队列
/// 
/// 演示 2 个生产者和 2 个消费者共享同一队列。
/// 队列保证 FIFO 语义，消费者按到达顺序获取数据。
/// 
/// # 最佳实践
/// - 队列天然支持 MPMC（多生产者多消费者）
/// - FIFO 保证值的顺序，但不保证特定消费者获取特定值
/// - 适用于工作队列、任务分发等场景
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_queue_mpmc()
/// // 2 个生产者交替生产 0-5
/// // 2 个消费者竞争消费
/// ```
pub async fn demo_queue_mpmc() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer 0 produces 0,2,4
    root.spawn_bg(fn() {
      for i in 0..<3 {
        let v = i * 2
        q.put(v)
        log.write_string("produced \{v}\n")
        @async.sleep(100)
      }
    })
    // producer 1 produces 1,3,5, staggered to interleave
    root.spawn_bg(fn() {
      @async.sleep(50)
      for i in 0..<3 {
        let v = i * 2 + 1
        q.put(v)
        log.write_string("produced \{v}\n")
        @async.sleep(100)
      }
    })
    // two consumers; we only assert FIFO of values, not consumer id
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    @async.sleep(800)
  })
  log.to_string()
}

///|
/// 示例 19: 任务句柄与等待
/// 
/// 演示 `Task::try_wait()` 和 `Task::wait()` 的区别。
/// `try_wait()` 非阻塞返回 `Option`，`wait()` 阻塞直到完成。
/// 
/// # 最佳实践
/// - `try_wait()` 用于轮询任务状态
/// - `wait()` 用于同步等待任务结果
/// - 任务完成前 `try_wait()` 返回 `None`
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_task_wait_and_try_wait()
/// // 任务启动后立即 try_wait 返回 None
/// // 200ms 后 wait 返回 42
/// ```
pub async fn demo_task_wait_and_try_wait() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let task = root.spawn(fn() {
      @async.sleep(200)
      42
    })
    log.write_object(task.try_wait())
    log.write_string("\n")
    let v = task.wait()
    log.write_string("value=\{v}\n")
  })
  log.to_string()
}

///|
/// 示例 20: 持续服务循环
/// 
/// 演示 `root.spawn_loop(retry=..., fn)` 实现持续运行的服务。
/// 循环体返回 `IterResult`：`IterContinue` 继续，`IterEnd` 退出。
/// 
/// # 最佳实践
/// - `spawn_loop` 自动处理重试逻辑
/// - 使用 `IterEnd` 优雅退出循环
/// - 异常会触发重试，可配置退避策略
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_spawn_loop_retry_exponential()
/// // 前 3 次失败触发重试
/// // 第 4 次成功，返回 IterContinue
/// // 之后继续循环直到 IterEnd
/// ```
pub async fn demo_spawn_loop_retry_exponential() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        for i in 0..<9 {
          @async.sleep(200)
          log.write_string("tick \{i}\n")
        }
      })
      @async.sleep(100)
      let mut i = 0
      root.spawn_loop(
        retry=ExponentialDelay(initial=200, factor=2, maximum=600),
        fn() {
          log.write_string("loop \{i}\n")
          i = i + 1
          match i {
            1 | 2 | 3 => raise Failure("transient")
            4 => IterContinue
            5 | 6 => raise Failure("transient")
            _ => IterEnd
          }
        },
      )
    }),
  )
  log.to_string()
}

///|
/// 示例 21: 组级清理
/// 
/// 演示 `TaskGroup::add_defer(async () -> Unit)` 提供结构化清理。
/// defer 按 FILO 顺序执行，与任务取消协作。
/// 
/// # 最佳实践
/// - 使用 `add_defer` 注册组级清理逻辑
/// - 清理顺序：任务内 defer → 组级 defer（FILO）
/// - 即使任务被取消，defer 也会执行
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_group_defer()
/// // 第一个任务完成后执行 defer
/// // 第二个任务被取消（no_wait=true）但 defer 仍执行
/// // 组级 defer 按 FILO 顺序执行
/// ```
pub async fn demo_group_defer() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.add_defer(() => log.write_string("first group defer\n"))
    root.spawn_bg(fn() {
      defer log.write_string("defer for first task\n")
      @async.sleep(100)
    })
    root.spawn_bg(no_wait=true, fn() {
      defer log.write_string("defer for cancelled task\n")
      @async.sleep(1000)
    })
    root.add_defer(() => log.write_string("second group defer\n"))
  })
  log.to_string()
}

///|
/// 示例 22: 立即重试
/// 
/// 演示使用 `@async.retry(Immediate, fn)` 实现无延迟的立即重试。
/// 适用于快速失败场景，如内存操作、本地状态检查。
/// 
/// # 最佳实践
/// - 仅在重试成本极低时使用 `Immediate`
/// - 避免对外部服务使用立即重试（可能导致雪崩）
/// - 适用于乐观锁重试、快速状态检查等
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_retry_immediate()
/// // 前两次失败，立即重试
/// // 第三次成功
/// ```
pub async fn demo_retry_immediate() -> String {
  let log = StringBuilder::new()
  let mut i = 0
  @async.retry(Immediate, fn() {
    log.write_string("tick \{i}\n")
    i = i + 1
    if i < 3 {
      raise Failure("transient")
    }
  })
  log.to_string()
}

///|
/// 示例 23: 重试致命错误
/// 
/// 演示使用 `fatal_error` 谓词区分瞬态错误和致命错误。
/// 瞬态错误会重试，致命错误立即失败。
/// 
/// # 最佳实践
/// - 使用 `fatal_error` 谓词判断是否应该重试
/// - `TimeoutError` 通常是瞬态的，应该重试
/// - 业务逻辑错误通常是致命的，不应重试
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_retry_fatal_error()
/// // 前两次 TimeoutError 重试
/// // 第三次抛出 Failure("fatal error") 不重试
/// ```
pub async fn demo_retry_fatal_error() -> String {
  let log = StringBuilder::new()
  fn fatal_error(err) {
    not(err is @async.TimeoutError)
  }

  let mut i = 0
  async fn worker() {
    log.write_string("worker run #\{i}\n")
    i = i + 1
    if i < 3 {
      @async.with_timeout(100, () => @async.sleep(1000))
    } else {
      raise Failure("fatal error")
    }
  }

  log.write_object(try? @async.retry(Immediate, fatal_error~, worker))
  log.to_string()
}

///|
/// 示例 24: 队列非阻塞读取
/// 
/// 演示使用 `Queue::try_get()` 实现非阻塞的队列读取。
/// 配合 `@async.pause()` 实现轮询模式。
/// 
/// # 最佳实践
/// - `try_get()` 返回 `Some(value)` 或 `None`（队列为空）
/// - 使用 `pause()` 让出 CPU 避免忙等待
/// - 适用于可选消费、降级处理等场景
/// 
/// # 示例
/// ```moonbit no-check
/// let result = demo_queue_try_get_nonblocking()
/// // 消费者轮询队列，为空时短暂让出
/// // 生产者每 120ms 生产一个值
/// ```
pub async fn demo_queue_try_get_nonblocking() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer fills three values with gaps
    root.spawn_bg(fn() {
      for i in 0..<3 {
        @async.sleep(120)
        q.put(i)
        log.write_string("produced \{i}\n")
      }
    })
    // consumer: prefer non阻塞读取，若为空则短暂让出
    root.spawn_bg(fn() {
      let mut consumed = 0
      while consumed < 3 {
        match q.try_get() {
          Some(v) => {
            log.write_string("consumed \{v}\n")
            consumed = consumed + 1
          }
          None => @async.pause()
        }
      }
    })
    @async.sleep(600)
  })
  log.to_string()
}

///|
/// 示例 25: 业务综合场景 - 下单与支付流程
/// 
/// 演示如何在一个真实感更强的“下单+支付”流程中组合使用
/// 超时控制与重试策略，同时保持逻辑结构清晰。
///
/// 场景设定：
/// - 有两笔订单：101 和 102；
/// - 每笔订单调用支付网关；
/// - 支付网关可能出现瞬态失败，通过指数退避重试；
/// - 整体调用被一个上限超时保护，避免长时间悬挂。
///
/// # 最佳实践
/// - 将“外部依赖调用”封装为带重试+超时的基础设施函数；
/// - 业务层只关注“下单是否成功”，日志用于诊断；
/// - 超时上限应大于“最大重试时间总和”并留有安全边界。
///
/// # 示例
/// ```moonbit no-check
/// let result = demo_business_checkout_flow()
/// // 订单 101：1 次失败 + 1 次成功
/// // 订单 102：2 次失败 + 1 次成功
/// ```
pub async fn demo_business_checkout_flow() -> String {
  let log = StringBuilder::new()
  let orders = [101, 102]

  for order_id in orders {
    log.write_string("start order \{order_id}\n")
    let outcome = @async.with_timeout_opt(500, fn() {
      let mut attempt = 0
      @async.retry(
        ExponentialDelay(initial=50, factor=2, maximum=200),
        fn() {
          log.write_string("order \{order_id} attempt \{attempt}\n")
          attempt = attempt + 1
          // 模拟瞬态失败：前几次抛出 Failure，最终成功
          if order_id == 101 && attempt < 2 {
            raise Failure("transient")
          }
          if order_id == 102 && attempt < 3 {
            raise Failure("transient")
          }
        },
      )
      "ok"
    })

    match outcome {
      Some(_) => log.write_string("order \{order_id} success\n")
      None => log.write_string("order \{order_id} timeout\n")
    }
  }

  log.to_string()
}

///|
/// 基础设施客户端封装：超时 + 重试 + 错误归一化
/// 
/// 这是"策略收口"模式的示例实现：将超时/重试策略统一封装，供业务层调用。
/// 实际项目应替换为真实 HTTP/DB 客户端调用。

///|
/// 通用封装：超时 + 重试 + 错误归一化为 `Result(_, String)`
pub async fn[X] call_with_timeout_and_retry(
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

///|
/// 模拟支付网关调用（教学用）
/// 模拟瞬态失败：order_id==101 第2次成功；order_id==102 第3次成功
pub async fn call_payment_with_retry(order_id : Int) -> Result[String, String] {
  let mut attempt = 0
  call_with_timeout_and_retry(
    500,
    @async.ExponentialDelay(initial=50, factor=2, maximum=200),
    fn() {
      attempt = attempt + 1
      if order_id == 101 && attempt < 2 {
        raise Failure("transient")
      }
      if order_id == 102 && attempt < 3 {
        raise Failure("transient")
      }
      "ok"
    },
  )
}
