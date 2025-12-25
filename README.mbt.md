# MoonBit Async 最佳实践示例库

本仓库以可运行、可测试的示例方式，系统展示 `moonbitlang/async` 的高效用法与最佳实践。

## 📖 简介

`moonbitlang/async` 是 MoonBit 的异步编程库，提供了结构化并发、任务组管理、超时控制、重试策略、队列和信号量等核心功能。本仓库通过 **25 个精心设计的示例**，帮助程序员和 AI 代码助手快速掌握异步编程的最佳实践。

## 如何在项目中高效使用 Async（面向程序员与 AI 的实战指南）

本节聚焦「如何把 Async 用好并落地到业务逻辑」，目标是让程序员或 AI 在引入本库后**能直接上手、复用模板并遵循最佳实践**。下面按原则、模板、测试与审查四个维度给出可复制的操作清单与代码片段。

核心原则（短平快）
- 对所有外部依赖（网络/DB/第三方）统一使用超时 + 重试封装（基础设施层）；
- 使用结构化并发（TaskGroup）管理生命周期，避免野生/泄漏任务；
- 使用信号量限制并发资源（连接池、并发请求）；
- 将非关键后台任务标记为 allow_failure 或 spawn_bg，并注册组级清理。

推荐基础设施模板（可拷贝）

1) 外部调用统一封装（超时 + 指数退避）

```moonbit no-check
pub async fn call_with_timeout_and_retry[T](timeout_ms : Int, fn_call : () -> T) -> Result[T, String] {
  @async.with_timeout_opt(timeout_ms, fn() {
    @async.retry(ExponentialDelay(initial=100, factor=2, maximum=1000), fn() {
      // 调用外部客户端（可能 raise/Failure）
      fn_call()
    })
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}
```

说明：把上面函数放到 `infra/clients.mbt`，业务层直接调用并处理 Result。

2) HTTP/请求处理器模板（在 handler 中使用 TaskGroup）

```moonbit no-check
pub async fn handle_request(req) -> Response {
  @async.with_task_group(fn(root) {
    // 并发请求内的子任务都在 group 作用域内
    let db_task = root.spawn(fn() {
      call_with_timeout_and_retry(500, fn() { query_db(req.id) })
    })
    let external = root.spawn(fn() {
      call_with_timeout_and_retry(1000, fn() { call_payment(req) })
    })
    // 等待关键结果
    let db_res = db_task.wait()
    let pay_res = external.wait()
    // 组合业务逻辑
    merge_results(db_res, pay_res)
  })
}
```

3) 信号量限流（数据库/外部 API）

```moonbit no-check
let db_sem = @semaphore.Semaphore::new(10) // 最大并发 10
root.spawn_bg(fn() {
  db_sem.acquire()
  defer db_sem.release()
  do_db_work()
})
```

4) 队列 + 消费者流水线（生产者/消费者）

```moonbit no-check
let q = @aqueue.Queue::new()
// producer
root.spawn_bg(fn() {
  for item in items { q.put(item) }
})
// consumer
root.spawn_bg(fn() {
  while let Some(v) = q.get() { process(v) }
})
```

关键测试与审查要点
- 为每个基础设施函数（call_with_timeout_and_retry、client wrapper）写单元/集成测试并使用 snapshot 验证错误/成功路径；
- 在 PR 检查列表中加入：是否对外部调用设置超时？是否使用 TaskGroup 管理任务？是否使用信号量限制关键资源？
- 对复杂业务流程（如下单+支付）添加端到端快照，验证重试与超时的时间线。

常见陷阱（快速检查）
- 忘记给外部调用设置超时；
- 在全局/顶层 spawn 野生任务，导致进程退出后任务仍运行或泄漏；
- 在持有信号量期间执行长耗时操作（应把关键区短化）；
- 把关键提交（commit）放在可被取消的上下文中，必要时用 `protect_from_cancel`。

