## examples/retry_timeout — 超时与重试策略

> **推荐阅读顺序：第 3 个**（理解策略封装）

---

## 核心知识点

- ✅ **统一超时封装**：所有外部调用都通过 `infra` 设置超时
- ✅ **重试策略**：区分瞬态失败（可重试）与逻辑错误（不可重试）
- ✅ **错误归一化**：返回 `Result[X, String]`，业务层统一处理

---

## 快速运行

```bash
cd examples/retry_timeout
moon test --target native
```

---

## 关键代码

### 场景 1：操作成功

```moonbit
pub async fn demo_retry_timeout_success() -> String {
  let result = @infra.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(100)  // 模拟操作耗时 100ms
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

### 场景 2：操作超时

```moonbit
pub async fn demo_retry_timeout_fail() -> String {
  let result = @infra.call_with_timeout_and_retry(
    50,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(200)  // 操作耗时 200ms，超时 50ms
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

### 场景 3：瞬态失败后重试成功

```moonbit
pub async fn demo_retry_timeout_transient_success() -> String {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      attempts = attempts + 1
      if attempts < 3 {
        raise Failure("Transient error")  // 前 2 次失败
      }
      "Operation successful after retry"  // 第 3 次成功
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**要点**：
- 超时保护避免无界等待
- 重试只用于瞬态错误（网络抖动、服务过载）
- 逻辑错误（参数错误、权限错误）不应该重试

---

## 学到了什么？

1. **策略统一**：超时/重试策略在 `infra/` 层统一封装
2. **错误区分**：明确区分瞬态错误（可重试）与逻辑错误（不可重试）
3. **测试覆盖**：覆盖成功/超时/瞬态失败三种场景

---

## 下一步

- 查看 [`infra/README.md`](../../infra/README.md) 了解 infra 层实现
- 继续学习 [`examples/semaphore_limiter`](../semaphore_limiter/README.md)（并发限流）
- 参考 [`docs/faq.md`](../../docs/faq.md) 了解超时/重试常见问题
