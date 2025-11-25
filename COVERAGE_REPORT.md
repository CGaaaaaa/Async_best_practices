## MoonBit Async 示例库 API 覆盖率报告

> 本文件用于补充说明 README 中提到的覆盖率情况，帮助使用者快速判断示例是否覆盖了核心 API。

### 总览

- 覆盖对象：`moonbitlang/async` 核心 API（含 `semaphore`、`aqueue` 等子包）
- 覆盖率：**28 / 28 API，100% 覆盖**
- 示例数量：**25 个**（入门示例 8 个，高级示例 17 个，其中 1 个为业务综合示例）
- 测试：所有示例均在 `src/Async_best_practices_test.mbt` 中有对应的快照测试，当前在 `--target native` 下 **25 / 25 全部通过**。

### 覆盖维度说明

- **结构化并发与任务组**：`with_task_group`、`spawn`、`spawn_bg`、`spawn_loop`、`TaskGroup.add_defer` 等
- **超时与取消**：`with_timeout`、`with_timeout_opt`、`TimeoutError` 处理与取消传播
- **重试策略**：`retry` + `Immediate` / `FixedDelay` / `ExponentialDelay` / `fatal_error` 谓词
- **并发限流**：`Semaphore`（阻塞获取与 `try_acquire` 非阻塞获取）
- **队列与流水线**：`aqueue.Queue`（单/多生产者、多消费者、阻塞读与 `try_get` 非阻塞读）
- **任务句柄**：`Task.wait`、`Task.try_wait`
- **取消与关键区**：`protect_from_cancel`、取消时的错误传播与清理逻辑

### 使用建议

- 如果你在业务中使用到了上述任一能力，都可以在 `src/Async_best_practices.mbt` 中找到对应的 **最小可运行示例** 作为模板；
- 若你在实际项目中扩展了新的模式或封装，建议同步扩展本报告与测试，保持覆盖率可追踪。