AI 使用建议
- 对 AI 提问时，直接引用示例函数名（如 `demo_retry_exponential`、`demo_business_checkout_flow`），并说明想要的场景（例如“下单并发 1000 QPS 的限流策略”），AI 可据此给出可运行修改建议；
- AI 自动改代码时优先改 infra 层（client wrapper）而非业务层，便于全局回滚与验证。

小结：把“超时+重试”封装成基础设施，把“并发/资源控制”用信号量抽象，把“任务生命周期”交给 TaskGroup。示例代码与测试放在 `src/`，基础设施建议放在 `infra/`（或在项目内相应包）。

### 为什么需要这个库？

- **学习曲线陡峭**：异步编程涉及任务组、取消传播、结构化并发等复杂概念
- **最佳实践分散**：官方文档可能缺少实际业务场景的完整示例
- **AI 辅助开发**：通过系统化的示例，AI 代码助手能更好地理解和使用 Async 库
- **快速上手**：每个示例都是可运行的，配合测试可以直观看到执行效果

## 🎯 项目亮点

- 🎉 **100% API 覆盖率**（28/28 API，完整覆盖！）
- ✅ **25 个完整示例**（入门 8 个 + 高级 17 个，其中 1 个为业务综合示例）
- ✅ **100% 测试通过率**（所有示例均有快照测试）
- ✅ **约 1600 行精心设计的代码**
- 📚 **系统化文档**：从基础概念到高级模式，循序渐进
- 🔍 **可运行示例**：每个示例都可以直接运行和测试

## 📁 项目结构

```
Async_best_practices/
├── README.mbt.md              # 项目主文档（本文件）
├── docs/
│   └── best_practices.mbt.md  # 详细的最佳实践指南
├── src/
│   ├── Async_best_practices.mbt      # 25 个示例实现
│   └── Async_best_practices_test.mbt # 对应的测试用例
├── moon.mod.json              # 模块配置
└── LICENSE                    # Apache-2.0 许可证
```

### 文档说明

- **README.mbt.md**（本文件）：项目概览、快速开始、示例索引
- **docs/best_practices.mbt.md**：系统化的最佳实践指南，包含设计理念和详细说明
- **src/Async_best_practices.mbt**：所有示例的实现代码，每个函数都有详细注释
- **src/Async_best_practices_test.mbt**：测试用例，使用 `inspect()` 快照测试

### 运行环境

- 推荐使用 **native 目标**（`--target native`）
- 测试采用 `inspect(...)` 快照，便于学习与回归

## 🚀 快速开始

### 环境要求

