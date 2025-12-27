## src/ — 主教学包（完整 API 索引）

> `src/` 目录提供**系统化的 Async 示例**：用一份相对集中的代码，覆盖更多 API 与组合模式，并用大量 `async test` 做可运行验证。

---

## 这个包是什么？

`src/` 是本仓库的**"API 手册"**：
- **功能目录式**：每个 Async API 都有对应的示例函数
- **可运行验证**：所有示例都配套 `async test`，运行 `moon test` 即可验证行为
- **快速查阅**：需要"怎么用 `with_timeout_opt`"时，直接搜索 `demo_with_timeout_opt`

与 `examples/` 的区别：
- `examples/`：**业务场景**，展示如何组合多个 API（适合"学习如何写真实代码"）
- `src/`：**API 手册**，系统化覆盖所有原语（适合"查找某个 API 怎么用"）

---

## 建议用法

### 场景 A：快速上手业务写法

**优先看 `examples/` + `infra/`**
1. `examples/checkout`（10 分钟）
2. `examples/task_group`（20 分钟）
3. `examples/retry_timeout`（20 分钟）

### 场景 B：系统学习 Async API

**按 `src/Async_best_practices.mbt` 的示例章节顺序阅读**
1. 运行 `moon test --target native src/`
2. 对照输出理解每个 API 的行为
3. 修改示例代码，观察结果变化

### 场景 C：查找某个 API 的用法

**用本文档的 API 索引快速定位**
- 需要超时？→ 查阅 `demo_with_timeout` / `demo_with_timeout_opt`
- 需要重试？→ 查阅 `demo_retry_fixed_delay` / `demo_retry_exponential`
- 需要限流？→ 查阅 `demo_semaphore` / `demo_try_acquire`

---

## 完整 API 索引

### 基础异步操作

#### 1. `hello_async` — 基本超时

```moonbit
pub async fn hello_async() -> String
```

**功能**：演示基本的超时功能

**关键 API**：
- `@async.with_timeout_opt(timeout_ms, fn() { ... })`：超时返回 `None`

**测试**：
```moonbit
async test "hello_async_test" {
  let result = hello_async()
  inspect(result, content=(#|Hello, Async with timeout!|))
}
```

**学习重点**：
- 理解 `with_timeout_opt` 的基本用法
- 超时时返回 `None`，不抛出异常

---

#### 2. `concurrent_tasks` — 并发执行多个任务

```moonbit
pub async fn concurrent_tasks() -> Array[Int]
```

**功能**：演示 `TaskGroup` 的用法，并发执行多个任务

**关键 API**：
- `@async.with_task_group(fn(group) { ... })`：创建任务组
- `group.spawn(fn() { ... })`：创建子任务
- `task.wait()`：等待任务完成

**测试**：
```moonbit
async test "concurrent_tasks_test" {
  let results = concurrent_tasks()
  inspect(results, content=(#|[1, 2, 3]|))
}
```

**学习重点**：
- 用 `TaskGroup` 管理并发任务
- 所有任务都在 group 内，生命周期可控

---

#### 3. `timeout_example` — 超时处理

```moonbit
pub async fn timeout_example() -> String
```

**功能**：演示超时场景（任务耗时超过超时时间）

**关键 API**：
- `@async.with_timeout_opt(timeout_ms, fn() { ... })`
- `@async.sleep(ms)`：模拟耗时操作

**测试**：
```moonbit
async test "timeout_example_test" {
  let result = timeout_example()
  inspect(result, content=(#|Operation timed out|))
}
```

**学习重点**：
- 超时时返回 `None`
- 业务层可以根据 `None` 做降级处理

---

### 高级并发模式

#### 4. `sequential_pipeline` — 顺序流水线

```moonbit
pub async fn sequential_pipeline() -> Int
```

**功能**：顺序执行异步操作，构建数据处理流水线

**关键 API**：
- 链式调用多个 `async fn`

**测试**：
```moonbit
async test "sequential_pipeline_test" {
  let result = sequential_pipeline()
  inspect(result, content=(#|30|))
}
```

**学习重点**：
- 异步操作可以顺序组合
- 每一步的输出是下一步的输入

---

#### 5. `race_example` — 竞争场景

```moonbit
pub async fn race_example() -> String
```

**功能**：演示多个任务竞争，第一个完成者胜出

**关键 API**：
- `group.spawn(...)`：创建多个任务
- 用 `@ref.new(...)` 记录第一个完成的任务

**测试**：
```moonbit
async test "race_example_test" {
  let result = race_example()
  inspect(result, content=(#|Task 1 wins|))
}
```

