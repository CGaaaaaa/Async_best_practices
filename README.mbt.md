## MoonBit Async — 最佳实践示例库（可直接跑、可直接学）

为了推广 `moonbitlang/async` 的使用，我们提供一个 **“拿来就能学会”** 的示例仓库：
- **示例驱动**：每个关键模式在 `examples/` 中都有可运行代码 + 测试
- **工程化模板**：把“超时/重试/错误归一化”等策略收口到 `infra/`
- **最佳实践正文**：`docs/best_practices.mbt.md` 给出原则、反模式与 PR 检查清单
- **系统化教学包**：`src/` 提供覆盖更全的“功能目录式”示例与大量测试（作为主教材）

### 快速开始（建议只跑 Native）

`moonbitlang/async` 当前包含部分 `extern "C"` 能力，因此 **wasm-gc backend 会失败**。本仓库建议使用 native：

```bash
moon check --target native
moon test --target native
```

### Repo 导航（先看哪里）

- `docs/best_practices.mbt.md`: Async 最佳实践（原则/反模式/检查清单）
- `src/`: 主教学包（“功能目录式”示例 + 测试），适合系统学习与查阅
- `infra/`: “策略收口层”示例（超时 + 重试 + 错误归一化）
- `examples/`: 可运行的业务组合示例（从最小闭环到进阶模式）

### 学习路径（10 分钟 → 1 小时）

- **10 分钟**：跑通 `examples/checkout`，看懂“业务层只处理 Result，策略在 infra 统一”
- **30 分钟**：跑通 `examples/task_group` / `examples/retry_timeout`，再浏览 `src/Async_best_practices.mbt` 的对应章节（更系统）
- **60 分钟**：按 `docs/best_practices.mbt.md` 的 checklist，把你项目的异步调用收口到 infra

### Examples 索引（建议按顺序）

- `examples/checkout`: 最小业务闭环（业务层调用 `@infra` wrapper + snapshot/inspect 测试）
- `examples/task_group`: TaskGroup 结构化并发（spawn/wait）与 fail-fast 取消传播
- `examples/retry_timeout`: “统一超时 + 重试 wrapper”的成功/超时用例
- `examples/semaphore_limiter`: Semaphore 限流（观测最大并发 <= limit）
- `examples/pipeline_queue`: aqueue 生产者-消费者流水线（并行消费、汇总结果）

### src/ 教学包是什么？什么时候看它？

`src/` 是“更全的示例目录”：覆盖 `with_timeout(_opt)`、TaskGroup、retry、Semaphore、Queue、取消传播等更多模式，并且配套了大量 `async test`。

如果你想把它当作依赖引入到自己的项目里，通常做法是在你的 `moon.pkg.json` 里增加包依赖：
- `CGaaaaaa/async-best-practices/src`（默认别名通常为 `@src`）
- `CGaaaaaa/async-best-practices/infra`（默认别名通常为 `@infra`）

### 给 AI 的使用方式（学习用）

- 把本仓库当作“参考实现”：优先阅读 `docs/best_practices.mbt.md`
- 写业务时：优先复用 `infra/` 的封装方式，再按 examples 组织并发结构