- **MoonBit 工具链**：已安装 MoonBit（参考官方文档 [https://docs.moonbitlang.com](https://docs.moonbitlang.com)）
- **Native 目标**：推荐使用 `--target native`
  - macOS：建议安装 Xcode Command Line Tools 以确保 C 工具链可用
  - Linux：确保已安装 gcc/clang 等 C 编译器
  - Windows：需要配置 C 工具链

### 安装步骤

#### 1. 克隆或下载本仓库

```bash
git clone https://github.com/CGaaaaaa/Async_best_practices.git
cd Async_best_practices
```

#### 2. 配置依赖

在模块 `moon.mod.json` 中确保包含依赖：

```json
{
  "deps": {
    "moonbitlang/async": "0.11.0"
  }
}
```

#### 3. 配置包导入

在包的 `moon.pkg.json` 中引入需要的子包：

```json
{
  "import": [
    "moonbitlang/async",
    "moonbitlang/async/semaphore",
    "moonbitlang/async/aqueue"
  ]
}
```

#### 4. 运行测试

```bash
# 运行所有测试
moon test --target native

# 运行并更新快照（如果行为变更）
moon test --target native --update
```

#### 5. 查看示例代码

直接打开 `src/Async_best_practices.mbt` 搜索相应函数名，每个函数都有详细的文档注释和示例。

### 在你的项目中使用

如果你想在自己的项目中参考这些示例：

1. **复制示例代码**：从 `src/Async_best_practices.mbt` 中复制需要的函数
2. **阅读文档注释**：每个函数都有 `///|` 开头的详细注释，说明用法和最佳实践
3. **运行测试验证**：参考 `src/Async_best_practices_test.mbt` 中的测试用例
4. **阅读最佳实践指南**：查看 `docs/best_practices.mbt.md` 了解设计理念

## 📚 示例索引

本仓库包含 **25 个完整示例**，涵盖从入门到高级的各种异步编程模式。所有示例都在 `src/Async_best_practices.mbt` 文件中，每个函数都有详细的文档注释。

### 入门示例（示例 1-8）

适合刚开始学习 Async 库的开发者，涵盖最常用的基础功能：

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 1 | `hello_async` | 简单的异步函数与超时 | `with_timeout_opt` |
| 2 | `concurrent_tasks` | 并发执行多个任务 | `with_task_group`, `spawn`, `wait` |
| 3 | `timeout_example` | 超时处理长时间运行的任务 | 超时控制 |
| 4 | `sequential_pipeline` | 顺序执行异步操作（数据处理流水线） | 异步流水线 |
| 5 | `race_example` | 竞速模式 - 返回最快完成的任务 | `spawn_bg`, `return_immediately` |
| 6 | `retry_example` | 重试机制 - 手动实现指数退避 | 手动重试逻辑 |
| 7 | `error_handling_example` | 错误隔离 - 允许部分任务失败 | `allow_failure=true` |
| 8 | `batch_processing` | 批量处理 - 并发处理集合元素 | 批量并发 |

### 高级示例（示例 9-25）

适合有一定基础的开发者，涵盖更复杂的异步编程模式和最佳实践：

#### 结构化并发与任务管理

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 9 | `demo_spawn` | 结构化并发 - 任务组管理 | `with_task_group`, `spawn_bg` |
| 19 | `demo_task_wait_and_try_wait` | 任务句柄与等待 | `Task::try_wait()`, `Task::wait()` |
| 21 | `demo_group_defer` | 组级清理 | `add_defer`, FILO 顺序 |

#### 超时与取消控制

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 10 | `demo_with_timeout` | 超时与取消传播 | `with_timeout`, 取消传播 |
| 14 | `demo_with_timeout_opt` | 可选超时 | `with_timeout_opt`, `Option` 处理 |
| 12 | `demo_protect_from_cancel` | 关键区防取消 | `protect_from_cancel` |

#### 重试策略

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 13 | `demo_retry_fixed` | 固定延迟重试 | `retry(FixedDelay(...))` |
| 16 | `demo_retry_exponential` | 指数退避重试 | `retry(ExponentialDelay(...))` |
| 22 | `demo_retry_immediate` | 立即重试 | `retry(Immediate)` |
| 23 | `demo_retry_fatal_error` | 重试致命错误 | `fatal_error` 谓词 |
| 20 | `demo_spawn_loop_retry_exponential` | 持续服务循环 | `spawn_loop`, `IterResult` |

#### 并发控制

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 11 | `demo_semaphore` | 信号量限流 | `Semaphore`, `acquire`, `release` |
| 17 | `demo_semaphore_try_acquire` | 信号量非阻塞获取 | `try_acquire()` |

#### 队列与流水线

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 15 | `demo_queue_pipeline` | 队列流水线 | `Queue`, `put`, `get` |
| 18 | `demo_queue_mpmc` | 多生产者/多消费者队列 | MPMC 模式 |
| 24 | `demo_queue_try_get_nonblocking` | 队列非阻塞读取 | `try_get()`, `pause()` |

#### 业务综合场景

| 示例 | 函数名 | 说明 | 核心概念 |
|------|--------|------|----------|
| 25 | `demo_business_checkout_flow` | 业务综合场景 - 下单与支付流程 | 组合使用超时、重试、错误处理 |

### 如何查找示例

1. **按功能查找**：使用上表快速定位需要的功能
2. **搜索代码**：在 `src/Async_best_practices.mbt` 中搜索函数名
3. **查看测试**：在 `src/Async_best_practices_test.mbt` 中查看对应的测试用例
4. **阅读文档**：每个函数都有详细的 `///|` 注释，说明用法和最佳实践

### 示例代码结构

每个示例都遵循以下结构：

```moonbit
///|
/// 示例 N: 标题 - 简短描述
/// 
/// 详细说明该示例的用途和使用场景。
/// 
/// # 最佳实践
/// - 列出关键的最佳实践要点
/// - 说明何时使用该模式
/// 
/// # 示例
/// ```moonbit no-check
/// let result = example_function()
/// // 说明预期结果
/// ```
pub async fn example_function() -> String {
  // 实现代码
  "result"
}
```

运行这些示例的测试可直观看到事件时间线与预期输出。

## 🛠️ 开发指南

### 运行测试

```bash
# 运行所有测试
moon test --target native

# 运行并更新快照（如果行为变更）
moon test --target native --update

# 运行特定测试（如果支持）
moon test --target native --filter "test_name"
```

### 常用命令

```bash
# 更新接口文件
moon info

# 格式化代码
moon fmt

# 静态检查
moon check

# 查看覆盖率
moon coverage analyze > uncovered.log
```

### 目标说明

- **推荐使用 `--target native`**：上游 `moonbitlang/async` 内部使用 C FFI，`wasm-gc` 目前不支持
- **如需 WASM/JS 目标**：请按需替换依赖或等待上游支持

## 📖 学习路径

### 初学者路径

1. **第一步**：阅读本 README，了解项目结构
2. **第二步**：运行测试，查看示例输出：`moon test --target native`
3. **第三步**：从入门示例（1-8）开始，逐个阅读代码和注释
4. **第四步**：阅读 `docs/best_practices.mbt.md` 了解设计理念
5. **第五步**：尝试在自己的项目中应用这些模式

### 进阶路径

1. **深入理解**：阅读高级示例（9-25），理解复杂场景
2. **最佳实践**：阅读 `docs/best_practices.mbt.md` 中的详细说明
3. **业务应用**：参考 `demo_business_checkout_flow` 学习如何组合使用
4. **源码学习**：查看上游 `moonbitlang/async` 的源码实现

### AI 代码助手使用

如果你使用 AI 代码助手（如 Cursor、Claude Code、GitHub Copilot 等）：

1. **参考 AGENTS.md**：本仓库包含 `AGENTS.md` 文件，帮助 AI 理解项目结构
2. **引用示例**：在提示中引用具体的示例函数名，AI 可以快速理解你的需求
3. **阅读文档注释**：每个函数都有详细的文档注释，AI 可以从中学习最佳实践

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

## 📚 进一步阅读

### 项目内文档

- **`src/Async_best_practices.mbt`**：所有示例的实现代码，学习紧凑的惯用写法
- **`src/Async_best_practices_test.mbt`**：测试用例，了解如何验证异步代码
- **`docs/best_practices.mbt.md`**：系统化的最佳实践指南，包含设计理念和详细说明
- **`AGENTS.md`**：AI 代码助手指南，帮助 AI 理解项目结构和使用方式

### 外部资源

- **MoonBit 官方文档**：[https://docs.moonbitlang.com](https://docs.moonbitlang.com)
- **Async 库源码**：参考上游 `.mooncakes/moonbitlang/async/` 中更高级的 IO/HTTP/进程控制示例
- **MoonBit 社区**：参与 MoonBit 社区讨论，获取更多帮助

## 🤝 贡献

欢迎贡献！如果你有：

- 新的示例或最佳实践
- 文档改进建议
- Bug 报告或修复

请提交 Issue 或 Pull Request。

## 📄 许可证

本项目采用 Apache-2.0 许可证，详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- 感谢 `moonbitlang/async` 库的开发者
- 参考了 [moonbitlang/system-prompt](https://github.com/moonbitlang/system-prompt) 的文档风格