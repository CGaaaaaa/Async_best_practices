## examples/retry_timeout — 超时与重试策略

> **推荐阅读顺序：第 3 个**（理解策略封装）

---

## 核心知识点

- ✅ **统一超时封装**：所有外部调用都通过 `infra` 设置超时
- ✅ **重试策略**：区分瞬态失败（可重试）与逻辑错误（不可重试）
- ✅ **错误归一化**：返回 `Result[X, String]`，业务层统一处理

---

## 场景说明

这个示例展示：
1. 操作成功时的正常流程
2. 操作超时时的错误处理
3. 瞬态失败后重试成功的场景

**为什么需要超时？**
- 避免无界等待（例如第三方 API 挂了，永远等不到响应）
- 快速失败，不浪费资源

**为什么需要重试？**
- 网络抖动、服务瞬时过载等瞬态错误，重试可以恢复
- 但注意：逻辑错误（参数错误、权限错误）不应该重试

---

## 代码结构

```
examples/retry_timeout/
├── README.mbt.md            # 本文档
├── retry_timeout.mbt        # 超时/重试示例
├── retry_timeout_test.mbt   # 测试用例
└── moon.pkg.json            # 包配置
```

---

## 关键代码解析

### 场景 1：操作成功

```moonbit
pub async fn demo_retry_timeout_success() -> String {
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    @async.sleep(100)  // 模拟操作耗时 100ms
    "Operation successful"
  })
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**测试**：
```moonbit
async test "demo_retry_timeout_success_flow" {
  let out = demo_retry_timeout_success()
  inspect(out, content=(#|Operation successful|))
}
```

**关键点**：
- 操作耗时 100ms，超时 1000ms → 成功
- 返回 `Ok("Operation successful")`

---

### 场景 2：操作超时

```moonbit
pub async fn demo_retry_timeout_fail() -> String {
  let result = @infra.call_with_timeout_and_retry(50, fn() {
    @async.sleep(200)  // 操作耗时 200ms，超时 50ms
    "Operation successful"
  })
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**测试**：
```moonbit
async test "demo_retry_timeout_fail_flow" {
  let out = demo_retry_timeout_fail()
  inspect(out, content=(#|Error: timeout|))
}
```

**关键点**：
- 操作耗时 200ms，超时 50ms → 超时
- 返回 `Err("timeout")`
- 即使有重试，每次重试都会超时（因为操作本身太慢）

---

### 场景 3：瞬态失败后重试成功

```moonbit
pub async fn demo_retry_timeout_transient_success() -> String {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 3 {
      raise Failure("Transient error")  // 前 2 次失败
    }
    "Operation successful after retry"  // 第 3 次成功
  })
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**测试**：
```moonbit
async test "demo_retry_timeout_transient_success_flow" {
  let out = demo_retry_timeout_transient_success()
  inspect(out, content=(#|Operation successful after retry|))
}
```

**关键点**：
- 前 2 次失败（抛出 `Failure`），第 3 次成功
- `@infra.call_with_timeout_and_retry` 使用指数退避重试
- 最终返回 `Ok("Operation successful after retry")`

---

## 重试策略详解

### 指数退避（Exponential Backoff）

`infra/clients.mbt` 使用的重试策略：

```moonbit
@async.retry(ExponentialDelay(initial=100, factor=2, maximum=1000), fn() {
  op()
})
```

**重试时序**：
- 第 1 次失败 → 等待 100ms → 第 2 次尝试
- 第 2 次失败 → 等待 200ms → 第 3 次尝试
- 第 3 次失败 → 等待 400ms → 第 4 次尝试
- ...
- 延迟上限 1000ms

**适用场景**：
- 外部服务过载（需要给对方恢复时间）
- 网络抖动
- DB 连接池满

### 固定延迟（Fixed Delay）

如果需要快速重试：

```moonbit
@async.retry(FixedDelay(delay=100, max_retry=3), fn() {
  op()
})
```

**重试时序**：
- 每次失败后等待 100ms
- 最多重试 3 次

**适用场景**：
- 快速瞬态失败（例如缓存未命中）
- 重试间隔短（< 200ms）

---

## 什么错误不应该重试

```moonbit
async fn should_not_retry_example() -> Result[String, String] {
  call_api() catch {
    // ❌ 不要对这些错误重试
    "permission_denied" => Err("no permission")    // 权限错误
    "invalid_param" => Err("bad request")          // 参数错误
    "not_found" => Err("resource not found")       // 资源不存在
    
    // ✅ 只对这些错误重试
    "network_error" => retry_call_api()            // 网络抖动
    "timeout" => retry_call_api()                  // 超时
    "503" => retry_call_api()                      // 服务暂时不可用
    "429" => retry_call_api()                      // Rate limit（需要退避）
  }
}
```

---

## 运行示例

### 运行测试

```bash
cd examples/retry_timeout
moon test --target native
```

**预期输出**：
```
Finished. moon: no work to do
Total tests: 3, passed: 3, failed: 0.
```

### 修改示例：观察重试行为

尝试修改重试次数：

```moonbit
pub async fn demo_retry_timeout_transient_success() -> String {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 5 {  // 改为前 4 次失败
      raise Failure("Transient error")
    }
    "Operation successful after retry"
  })
  ...
}
```

**观察**：
- 如果重试次数不够（例如只重试 3 次），最终会返回 `Err(...)`
- 可以在 `infra/clients.mbt` 中调整 `max_retry` 参数

---

## 学到了什么？

完成这个示例后，你应该理解：

1. **超时保护**
   - 所有外部调用都应该有超时
   - 超时时返回 `Err("timeout")`，不影响其他任务

2. **重试策略**
   - 指数退避适用于服务过载场景
   - 固定延迟适用于快速瞬态失败
   - 逻辑错误（参数/权限）不应该重试

3. **策略封装**
   - 业务层只调用 `@infra.call_with_timeout_and_retry`
   - 超时/重试参数都在 `infra/` 中统一管理

---

## 下一步

继续学习其他模式：

- **[examples/semaphore_limiter](../semaphore_limiter/)**：并发限流
- **[examples/pipeline_queue](../pipeline_queue/)**：生产者-消费者流水线

---

## 常见问题

### Q1：为什么用 `with_timeout_opt` 而不是 `with_timeout`？

**A**：
- `with_timeout`：超时时抛出 `Failure`，会取消父任务
- `with_timeout_opt`：超时时返回 `None`，不影响父任务

推荐在 infra 层用 `with_timeout_opt`，转为 `Result` 给业务层。

### Q2：如何测试重试次数？

**A**：用计数器验证：

```moonbit
async test "verify_retry_count" {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 3 {
      raise Failure("transient")
    }
    "ok"
  })
  
  assert_eq!(attempts, 3)  // 验证重试了 3 次
}
```

### Q3：如何调整重试参数？

**A**：修改 `infra/clients.mbt` 的 `call_with_timeout_and_retry` 实现：

```moonbit
// 改为固定延迟
@async.retry(FixedDelay(delay=200, max_retry=5), op)

// 改为更激进的指数退避
@async.retry(ExponentialDelay(initial=50, factor=3, maximum=5000), op)
```

---

**掌握超时与重试后，你的服务会更加健壮！** 🚀

