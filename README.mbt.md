# MoonBit Async 最佳实践示例库

本仓库以可运行、可测试的示例方式，系统展示 `moonbitlang/async` 的高效用法与最佳实践。

- 示例集中在 `examples/core`
- 测试采用 `inspect(...)` 快照，便于学习与回归
- 目前推荐在 native 目标下运行（见下文“目标说明”）

更多系统化讲解请阅读：`docs/best_practices.mbt.md`

## 快速开始

1) 在模块 `moon.mod.json` 中加入依赖：

```json
{
  "deps": {
    "moonbitlang/async": "^0.10.0"
  }
}
```

2) 在包的 `moon.pkg.json` 中引入需要的子包：

```json
{
  "import": [
    "moonbitlang/async",
    "moonbitlang/async/semaphore",
    "moonbitlang/async/aqueue"
  ]
}
```

3) 运行测试（native 目标）：

```bash
moon test --target native
```

如仅想快速查看某个用法，可直接打开 `examples/core/core.mbt` 搜索相应 `demo_*` 函数。

## 核心示例（文件：`examples/core/core.mbt`）

- 结构化并发：`demo_spawn`
  - 使用 `@async.with_task_group(fn(root) { ... })` 管理任务作用域
  - `root.spawn_bg` 的“即发即弃”任务仍受取消传播约束

- 超时与取消：`demo_with_timeout`
  - 用 `@async.with_timeout(ms, fn { ... })` 给异步阶段设定上限
  - 失败/超时要记录可行动上下文，便于排障

- 关键区防取消：`demo_protect_from_cancel`
  - 用于提交/回滚、持久化指标、资源交接等原子阶段
  - 仅在必要时使用，因其会打破外层超时等抽象

- 并发限流（信号量）：`demo_semaphore`
  - 优先使用信号量而非自制计数器
  - 关键区应短小：acquire → work → release

- 重试策略：`demo_retry_fixed`
  - 使用 `@async.retry(FixedDelay(...), fn { ... })` 实现“固定间隔+上限”的退避

- 可选超时：`demo_with_timeout_opt`
  - `@async.with_timeout_opt(ms, fn)` 返回 `Some(value)` 或 `None`，便于直接分支

- 队列/管道：`demo_queue_pipeline`
  - 使用 `@aqueue.Queue` 构建生产者-消费者流水线
  - 非阻塞写、阻塞读（可被取消），先到先服务

新增示例：

- 重试（指数退避）：`demo_retry_exponential`
  - `@async.retry(ExponentialDelay(initial, factor, maximum), fn)`
  - 可视化 backoff 时间线，避免热循环

- 信号量非阻塞获取：`demo_semaphore_try_acquire`
  - 用 `Semaphore.try_acquire()` 走“快速失败/降级”路径
  - 与阻塞式 `acquire()` 搭配，构建更灵活的限流

- 多生产者/多消费者队列：`demo_queue_mpmc`
  - 2P/2C 的 FIFO 消费，输出对值序列断言而非线程 ID

- 任务句柄与等待：`demo_task_wait_and_try_wait`
  - `Task::try_wait()` 获取非阻塞结果；`Task::wait()` 阻塞直到完成

- 持续服务循环：`demo_spawn_loop_retry_exponential`
  - `root.spawn_loop(retry=ExponentialDelay(...), fn -> IterResult)`
  - 在循环体内自动重试 + 以 `IterEnd` 退出

- 组级清理：`demo_group_defer`
  - `TaskGroup::add_defer(async () -> Unit)` 提供结构化清理
  - 与 `defer`、取消传播协作，顺序可预测（FILO）

运行这些示例的测试可直观看到事件时间线与预期输出。

## 运行与更新快照

- 运行：`moon test --target native`
- 行为变更后更新快照：`moon test --target native --update`

## 目标说明

- 上游 `moonbitlang/async` 内部使用 C FFI，`wasm-gc` 目前不支持
- 推荐 `--target native`；如需 `--target wasm/js`，请按需替换依赖

## 发布到 Mooncakes（可选）

若你 fork/改造了本仓库，希望以模块形式分发：

1) 修改 `moon.mod.json`：

```json
{
  "name": "yourname/async-best-practices",
  "repository": "https://github.com/yourname/async-best-practices"
}
```

2) 确保 `README.mbt.md` 为入口文档（本仓库已配置 `readme` 字段）。

3) 在 Mooncakes 配置凭据后，执行发布命令（以官方指南为准），通常为：

```bash
moon publish
```

注意：`name` 前缀需为你的 Mooncakes 用户名；建议仓库名和模块名使用小写连字符风格。

## 进一步阅读

- 查看 `examples/core/core.mbt` 以学习紧凑的惯用写法
- 参考上游 `.mooncakes/moonbitlang/async/` 中更高级的 IO/HTTP/进程控制示例与文档