**学习重点**：
- 多个任务并发，只关心第一个完成的
- 适用场景：多个数据源查询，返回最快的结果

---

### 错误处理与重试

#### 6. `retry_example` — 重试机制

```moonbit
pub async fn retry_example() -> Result[String, String]
```

**功能**：演示瞬态失败的重试机制

**关键 API**：
- `@async.retry(strategy, fn() { ... })`：自动重试
- `ExponentialDelay(initial, factor, maximum)`：指数退避

**测试**：
```moonbit
async test "retry_example_test" {
  let result = retry_example()
  inspect(result, content=(#|Ok("Success after retries")|))
}
```

**学习重点**：
- 瞬态失败可以重试（网络抖动、服务过载）
- 用指数退避避免雪崩

---

#### 7. `error_handling_example` — 错误处理与取消传播

```moonbit
pub async fn error_handling_example() -> String
```

**功能**：演示异步任务中的错误处理与取消传播

**关键 API**：
- `try...catch`：捕获异常
- `TaskGroup` 的 fail-fast 取消

**测试**：
```moonbit
async test "error_handling_example_test" {
  let result = error_handling_example()
  inspect(result, content=(#|Error: Task failed|))
}
```

**学习重点**：
- 任务失败时，兄弟任务被自动取消
- 用 `catch` 处理异常

---

### 批量处理与并发控制

#### 8. `batch_processing` — 批量处理任务

```moonbit
pub async fn batch_processing() -> Array[Int]
```

**功能**：演示批量处理任务，结合并发与限流

**关键 API**：
- `TaskGroup` + `Semaphore` 限流

**测试**：
```moonbit
async test "batch_processing_test" {
  let results = batch_processing()
  inspect(results, content=(#|[2, 4, 6, 8, 10]|))
}
```

**学习重点**：
- 批量任务需要限流，避免资源耗尽
- 用 Semaphore 控制最大并发

---

### TaskGroup 详细示例

#### 9. `demo_spawn` — TaskGroup.spawn 和 spawn_bg

```moonbit
pub async fn demo_spawn() -> String
```

**功能**：演示 `spawn` 和 `spawn_bg` 的区别

**关键 API**：
- `group.spawn(fn() { ... })`：关键任务（失败会取消 group）
- `group.spawn_bg(fn() { ... })`：后台任务（失败不影响 group）

**测试**：
```moonbit
async test "demo_spawn_test" {
  let result = demo_spawn()
  inspect(result, content=(...))
}
```

**学习重点**：
- `spawn`：关键任务，fail-fast
- `spawn_bg`：后台任务，允许失败

---

### 超时详细示例

#### 10. `demo_with_timeout` — with_timeout（抛出异常）

```moonbit
pub async fn demo_with_timeout() -> String
```

**功能**：演示 `with_timeout` 超时时抛出 `Failure`

**关键 API**：
- `@async.with_timeout(timeout_ms, fn() { ... })`：超时抛出异常

**学习重点**：
- 超时时会取消父任务
- 适用场景：超时即失败的关键操作

---

#### 11. `demo_with_timeout_opt` — with_timeout_opt（返回 Option）

```moonbit
pub async fn demo_with_timeout_opt() -> String
```

**功能**：演示 `with_timeout_opt` 超时时返回 `None`

**关键 API**：
- `@async.with_timeout_opt(timeout_ms, fn() { ... })`：超时返回 `None`

**学习重点**：
- 超时时不影响父任务
- 适用场景：超时后需要降级处理

---

### Semaphore 详细示例

#### 12. `demo_semaphore` — Semaphore 限流

```moonbit
pub async fn demo_semaphore() -> String
```

**功能**：演示 Semaphore 限流，控制并发数

**关键 API**：
- `@semaphore.Semaphore::new(n)`：创建信号量
- `semaphore.acquire()`：阻塞获取
- `semaphore.release()`：释放

**学习重点**：
- 用 Semaphore 限制最大并发
- 保护外部依赖（DB、API）

---

#### 13. `demo_semaphore_try_acquire` — 非阻塞获取

```moonbit
pub async fn demo_semaphore_try_acquire() -> String
```

**功能**：演示 `try_acquire` 非阻塞获取

**关键 API**：
- `semaphore.try_acquire()`：立即返回 `Option`

**学习重点**：
- 非阻塞获取，适用于可降级场景
- 繁忙时快速失败

---

### 关键区保护

#### 14. `demo_protect_from_cancel` — 防取消关键区

```moonbit
pub async fn demo_protect_from_cancel() -> String
```

**功能**：演示 `protect_from_cancel` 保护不可中断操作

