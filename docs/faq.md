# 常见问题（FAQ）

> 本文档回答开发者在使用 MoonBit Async 时最常遇到的问题，按主题分类。

---

## 目录

- [基础概念](#基础概念)
- [超时与重试](#超时与重试)
- [TaskGroup 与并发](#taskgroup-与并发)
- [错误处理](#错误处理)
- [性能与调优](#性能与调优)
- [测试与调试](#测试与调试)
- [常见错误排查](#常见错误排查)

---

## 基础概念

### Q1: MoonBit Async 和其他语言的 async/await 有什么区别？

**A**: 主要区别：

| 特性 | MoonBit Async | JavaScript/TypeScript | Rust async | Go |
|------|--------------|----------------------|-----------|-----|
| **错误处理** | Checked errors (raise) | try-catch | Result/? | panic/error |
| **取消机制** | TaskGroup 自动传播 | AbortController | 手动检查 | context.Context |
| **结构化并发** | 内置 TaskGroup | 无 | 需要库支持 | WaitGroup |
| **超时** | `with_timeout` | Promise.race | timeout crate | context.WithTimeout |

**核心优势**：MoonBit 的 TaskGroup 确保任务有明确的生命周期和取消传播，避免资源泄漏。

---

### Q2: 什么时候应该使用 Async？

**A**: 适用场景：

✅ **应该使用**：
- 网络请求（HTTP API、RPC）
- 数据库查询
- 文件 I/O
- 任何可能阻塞的操作

❌ **不应该使用**：
- 纯计算（同步函数更简单）
- 简单的内存操作
- 已经很快的操作（< 1ms）

---

### Q3: `async fn` 和普通 `fn` 有什么区别？

**A**:

```moonbit
// 普通函数：立即执行，返回结果
fn add(a : Int, b : Int) -> Int {
  a + b
}

// 异步函数：可能需要等待，支持并发
async fn fetch_data(url : String) -> String {
  @async.sleep(100)  // 可以暂停
  "data"
}
```

**关键区别**：
- `async fn` 可以调用其他 `async fn` 和使用 Async API（如 `sleep`、`with_timeout`）
- 普通 `fn` 不能调用 `async fn`（会编译错误）

---

## 超时与重试

### Q4: `with_timeout` 和 `with_timeout_opt` 有什么区别？

**A**:

| API | 超时行为 | 返回类型 | 推荐场景 |
|-----|---------|---------|---------|
| `with_timeout_opt` | 返回 `None` | `T?` | ⭐ 超时后需要降级处理 |
| `with_timeout` | 抛出 `Failure` | `T` | 超时即失败的关键操作 |

**推荐用法**：

```moonbit
// ✅ 推荐：用 with_timeout_opt + 转为 Result
@async.with_timeout_opt(1000, fn() {
  call_api()
}) match {
  Some(v) => Ok(v)
  None => Err("timeout")
}

// ⚠️ 慎用：with_timeout 会取消父任务
@async.with_timeout(1000, fn() {
  call_api()
})
```

---

### Q5: 超时时间应该设置多少？

**A**: 根据依赖类型设置：

| 依赖类型 | 推荐超时 | 理由 |
|---------|---------|------|
| 内部 RPC | 500ms - 1s | 同机房延迟低 |
| 第三方 API | 3s - 5s | 网络不稳定 |
| DB 查询 | 1s - 2s | 慢查询可能阻塞 |
| 文件上传 | 10s - 30s | 大文件传输慢 |

**动态调整**：生产环境应根据 P99 延迟动态调整。

---

### Q6: 什么时候应该重试？什么时候不应该重试？

**A**:

✅ **应该重试的错误**：
- 网络抖动（`network_error`）
- 服务过载（`503 Service Unavailable`）
- Rate limit（`429 Too Many Requests`）
- 超时（`timeout`）

❌ **不应该重试的错误**：
- 参数错误（`400 Bad Request`）
- 权限错误（`401 Unauthorized`, `403 Forbidden`）
- 资源不存在（`404 Not Found`）
- 逻辑错误（业务规则违反）

**示例**：

```moonbit
call_api() catch {
  "503" | "timeout" | "network_error" => retry_call_api()  // ✅ 重试
  "401" | "400" | "404" => Err("permanent_error")          // ❌ 不重试
}
```

---

### Q7: ExponentialDelay 和 FixedDelay 应该怎么选？

**A**:

| 策略 | 适用场景 | 参数示例 |
|------|---------|---------|
| **ExponentialDelay** | 服务过载、rate limit | `initial=100, factor=2, max=2000` |
| **FixedDelay** | 快速瞬态失败、网络抖动 | `delay=100, max_retry=3` |

**重试时序对比**：

```
FixedDelay(100, 3):
  0ms → 100ms → 200ms → 300ms

ExponentialDelay(100, 2, 2000):
  0ms → 100ms → 300ms → 700ms → 1500ms → 2000ms
```

**推荐**：默认用 `ExponentialDelay`，除非重试间隔很短（< 200ms）。

---

### Q8: 重试次数应该设置多少？

**A**: 根据场景设置：

| 场景 | 推荐次数 | 理由 |
|------|---------|------|
| 快速瞬态失败 | 2-3 次 | 网络抖动通常很快恢复 |
| 服务过载 | 5-10 次 | 需要给服务恢复时间 |
| Rate limit | 3-5 次 | 等待 rate limit 窗口重置 |

**注意**：总重试时间 = 每次延迟之和，不要让用户等太久（建议 < 30s）。

---

## TaskGroup 与并发

### Q9: 为什么不能用 `@async.spawn`？

**A**: `@async.spawn` 创建的任务**没有父亲**，会导致：

❌ **问题**：
- 取消信号不传播（父任务取消时，子任务还在跑）
- 难以追踪任务生命周期
- 资源泄漏（任务永远不结束）

✅ **解决方案**：用 `TaskGroup`：

```moonbit
// ❌ 错误
let t = @async.spawn(fn() { ... })

// ✅ 正确
@async.with_task_group(fn(group) {
  let t = group.spawn(fn() { ... })
  t.wait()
})
```

---

### Q10: `spawn` 和 `spawn_bg` 有什么区别？

**A**:

| API | 失败行为 | 适用场景 |
|-----|---------|---------|
| `spawn` | fail-fast（一个失败，全部取消）| ⭐ 关键任务 |
| `spawn_bg` | 允许失败，不影响主流程 | 后台任务 |

**示例**：

```moonbit
@async.with_task_group(fn(group) {
  let main = group.spawn(fn() { 
    process_order()  // 关键任务，失败应该取消一切
  })
  
  group.spawn_bg(fn() { 
    log_metrics()  // 后台任务，失败了也没关系
  })
  
  main.wait()
})
```

**什么是"后台任务"**：打点、日志、非关键缓存、预热等。

---

### Q11: 如何控制最大并发数？

**A**: 用 `Semaphore`：

```moonbit
let sem = @semaphore.Semaphore::new(20)  // 最大 20 并发

@async.with_task_group(fn(group) {
  for item in items {
    group.spawn_bg(fn() raise {
      sem.acquire()  // 阻塞等待槽位
      process(item)
      sem.release()
    })
  }
})
```

**并发数设置建议**：
- DB 查询：连接池大小 - 10
- 第三方 API：QPS 限制 / 平均耗时
- CPU 密集：CPU 核心数 × 1.5 ~ 2

---

### Q12: `acquire()` 和 `try_acquire()` 有什么区别？

**A**:

| API | 阻塞行为 | 返回类型 | 适用场景 |
|-----|---------|---------|---------|
| `acquire()` | 阻塞等待 | `Unit` | ⭐ 必须执行的任务 |
| `try_acquire()` | 立即返回 | `Unit?` | 可降级的任务 |

**示例**：

```moonbit
// ✅ 必须执行（推荐）
sem.acquire()
process()
sem.release()

// ✅ 可降级（繁忙时跳过）
match sem.try_acquire() {
  Some(_) => { process(); sem.release() }
  None => log("too busy, skip")
}
```

---

## 错误处理

### Q13: 如何在测试中捕获错误？

**A**: 用 `try?` 转为 `Result`：

```moonbit
test "test_error" {
  let result : Result[Int, Error] = try? my_function_that_raises()
  
  match result {
    Ok(v) => inspect(v, content="...")
    Err(e) => inspect(e, content="...")
  }
}
```

---

### Q14: `raise` 和 `panic` 有什么区别？

**A**:

| 特性 | `raise` | `panic` / `fail` |
|------|---------|-----------------|
| 类型检查 | ✅ 编译时检查 | ❌ 运行时崩溃 |
| 可恢复 | ✅ 用 `try...catch` | ❌ 程序终止 |
| 适用场景 | 业务错误 | 不可恢复的错误 |

**推荐用法**：

```moonbit
// ✅ 业务错误：用 raise
fn parse_int(s : String) -> Int raise ParseError {
  if s is "" { raise ParseError::Empty }
  ...
}

// ✅ 不可恢复：用 fail
fn internal_bug() -> Unit {
  fail("This should never happen!")
}
```

---

### Q15: 如何定义自己的错误类型？

**A**: 用 `suberror`：

```moonbit
suberror MyError {
  InvalidInput(String)
  Timeout
  NetworkError(Int)  // 可以带参数
} derive(Show, Eq)

fn my_function() -> Int raise MyError {
  raise MyError::Timeout
}
```

---

## 性能与调优

### Q16: 如何提高并发性能？

**A**: 优化策略：

1. **调整并发数**：根据瓶颈资源（CPU/DB/API）调整 Semaphore 大小
2. **减少重试次数**：不要盲目重试，快速失败
3. **批量处理**：将小请求合并为批量请求
4. **缓存结果**：避免重复计算

**示例**：

```moonbit
// ❌ 慢：每个请求单独调用
for id in ids {
  fetch_user(id)
}

// ✅ 快：批量调用
fetch_users_batch(ids)
```

---

### Q17: 如何避免内存爆炸？

**A**: 关键策略：

1. **用 Semaphore 控制队列大小**：

```moonbit
let queue = @aqueue.Queue::new()
let sem = @semaphore.Semaphore::new(100)  // 队列最多 100 条
```

2. **分批处理大数据集**：

```moonbit
for batch in items.chunks(100) {
  process_batch(batch)
}
```

3. **及时释放资源**：

```moonbit
let conn = db.connect()
process(conn)
conn.close()  // 不要忘记
```

---

### Q18: 为什么我的程序很慢？

**A**: 常见原因与排查：

| 原因 | 症状 | 排查方法 |
|------|------|---------|
| **并发数太小** | CPU 利用率低 | 增大 Semaphore 大小 |
| **并发数太大** | 频繁 GC | 减小 Semaphore 大小 |
| **没有批量处理** | 请求数多 | 改为批量 API |
| **重试过多** | 延迟高 | 减少重试次数 |
| **没有缓存** | 重复计算 | 加缓存 |

**调试技巧**：打印时序日志，找出瓶颈。

---

## 测试与调试

### Q19: 如何测试异步代码？

**A**: 用 `async test` + `inspect`：

```moonbit
async test "test_my_function" {
  let result = my_async_function()
  inspect(result, content=(#|Expected output|))
}
```

**运行测试**：

```bash
moon test --target native
moon test --update  # 更新快照
```

---

### Q20: 如何测试超时场景？

**A**: 模拟慢操作：

```moonbit
async test "test_timeout" {
  let result = @infra.call_with_timeout_and_retry(50, fn() {
    @async.sleep(200)  // 操作耗时 200ms，超时 50ms
    "ok"
  })
  
  inspect(result, content=(#|Err("timeout")|))
}
```

---

### Q21: 如何测试重试？

**A**: 用计数器模拟瞬态失败：

```moonbit
async test "test_retry" {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 3 {
      raise Failure("transient")  // 前 2 次失败
    }
    "ok"  // 第 3 次成功
  })
  
  inspect(result, content=(#|Ok("ok")|))
  assert_eq!(attempts, 3)
}
```

---

### Q22: 如何调试异步代码？

**A**: 调试技巧：

1. **打印时序日志**：

```moonbit
let log = StringBuilder::new()
log.write_string("Step 1: \{now()}\n")
@async.sleep(100)
log.write_string("Step 2: \{now()}\n")
println(log.to_string())
```

2. **减少并发**：

```moonbit
// 调试时：改为串行
let sem = @semaphore.Semaphore::new(1)
```

3. **用 inspect 验证中间状态**：

```moonbit
let intermediate = compute_something()
inspect(intermediate, content=(...))  // 验证中间结果
```

---

### Q23: 如何测试取消传播？

**A**: 模拟任务失败：

```moonbit
async test "test_cancellation" {
  let log = StringBuilder::new()
  
  ignore(
    @async.with_task_group(fn(group) {
      group.spawn(fn() {
        @async.sleep(100)
        log.write_string("Task 1 done\n")  // 不会执行（被取消）
      })
      
      group.spawn(fn() {
        log.write_string("Task 2 failed\n")
        raise Failure("error")
      })
    })
  ) catch { _ => () }
  
  // 验证 Task 1 没有执行
  inspect(log.to_string(), content=(#|Task 2 failed\n|))
}
```

---

## 常见错误排查

### Q24: 错误：`Cannot use raise in a function without error types`

**原因**：函数签名没有声明 `raise`

```moonbit
// ❌ 错误
fn my_function() -> Int {
  raise Failure("error")  // 编译错误！
}

// ✅ 正确
fn my_function() -> Int raise {
  raise Failure("error")
}
```

---

### Q25: 错误：`The value identifier ... is unbound`

**原因**：没有在 `moon.pkg.json` 中引入包

```json
// ✅ 在 moon.pkg.json 中添加
{
  "import": [
    "moonbitlang/async"
  ]
}
```

---

### Q26: 为什么我的队列一直堆积？

**原因**：生产速度 > 消费速度，且没有背压

**解决方案**：用 Semaphore 控制队列大小（见 Q17）

---

### Q27: 为什么任务没有被取消？

**原因**：

1. 用了 `@async.spawn`（没有 TaskGroup）
2. 用了 `spawn_bg`（允许失败）
3. 用了 `protect_from_cancel`（保护了整个函数）

**排查**：检查是否正确使用 `with_task_group` + `spawn`。

---

### Q28: 为什么测试一直失败？

**常见原因**：

1. **快照过期**：运行 `moon test --update`
2. **时序问题**：增加 `@async.sleep` 等待
3. **并发竞争**：改为串行测试

---

## 更多资源

### 推荐阅读顺序

1. **业务与 infra 分层**：查看 [examples/README.md](../examples/README.md) 中的 checkout 示例
2. **完整指南**：[最佳实践](./best_practices.md)
3. **API 参考**：[快速参考](./quick-reference.md)
4. **运行示例**：`moon test --target native src/` 查看所有 API 示例

### 获取帮助

- **文档问题**：查阅 [MoonBit 官方文档](https://docs.moonbitlang.com/)
- **代码示例**：参考 [examples/](../examples/)
- **真实案例**：查看 [examples/api-gateway/](../examples/api-gateway/)

---

**FAQ 更新时间**: 2025-12-28  
**问题总数**: 28 个

有新问题？欢迎提交 Issue 或 PR！

