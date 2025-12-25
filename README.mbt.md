# MoonBit Async — System式示例与最佳实践仓库

本仓库以“示例驱动 + 系统式文档”为核心，推广 `moonbitlang/async` 在真实业务中的正确用法与工程化实践。
目标：让程序员或 AI 在引入本库后，能立即上手并按最佳实践构建可靠的异步业务逻辑。

为什么采用 System 式 README？
- 借鉴 `moonbitlang/system-prompt` 的风格，README.mbt.md 同时为“人类开发者”和“AI/代理”提供清晰、结构化的上下文与可复用模板，便于自动化工具直接读取并执行建议。

核心承诺
- 提供可复制的基础设施模板（超时+重试、限流、队列）；
- 展示结构化并发与取消传播的正确使用方式（TaskGroup）；
- 提供 PR/审查清单与 CI 建议，确保「绿色勾」的持续质量信号。

重要说明
- 应你要求，本仓库已移除原来的 `docs/` 与 `src/` 中的示例实现文件（代码历史仍在 git 历史中可回溯）。当前我们把关键示例与最佳实践直接保存在 README.mbt.md 中，便于 AI/代理直接引用；如需我可把精选模板提取回 `infra/` 并添加可运行测试。

----------------------------------------

如何快速使用本仓库（程序员 / AI）

1) 阅读“核心原则”与“审查清单”，确保项目默认保护措施到位。  
2) 把 `call_with_timeout_and_retry` 等基础设施拷贝到你的 infra 包，替换具体的客户端实现。  
3) 在 handler/业务入口使用 TaskGroup 管理并发调用。  
4) 在 CI 中运行 `moon check` 与 `moon test --target native`（或至少 `moon check`）确保行为可回归。

----------------------------------------

核心原则（简短、必须遵守）

- 对所有外部依赖（网络/DB/第三方）统一使用超时 + 重试封装；  
- 以结构化并发（TaskGroup）管理任务生命周期，禁止创建“野生”顶层任务；  
- 使用信号量限制关键资源并发（数据库连接、并发外部请求）；  
- 非关键后台任务用 `spawn_bg(no_wait=true)` 或 `allow_failure=true`，并注册组级清理（defer/add_defer）。

----------------------------------------

可复制基础设施模板（直接拷贝到 `infra/clients.mbt`）

1) 外部调用统一封装：超时 + 指数退避

```moonbit no-check
/// infra/clients.mbt
pub async fn call_with_timeout_and_retry[T](timeout_ms : Int, op : () -> T) -> Result[T, String] {
  @async.with_timeout_opt(timeout_ms, fn() {
    @async.retry(ExponentialDelay(initial=100, factor=2, maximum=1000), fn() {
      op()
    })
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}
```

说明：把所有对外调用（HTTP/DB/third-party）都通过该 wrapper，以便统一监控、打点与审查。

2) 请求处理/组合调用模板（在 handler 中使用 TaskGroup）

```moonbit no-check
pub async fn handle_order(order_id : Int) -> String {
  @async.with_task_group(fn(root) {
    let db_task = root.spawn(fn() { call_with_timeout_and_retry(500, fn() { query_order(order_id) }) })
    let pay_task = root.spawn(fn() { call_with_timeout_and_retry(1000, fn() { call_payment_gateway(order_id) }) })
    let db_res = db_task.wait()
    let pay_res = pay_task.wait()
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

4) 队列/流水线（生产者-消费者）

```moonbit no-check
let q = @aqueue.Queue::new()
root.spawn_bg(fn() { for item in items { q.put(item) } })
root.spawn_bg(fn() { for _ in 0..<items_count { let v = q.get(); process(v) } })
```

----------------------------------------

业务综合示例（模板）：下单 + 支付（简化伪码）

```moonbit no-check
pub async fn demo_business_checkout_flow(order_ids : Array[Int]) -> String {
  for id in order_ids {
    let outcome = call_with_timeout_and_retry(500, fn() { process_payment(id) })
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  "done"
}
```

说明：业务层只处理结果，所有重试/超时由 infra 层统一控制。

----------------------------------------

测试策略与 CI 建议（确保绿色勾）

- 为每个 infra wrapper 写单元与集成测试（模拟超时、失败、退避成功路径）；  
- 使用 snapshot 测试（`inspect`）验证重要时间线与日志输出；  
- CI 建议：GitHub Actions on push/PR 执行 `moon info`, `moon check`, `moon test --target native`（如环境有限，先运行 `moon check`）；  
- PR 模板应包含审查要点：超时/重试是否存在？任务是否在 TaskGroup 内？是否有信号量/限流？

----------------------------------------

AI / 代理 使用说明（system-prompt 风格）

- 最直接的方法：在提示中引用 `README.mbt.md` 或直接引用模板函数名（如 `call_with_timeout_and_retry`、`handle_order`）；  
- 建议 AI 在修改时优先调整 infra 层，确保全局行为一致；任何 infra 修改必须伴随测试更新。  
- 在自动化迁移/重构场景，先在分支上运行 `moon test --target native --update`，并人工审阅 snapshot diff。

----------------------------------------

仓库现状与后续计划

- 当前 README.mbt.md 为系统式文档与教学模板中心；如需我可：  
  - 将上述模板抽出到 `infra/` 并添加示例实现与测试；  
  - 恢复或新增精选 `src/` 示例（每个示例配套测试与快照）；  
  - 添加 GitHub Actions CI workflow 并调试至绿色（需配置 runner 环境）。

----------------------------------------

贡献与发布

- 若准备发布到 Mooncakes，设置 `moon.mod.json` 的 `name` 与 `repository`，并在发布前确保 tests 与 snapshots 通过；  
- 欢迎 PR / Issue：新增示例、优化模板、补充测试与 CI 配置。

----------------------------------------

致谢  
- 感谢 `moonbitlang/async` 的开发者；本 README 风格参考 `moonbitlang/system-prompt`（https://github.com/moonbitlang/system-prompt）。


