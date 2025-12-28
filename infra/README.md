## infra/ — 策略收口层（Policy Enforcement Layer）

> 本目录提供**可直接复制的模板**：把异步调用的超时/重试/限流策略统一封装，供业务层调用。

---

## 设计思想

### 为什么需要 infra 层？

在真实业务中，异步调用的常见问题：

| 问题 | 症状 | 后果 |
|------|------|------|
| **策略散落** | 每个业务文件都写自己的超时/重试逻辑 | 难以统一调参、代码审查困难 |
| **参数不一致** | A 文件超时 500ms，B 文件超时 300ms | 无法统一治理（例如"所有第三方调用改为 3 秒"） |
| **测试困难** | 业务代码耦合了 `@async.with_timeout_opt` | 测试时需要真实 sleep，难以 mock |

### infra 层的职责

```
┌─────────────────────────────────────────┐
│  业务层 (examples/checkout.mbt)          │
│                                         │
│  @infra.call_payment_with_retry(101)   │  ← 只调用 wrapper
│  match result {                         │
│    Ok(v) => ...                         │
│    Err(e) => ...                        │
│  }                                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  策略收口层 (infra/clients.mbt)          │
│                                         │
│  call_with_timeout_and_retry(...)      │  ← 统一超时/重试策略
│  └─> @async.with_timeout_opt(500, ...) │
│  └─> @async.retry(ExponentialDelay)    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  底层 Async 库 (moonbitlang/async)       │
└─────────────────────────────────────────┘
```

**核心价值**：
1. **策略集中**：所有超时/重试参数都在 `infra/`，一处修改全局生效
2. **业务简洁**：业务代码只处理 `Result[X, String]`，不关心策略细节
3. **易于测试**：业务层测试时 mock `infra`，不需要真实 sleep

---

## 文件结构

```
infra/
├── README.md              # 本文档
├── clients.mbt           # 通用 wrapper 实现
├── clients_test.mbt      # 超时/重试测试用例
└── moon.pkg.json         # 包配置
```

---

## 核心 API

### 1. `call_with_timeout_and_retry`

**签名**：
```moonbit
pub async fn[X] call_with_timeout_and_retry(
  timeout_ms : Int,
  op : () -> X
) -> Result[X, String]
```

**功能**：统一封装"超时 + 重试"策略

**实现**：
```moonbit
pub async fn[X] call_with_timeout_and_retry(timeout_ms : Int, op : () -> X) -> Result[X, String] {
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

**使用示例**：
```moonbit
// infra/clients.mbt
pub async fn call_payment_api(order_id : Int) -> Result[String, String] {
  call_with_timeout_and_retry(3000, fn() {  // 3 秒超时
    http_post("/api/pay", order_id)  // 真实 HTTP 调用
  })
}

