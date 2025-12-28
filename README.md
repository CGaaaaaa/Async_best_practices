# MoonBit Async 最佳实践示例库

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Moon](https://img.shields.io/badge/moon-latest-orange)](https://www.moonbitlang.com/)

> **Learn MoonBit Async by running examples** — 通过运行示例学习 MoonBit 异步编程

## 📖 项目简介

这是一个**生产级的 MoonBit Async 最佳实践示例库**，旨在帮助开发者和 AI 快速掌握 `moonbitlang/async` 的高效用法。

### 为什么需要这个仓库？

异步编程容易陷入以下问题：
- ❌ 超时/重试逻辑散落在业务代码各处，难以统一治理
- ❌ 缺乏结构化并发（野生 spawn），取消传播失效
- ❌ 没有限流导致资源耗尽（DB 连接、API 调用）
- ❌ 队列使用不当导致内存泄漏或背压失效

**本仓库提供**：
- ✅ **策略收口模式**：`src/` 中提供超时/重试封装示例
- ✅ **可运行示例**：`examples/` 从最小闭环到复杂场景，全部可测试
- ✅ **系统化教材**：`src/` 覆盖所有 Async API，配套 33+ 测试
- ✅ **最佳实践文档**：`docs/` 提供原则、反模式对比、PR 检查清单

## 🚀 快速开始

### 环境要求

- **MoonBit 工具链**：`moon` CLI（[安装指南](https://www.moonbitlang.com/docs/start)）
- **推荐 Backend**：`--target native`（`wasm-gc` 因 `extern "C"` 暂不支持）

### 5 分钟上手

```bash
# 克隆仓库
git clone https://github.com/CGaaaaaa/Async_best_practices.git
cd Async_best_practices

# 运行类型检查
moon check --target native

# 运行所有测试（33+ async tests）
moon test --target native

# 查看最小业务示例
cd examples/checkout
moon test --target native
# 或查看所有示例说明
cat examples/README.md
```

### 10 分钟理解核心思想

阅读 [`examples/README.md`](examples/README.md) 中的 checkout 示例，理解：
1. **业务层**只处理 `Result`，不关心"怎么调用"
2. **策略收口层**统一封装超时/重试策略（在 `src/` 中）
3. 用 `inspect` 做快照测试，验证业务逻辑

```moonbit
// 业务层代码（简洁、可测试）
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  for id in order_ids {
    match @src.call_payment_with_retry(id) {  // 策略收口层封装
      Ok(_) => log("order {id} success")
      Err(e) => log("order {id} failed: {e}")
    }
  }
}
```

## 📂 仓库结构

```
Async_best_practices/
├── README.md                    # 本文件（GitHub 首页）
├── docs/
│   ├── best_practices.md        # 最佳实践（原则/反模式/检查清单）
│   ├── quick-reference.md       # 🆕 快速参考（API 速查表）
│   └── faq.md                   # 🆕 常见问题（FAQ）
├── examples/                    # 可运行的业务示例（从简单到复杂）
│   ├── checkout/                # 最小业务闭环
│   ├── task_group/              # 结构化并发与取消传播
│   ├── retry_timeout/           # 统一超时/重试
│   ├── semaphore_limiter/       # 限流与并发控制
│   ├── pipeline_queue/          # 生产者-消费者流水线
│   └── api-gateway/             # 🆕 综合真实案例（API 网关）
└── src/                         # 主教学包（系统化 API 示例 + 42 测试）
    ├── README.md
    ├── Async_best_practices.mbt
    └── Async_best_practices_test.mbt
```

### 各部分详细说明

| 目录/文件 | 作用 | 适用场景 |
|-----------|------|----------|
| **`docs/best_practices.md`** | 核心原则与反模式对比 | 代码审查、架构设计 |
| 🆕 **`docs/quick-reference.md`** | API 速查表 | 快速查阅常用 API 和模式 |
| 🆕 **`docs/faq.md`** | 常见问题（28 个） | 遇到问题时快速找答案 |
| **`src/`** | 策略收口层示例 | 包含 `call_with_timeout_and_retry` 等封装函数 |
| **`examples/`** | 6 个渐进式示例 | 从零开始学习 Async |
| **`src/`** | 完整 API 目录（42 测试） | 快速查找某个 API 的用法 |

## 🎯 学习路径

### 核心概念

1. **业务与 infra 分层**：查看 [`examples/README.md`](examples/README.md) 中的 checkout 示例
2. **结构化并发**：查看 [`examples/README.md`](examples/README.md) 中的 task_group 示例
3. **超时与重试**：查看 [`examples/README.md`](examples/README.md) 中的 retry_timeout 示例

### 并发控制

1. **限流**：查看 [`examples/README.md`](examples/README.md) 中的 semaphore_limiter 示例
2. **队列与流水线**：查看 [`examples/README.md`](examples/README.md) 中的 pipeline_queue 示例

### 综合应用

1. **生产级案例**：查看 [`examples/README.md`](examples/README.md) 中的 api-gateway 示例
2. **API 参考**：运行 `moon test --target native src/` 查看所有 API 示例
3. **最佳实践**：阅读 [`docs/best_practices.md`](docs/best_practices.md) 了解完整原则
4. **快速查阅**：需要查找 API 时使用 [`docs/quick-reference.md`](docs/quick-reference.md)
5. **常见问题**：遇到问题时查阅 [`docs/faq.md`](docs/faq.md)

## 💡 核心设计思想

### 1. 策略收口模式

**问题**：业务代码散落大量 `@async.with_timeout_opt(500, ...)`，难以统一调参、难以审查

**方案**：
```moonbit
// infra/clients.mbt
pub async fn call_with_timeout_and_retry(
  timeout_ms : Int,
  op : () -> X
) -> Result[X, String] {
  @async.with_timeout_opt(timeout_ms, fn() {
    @async.retry(ExponentialDelay(...), op)
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}

// 业务层只需调用
let result = @src.call_with_timeout_and_retry(500, fn() { ... })
```

### 2. 结构化并发（Structured Concurrency）

**问题**：野生 `spawn` 导致任务失控，取消信号无法传播

**方案**：
```moonbit
@async.with_task_group(fn(group) {
  let task1 = group.spawn(fn() { ... })
  let task2 = group.spawn(fn() { ... })
  // task1/task2 失败会自动取消对方
  task1.wait() + task2.wait()
})
```

### 3. 有限并发与背压

**问题**：无限并发导致 DB 连接耗尽、内存爆炸

**方案**：
```moonbit
let sem = @semaphore.Semaphore::new(10)  // 最大 10 并发
sem.acquire()
// ... 关键区操作
sem.release()
```

## 📋 示例索引

| 示例 | 核心知识点 | 测试覆盖 | 推荐阅读顺序 |
|------|-----------|---------|-------------|
| [checkout](examples/README.md#1-checkout---最小业务闭环) | 业务与 infra 分层 | 快照测试 | 1️⃣ |
| [task_group](examples/README.md#2-task_group---结构化并发) | 结构化并发、fail-fast | 取消传播 | 2️⃣ |
| [retry_timeout](examples/README.md#3-retry_timeout---超时与重试) | 超时/重试策略 | 成功/超时/瞬态失败 | 3️⃣ |
| [semaphore_limiter](examples/README.md#4-semaphore_limiter---并发限流) | 并发限流 | 最大并发观测 | 4️⃣ |
| [pipeline_queue](examples/README.md#5-pipeline_queue---生产者-消费者) | 生产者-消费者 | 并行消费+汇总 | 5️⃣ |
| [api-gateway](examples/README.md#6-api-gateway---综合真实案例) | **生产级API网关** | 路由/限流/重试/健康检查 | 6️⃣ 综合 |

## 🧪 测试策略

本仓库所有示例都配套 `async test`（**42 个测试，100% 通过**）：

```bash
# 运行所有测试
moon test --target native

# 运行单个包的测试
moon test --target native src/
moon test --target native examples/checkout/
moon test --target native examples/api-gateway/
# 查看所有示例说明
cat examples/README.md
```

**最新测试结果**：✅ Total tests: 42, passed: 42, failed: 0

### 测试覆盖的场景

- ✅ **正常流程**：操作成功
- ✅ **超时场景**：操作超时返回错误
- ✅ **瞬态失败**：重试后成功
- ✅ **取消传播**：父任务取消时子任务也取消
- ✅ **并发限制**：最大并发数不超过限制

## 🤖 给 AI Agent 的使用说明

如果你是 AI Agent，建议：

1. **学习阶段**：
   - 优先阅读 `docs/best_practices.mbt.md`
   - 按顺序运行 `examples/` 的 5 个示例
   - 查阅 `src/Async_best_practices.mbt` 作为 API 手册

2. **写业务代码时**：
   - 复用 `src/Async_best_practices.mbt` 中的封装模式
   - 使用 `TaskGroup` 管理并发任务
   - 参考 `examples/` 的组合方式

3. **代码审查时**：
   - 对照 `docs/best_practices.md` 的 PR 检查清单
   - 确保外部调用都有超时+重试
   - 确保并发任务都在 TaskGroup 内
   - 🆕 快速查阅：[`docs/quick-reference.md`](docs/quick-reference.md)

## 🔧 如何在你的项目中使用

### 方式 1：复制策略收口层代码

```bash
# 从 src/Async_best_practices.mbt 中复制以下函数到你的项目：
# - call_with_timeout_and_retry
# - call_payment_with_retry（或改为你的业务函数）

# 在你的 moon.pkg.json 中引入
{
  "import": ["CGaaaaaa/async-best-practices/src"]
}
```

### 方式 2：作为依赖引入（如果发布到 Mooncakes）

```json
{
  "import": [
    "CGaaaaaa/async-best-practices/infra",
    "CGaaaaaa/async-best-practices/src"
  ]
}
```

## 📚 延伸阅读

- [MoonBit Async 官方文档](https://docs.moonbitlang.com/async)
- [Structured Concurrency 论文](https://en.wikipedia.org/wiki/Structured_concurrency)
- [moonbitlang/async 源码](https://github.com/moonbitlang/async)

## 🤝 贡献指南

欢迎提交：
- 🐛 Bug 修复
- 📝 文档改进
- 💡 新的示例场景
- 🧪 测试补充

提交 PR 前请确保：
```bash
moon check --target native
moon test --target native
moon fmt  # 格式化代码
```

## 📄 许可证

本项目采用 [Apache 2.0 许可证](LICENSE)。

## ⭐ Star History

如果这个项目对你有帮助，请给一个 Star ⭐️

---

**Made with ❤️ by MoonBit Community**

