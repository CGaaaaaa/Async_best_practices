# MoonBit Async 最佳实践指南

本文以可运行的示例为主线，总结 `moonbitlang/async` 在业务研发中的高频模式与建议。所有示例均在 `examples/core/core.mbt` 中可运行、可测试。

## 目录
- 结构化并发与任务组
- 超时与取消
- 关键区防取消
- 重试策略（Immediate/Fixed/Exponential）与 fatal_error
- 队列与流水线（单生产/多生产，单消费/多消费）
- 并发限流（信号量）
- 任务句柄与等待
- 持续服务循环与自动重试
- 组级清理（defer/FILO）

---

## 结构化并发与任务组
- 示例：`demo_spawn`
- 要点：
  - 所有子任务均受父作用域管控，退出时统一收敛。
  - `spawn_bg` 的“即发即弃”任务仍然会被取消传播控制。

## 超时与取消
- 示例：`demo_with_timeout`、`demo_with_timeout_opt`
- 建议：
  - 对外部依赖（IO/第三方服务）设定明确上限，避免悬挂。
  - 业务错误需保留可行动上下文（便于排障与告警汇聚）。

## 关键区防取消
- 示例：`demo_protect_from_cancel`
- 适用：提交/回滚、资源交接等原子区段。
- 谨慎：该能力会打破外层超时等抽象，仅在必要时使用。

## 重试策略与致命错误
- 示例：
  - 固定间隔：`demo_retry_fixed`
  - 指数退避：`demo_retry_exponential`
  - 立即重试：`demo_retry_immediate`
  - 致命错误终止：`demo_retry_fatal_error`
- 建议：
  - 使用 `@async.retry(strategy, max_retry?, fatal_error?)` 组合策略：
    - `Immediate` 适合极快失败/恢复场景，避免额外等待。
    - `FixedDelay(t)` 适合稳定但轻负载场景。
    - `ExponentialDelay(initial, factor, maximum)` 适合抖动恢复场景。
  - 使用 `fatal_error` 终止不可恢复错误，避免无意义重试。

## 队列与流水线
- 示例：
  - 单生产单消费：`demo_queue_pipeline`
  - 多生产多消费：`demo_queue_mpmc`
  - 非阻塞读 + 轮询：`demo_queue_try_get_nonblocking`
- 建议：
  - 写端永不阻塞；读端可阻塞（可取消）或非阻塞（`try_get`）。
  - 非阻塞轮询需搭配 `@async.pause()`，避免忙等。

## 并发限流（信号量）
- 示例：`demo_semaphore`、`demo_semaphore_try_acquire`
- 建议：
  - 优先用信号量表达并发控制，而非自制计数器。
  - 关键区应短小：acquire → work → release。

## 任务句柄与等待
- 示例：`demo_task_wait_and_try_wait`
- 用法：
  - `Task::try_wait()` 非阻塞获取；`Task::wait()` 阻塞等待。

## 持续服务循环与自动重试
- 示例：`demo_spawn_loop_retry_exponential`
- 注意：循环中使用 `IterContinue` / `IterEnd` 控制生命周期；
  指数退避在长跑服务中更友好，避免热循环。

## 组级清理（defer/FILO）
- 示例：`demo_group_defer`
- 说明：
  - `TaskGroup::add_defer(async () -> Unit)` 提供结构化清理；
  - 与 `defer`、取消传播协作，顺序可预测（FILO）。

---

## 落地建议清单（Checklist）
- 对外部交互必设超时；封装为基础设施函数统一使用。
- 重试默认指数退避；对致命错误设 `fatal_error` 终止条件。
- 采用结构化并发管理生命周期，避免“野生”任务泄漏。
- 通过信号量做并发限流；关键区尽量短平快。
- 用队列构建流水线；在高并发消费场景考虑 MPMC。
- 关键区需要时使用 `protect_from_cancel`，明确圈定边界与注释理由。

---

## 参考
- 代码：`examples/core/core.mbt`
- 测试：`examples/core/core_test.mbt`
- 上游：`.mooncakes/moonbitlang/async/`



