## MoonBit Async 最佳实践（面向业务开发）

本仓库的目标是：让程序员或 AI **通过阅读 + 运行代码**，快速掌握 `moonbitlang/async` 的高效用法，并能把这些模式迁移到真实业务。

### 0. 总原则（评审时逐条对照）

- **策略统一收口到 infra**：超时/重试/限流/错误归一化不要散落在业务代码里
- **结构化并发（TaskGroup）**：任务必须“有父亲”，生命周期可控，取消可传播
- **有限并发与背压**：对外部依赖（DB/第三方）必须限流；队列默认需要背压策略
- **失败要可见**：明确区分关键任务（fail-fast）与允许失败的后台任务（allow_failure/no_wait）
- **测试要覆盖策略**：至少覆盖成功/超时/瞬态失败重试成功/取消传播

### 1. 推荐的 repo 学习路径

- **先系统扫一遍主教材**：`src/Async_best_practices.mbt`（功能目录式示例 + 大量测试）
- **先跑通最小闭环**：`examples/checkout`
- **再看结构化并发**：`examples/task_group`
- **学习“策略收口”**：`examples/retry_timeout`（统一超时 + 重试 wrapper）
- **学习限流**：`examples/semaphore_limiter`
- **学习流水线**：`examples/pipeline_queue`

### 1.1 主题对照索引（看哪里最快）

- **超时**：
  - `src/Async_best_practices.mbt`: `hello_async`, `timeout_example`, `demo_with_timeout`, `demo_with_timeout_opt`
  - `examples/retry_timeout`: `timeout_returns_err`
- **结构化并发 / TaskGroup**：
  - `src/Async_best_practices.mbt`: `concurrent_tasks` 以及多处 `demo_*`
  - `examples/task_group`: `fail_fast_cancels_sibling`, `sum_two_tasks`
- **重试**：
  - `src/Async_best_practices.mbt`: `retry_example`, `demo_retry_exponential`
  - `infra/clients.mbt`: `call_with_timeout_and_retry`
  - `examples/retry_timeout`: `retry_then_ok`
- **限流（Semaphore）**：
  - `src/Async_best_practices.mbt`: `demo_semaphore`, `demo_try_acquire`
  - `examples/semaphore_limiter`: `max_concurrency_observed`
- **队列/流水线（Queue）**：
  - `src/Async_best_practices.mbt`: `demo_queue_pipeline`
  - `examples/pipeline_queue`: `pipeline_sum`

### 2. 业务代码应该长什么样（目标形态）

- **业务层**：只表达“我要调用什么/如何组合结果”
- **infra 层**：统一处理“怎么调用”（超时/重试/限流/错误归一化/观测）

反例（不推荐）：
- 业务里到处 `@async.with_timeout_opt(...)`
- 业务里自己决定重试次数/退避参数（难审查、难统一调参）

正例（推荐）：
- 业务里只调用 `@infra.call_with_timeout_and_retry(...)` 这类 wrapper

### 3. TaskGroup：结构化并发与取消传播

推荐：
- 用 `@async.with_task_group` 把“这一段业务”包起来
- 用 `group.spawn`/`group.spawn_bg` 创建子任务
- 默认 `allow_failure=false` 形成 fail-fast：关键任务失败时自动取消兄弟任务

什么时候用 `allow_failure=true`：
- 明确是“后台可选任务”（例如打点、异步预热、非关键缓存刷新）

### 4. 超时与重试：务必统一封装

建议：
- **所有外部依赖**都必须有超时（避免无界等待）
- 重试只用于“瞬态错误”，不要对逻辑错误/权限错误/参数错误重试
- 重试必须可调参（initial/factor/max_retry），便于不同依赖差异化治理

### 5. 限流：Semaphore 是最小可用方案

建议：
- 对 DB 连接、第三方 API 调用、CPU 密集任务都加并发上限
- 先用 Semaphore（简单、好审查），复杂场景再引入更高级的 rate limiter

### 6. 队列/流水线：默认要考虑背压

注意：
- `aqueue.Queue` 是无界缓冲：生产者一直 put 会导致内存增长
- 业务中一般需要“背压策略”（例如：用 Semaphore 控制 producer、分批 put、或引入有界队列）

### 7. PR 检查清单（上线必备）

- **外部调用**：是否都通过 infra wrapper？是否设置超时？重试策略是否合理？
- **并发**：是否使用 TaskGroup？是否避免野生 spawn？是否有限流？
- **取消**：入口取消能否传播到子任务？是否滥用 protect_from_cancel？
- **测试**：是否覆盖超时/重试/取消传播？是否能稳定复现？


