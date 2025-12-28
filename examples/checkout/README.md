## examples/checkout — 最小业务闭环示例

> **推荐阅读顺序：第 1 个**（10 分钟上手）

---

## 核心知识点

- ✅ **业务与 infra 分层**：业务代码只处理 `Result`，策略在 `infra` 统一
- ✅ **快照测试**：用 `inspect` 验证完整输出
- ✅ **错误处理**：展示成功/失败两种路径

---

## 快速运行

```bash
cd examples/checkout
moon test --target native
```

---

## 关键代码

### 业务层（checkout.mbt）

```moonbit
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  for id in order_ids {
    log.write_string("start order \{id}\n")
    
    // ✅ 业务层只调用 infra wrapper，不关心超时/重试细节
    let outcome = @infra.call_payment_with_retry(id)
    
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  log.to_string()
}
```

**要点**：业务代码只表达"处理订单列表，记录结果"，超时/重试策略都在 `infra/clients.mbt` 中。

### 测试（checkout_test.mbt）

```moonbit
async test "checkout_orders_flow" {
  let out = checkout_orders([101, 102])
  inspect(
    out,
    content=(
      #|start order 101
      #|order 101 success
      #|start order 102
      #|order 102 success
      #|
    ),
  )
}
```

**要点**：用 `inspect` 做快照测试，验证完整输出。

---

## 学到了什么？

1. **职责分离**：业务层不关心"怎么调用"，只处理 `Result`
2. **策略统一**：超时/重试策略在 `infra/` 层统一封装
3. **测试简单**：快照测试一眼看懂预期行为

---

## 下一步

- 查看 [`infra/README.md`](../../infra/README.md) 了解 infra 层设计
- 继续学习 [`examples/task_group`](../task_group/README.md)（结构化并发）
- 参考 [`docs/best_practices.md`](../../docs/best_practices.md) 了解完整原则