**关键 API**：
- `@async.protect_from_cancel(fn() { ... })`

**学习重点**：
- 只在"不可中断的关键区"使用
- 例如：DB 事务、文件写入

---

### 重试详细示例

#### 15. `demo_retry_fixed_delay` — 固定延迟重试

```moonbit
pub async fn demo_retry_fixed_delay() -> String
```

**功能**：演示固定延迟重试策略

**关键 API**：
- `@async.retry(FixedDelay(delay, max_retry), fn() { ... })`

**学习重点**：
- 每次重试间隔固定
- 适用于快速瞬态失败

---

#### 16. `demo_retry_exponential` — 指数退避重试

```moonbit
pub async fn demo_retry_exponential() -> String
```

**功能**：演示指数退避重试策略

**关键 API**：
- `@async.retry(ExponentialDelay(initial, factor, maximum), fn() { ... })`

**学习重点**：
- 重试间隔指数增长
- 适用于服务过载场景

---

### 队列与流水线

#### 17. `demo_queue_pipeline` — 队列流水线

```moonbit
pub async fn demo_queue_pipeline() -> String
```

**功能**：演示 aqueue 生产者-消费者流水线

**关键 API**：
- `@aqueue.Queue::new()`：创建队列
- `queue.put(item)`：放入数据
- `queue.get()`：取出数据

**学习重点**：
- 解耦生产与消费
- 多 worker 并行处理

---

## 运行与测试

### 运行所有测试

```bash
cd /path/to/Async_best_practices
moon test --target native src/
```

**预期输出**：
```
Total tests: 33, passed: 33, failed: 0.
```

### 运行单个测试

```bash
moon test --target native src/ -f hello_async_test
```

---

## 如何引入到你的项目

如果你想在自己的项目中引用这个包（学习用）：

### 方式 1：作为依赖引入

在你的 `moon.pkg.json` 中：

```json
{
  "import": [
    "CGaaaaaa/async-best-practices/src"
  ]
}
```

然后在代码中：

```moonbit
let result = @src.hello_async()
```

### 方式 2：复制示例代码

直接复制 `src/Async_best_practices.mbt` 中的函数到你的项目，修改为真实业务逻辑。

---

## 主题索引（快速查找）

| 主题 | 示例函数 | 关键 API |
|------|---------|---------|
| **基础超时** | `hello_async`, `timeout_example` | `with_timeout_opt` |
| **并发任务** | `concurrent_tasks`, `demo_spawn` | `TaskGroup`, `spawn` |
| **超时对比** | `demo_with_timeout`, `demo_with_timeout_opt` | `with_timeout` vs `with_timeout_opt` |
| **重试策略** | `retry_example`, `demo_retry_fixed_delay`, `demo_retry_exponential` | `retry`, `ExponentialDelay` |
| **限流** | `demo_semaphore`, `demo_semaphore_try_acquire` | `Semaphore`, `acquire`, `try_acquire` |
| **关键区** | `demo_protect_from_cancel` | `protect_from_cancel` |
| **队列** | `demo_queue_pipeline` | `aqueue.Queue` |
| **错误处理** | `error_handling_example` | `try...catch` |
| **批量处理** | `batch_processing` | `TaskGroup` + `Semaphore` |

---

## 下一步

1. **运行所有测试**：`moon test --target native src/`
2. **阅读感兴趣的示例**：按主题索引查找
3. **修改示例代码**：观察行为变化
4. **对照 `examples/`**：看如何在业务中组合这些 API

---

## 常见问题

### Q1：为什么有这么多测试（33+）？

**A**：每个示例函数都配套测试，确保：
- 代码可运行（不是伪代码）
- 行为符合预期（用 `inspect` 验证输出）
- 修改仓库时不会破坏示例

### Q2：`src/` 和 `infra/` 有什么关系？

**A**：
- `src/`：展示 Async API 的"原子能力"（超时、重试、限流）
- `infra/`：把这些能力组合成"业务可用的 wrapper"（`call_with_timeout_and_retry`）

### Q3：为什么要分 `src/` 和 `examples/`？

**A**：
- `src/`：**API 手册**，系统化覆盖所有原语（适合"查找 API"）
- `examples/`：**业务场景**，展示如何组合 API（适合"学习写代码"）

### Q4：如何贡献新示例？

**A**：
1. 在 `src/Async_best_practices.mbt` 中添加新函数
2. 在 `src/Async_best_practices_test.mbt` 中添加测试
3. 更新本 `README.mbt.md` 的 API 索引
4. 提交 PR

---

**Happy Learning! 探索 MoonBit Async 的所有能力！** 🚀