// 业务层
let result = @infra.call_payment_api(101)
match result {
  Ok(txn_id) => log("success")
  Err(e) => log("failed: {e}")
}
```

**参数说明**：
- `timeout_ms`：超时时间（毫秒），超时返回 `Err("timeout")`
- `op`：要执行的操作（thunk）

**重试策略**：
- 指数退避：100ms → 200ms → 400ms → 800ms → 1000ms（上限）
- 适用场景：外部服务瞬态失败（网络抖动、服务过载）

---

### 2. `call_payment_with_retry`

**签名**：
```moonbit
pub async fn call_payment_with_retry(order_id : Int) -> Result[String, String]
```

**功能**：模拟支付网关调用（教学用）

**实现**：
```moonbit
pub async fn call_payment_with_retry(order_id : Int) -> Result[String, String] {
  let mut attempt = 0
  call_with_timeout_and_retry(500, fn() {
    attempt = attempt + 1
    // 模拟瞬态失败：order_id==101 第2次成功；order_id==102 第3次成功
    if order_id == 101 && attempt < 2 {
      raise Failure("transient")
    }
    if order_id == 102 && attempt < 3 {
      raise Failure("transient")
    }
    "ok"
  })
}
```

**使用示例**：
```moonbit
async test "call_payment_with_retry_examples" {
  // order 101: 第 2 次尝试成功
  let r1 = @infra.call_payment_with_retry(101)
  inspect(r1, content=(#|Ok("ok")|))

  // order 102: 第 3 次尝试成功
  let r2 = @infra.call_payment_with_retry(102)
  inspect(r2, content=(#|Ok("ok")|))
}
```

**注意**：
- 这是教学示例，用计数器模拟瞬态失败
- 真实项目应替换为真实 HTTP/DB 调用

---

## 如何在你的项目中使用

### 步骤 1：复制 `infra/` 到你的项目

```bash
cp -r infra/ your-project/infra/
```

### 步骤 2：修改 `clients.mbt`

把 mock 实现替换为真实调用：

```moonbit
// 示例：封装支付 API
pub async fn call_payment_api(order_id : Int, amount : Int) -> Result[String, String] {
  call_with_timeout_and_retry(3000, fn() {
    // 替换为真实 HTTP 调用
    let resp = http_post(
      "https://payment-gateway.com/api/charge",
      json!{ "order_id": order_id, "amount": amount }
    )
    parse_response(resp)
  })
}

// 示例：封装 DB 查询
pub async fn query_user_by_id(uid : Int) -> Result[User, String] {
  call_with_timeout_and_retry(1000, fn() {
    // 替换为真实 DB 调用
    db_query("SELECT * FROM users WHERE id = ?", [uid])
  })
}
```

### 步骤 3：业务层引入 `infra`

在 `moon.pkg.json` 中添加：

```json
{
  "import": [
    "your-username/your-project/infra"
  ]
}
```

业务代码调用：

```moonbit
async fn checkout_order(order_id : Int) -> Result[String, String] {
  @infra.call_payment_api(order_id, 9999)  // 业务层只调用 wrapper
}
```

---

## 策略参数调整指南

### 超时时间（timeout_ms）

| 依赖类型 | 推荐超时 | 理由 |
|---------|---------|------|
| **内部 RPC** | 500ms - 1s | 同机房延迟低 |
| **第三方 API** | 3s - 5s | 网络不稳定 |
| **DB 查询** | 1s - 2s | 慢查询可能阻塞 |
| **文件上传** | 10s - 30s | 大文件传输慢 |

### 重试策略

#### 固定延迟（适用于快速重试）

```moonbit
@async.retry(FixedDelay(delay=100, max_retry=3), fn() { ... })
```

- **适用场景**：网络抖动、瞬态失败
- **不适用**：服务过载（需要给对方恢复时间）

#### 指数退避（适用于服务过载）

```moonbit
@async.retry(ExponentialDelay(initial=100, factor=2, maximum=2000), fn() { ... })
```

- **重试时序**：100ms → 200ms → 400ms → 800ms → 1600ms → 2000ms
- **适用场景**：外部服务过载、rate limit

### 什么错误不应该重试

```moonbit
async fn should_not_retry(id : Int) -> Result[X, String] {
  call_api(id) catch {
    // ❌ 不要重试这些错误
    "permission_denied" => Err("no permission")
    "invalid_param" => Err("bad request")
    "not_found" => Err("resource not found")
    
    // ✅ 只重试这些错误
    "network_error" => retry_call_api(id)
    "timeout" => retry_call_api(id)
    "503" => retry_call_api(id)  // Service Unavailable
  }
}
```

---

## 测试策略

### 测试覆盖的场景

| 场景 | 测试方法 | 示例 |
|------|---------|------|
| **成功** | 模拟立即成功 | `call_payment_with_retry(101)` |
| **瞬态失败** | 模拟重试后成功 | order 101（第 2 次成功）、order 102（第 3 次成功） |
| **超时** | 模拟慢操作 | `@async.sleep(200)` 超过超时时间 |

### 示例：测试超时

```moonbit
async test "timeout_returns_err" {
  let result = @infra.call_with_timeout_and_retry(50, fn() {
    @async.sleep(200)  // 操作耗时 200ms，超时 50ms
    "ok"
  })
  
  inspect(result, content=(#|Err("timeout")|))
}
```

### 示例：测试重试

```moonbit
async test "retry_then_success" {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(1000, fn() {
    attempts = attempts + 1
    if attempts < 3 {
      raise Failure("transient")
    }
    "ok"
  })
  
  inspect(result, content=(#|Ok("ok")|))
  assert_eq!(attempts, 3)
}
```

---

## 常见问题

### Q1：为什么用 `Result[X, String]` 而不是 `Option` 或 `raise`？

**A**：
- `Result`：明确区分成功/失败，错误信息可传递
- `Option`：无法传递错误原因（例如"超时" vs "网络错误"）
- `raise`：会中断整个调用链（不适合部分失败场景）

### Q2：为什么 `call_with_timeout_and_retry` 用泛型 `[X]`？

**A**：支持任意返回类型，例如：
```moonbit
call_with_timeout_and_retry(1000, fn() { 42 })           // Result[Int, String]
call_with_timeout_and_retry(1000, fn() { "hello" })      // Result[String, String]
call_with_timeout_and_retry(1000, fn() { User{...} })    // Result[User, String]
```

### Q3：如何调整重试策略？

**A**：修改 `call_with_timeout_and_retry` 的实现：

```moonbit
// 改为固定延迟
@async.retry(FixedDelay(delay=200, max_retry=5), op)

// 改为更激进的指数退避
@async.retry(ExponentialDelay(initial=50, factor=3, maximum=5000), op)
```

### Q4：如何添加观测（日志/监控）？

**A**：在 wrapper 中加入埋点：

```moonbit
pub async fn call_with_timeout_and_retry[X](timeout_ms : Int, op : () -> X) -> Result[X, String] {
  let start_time = now()
  let result = @async.with_timeout_opt(timeout_ms, fn() {
    @async.retry(ExponentialDelay(...), op)
  }) match {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
  let duration = now() - start_time
  log_metrics("infra.call_duration", duration)  // 打点
  result
}
```

---

## 下一步

1. **运行测试**：`moon test --target native infra/`
2. **复制到你的项目**：`cp -r infra/ your-project/`
3. **改造业务代码**：把外部调用封装为 `@infra.call_xxx`
4. **补充测试**：用 `inspect` 验证业务逻辑

---

**设计原则**：
- ✅ 策略集中，易于调整
- ✅ 业务简洁，易于测试
- ✅ 可观测，易于调试

Happy Coding! 🚀

