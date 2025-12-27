## 主教学包（src/）导览

`src/` 目录提供“功能目录式”的 Async 示例：用一份相对集中的代码，覆盖更多 API 与组合模式，并用大量 `async test` 做可运行验证。

### 建议用法

- **想快速上手业务写法**：优先看 `examples/` + `infra/`
- **想系统学习 Async API**：按 `src/Async_best_practices.mbt` 的示例章节顺序阅读，并运行测试对照输出

### 你能在这里学到什么（按主题）

- **超时**：`with_timeout` / `with_timeout_opt` 与取消传播的关系
- **结构化并发**：`with_task_group` + `spawn/spawn_bg` 的生命周期管理
- **重试**：固定延迟与指数退避
- **限流**：Semaphore 的阻塞 acquire 与非阻塞 try_acquire
- **队列/流水线**：aqueue 的 producer/consumer 组合
- **取消与关键区**：`protect_from_cancel` 的正确使用边界

### 运行

本仓库建议只跑 native：

```bash
moon test --target native
```


