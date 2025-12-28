## examples/api-gateway — 综合真实案例：API 网关

> **推荐阅读顺序：完成其他示例后**（综合应用）

---

## 核心知识点

- ✅ **综合应用**：TaskGroup + Semaphore + 超时 + 重试 + infra 层
- ✅ **真实场景**：API 网关的路由、限流、熔断、健康检查
- ✅ **并发处理**：批量请求并行处理
- ✅ **后台任务**：日志记录不阻塞主流程
- ✅ **统计监控**：请求计数、成功率统计

---

## 场景说明

这是一个**生产级的 API 网关示例**，展示如何综合运用 MoonBit Async 的所有核心模式：

### 功能清单

| 功能 | 实现方式 | Async 模式 |
|------|---------|-----------|
| **路由转发** | 根据路径分发到不同后端 | TaskGroup |
| **并发限流** | 最大并发请求数控制 | Semaphore |
| **超时保护** | 统一请求超时 | with_timeout_opt |
| **重试机制** | 瞬态失败自动重试 | infra 层封装 |
| **日志记录** | 后台异步日志 | spawn_bg |
| **批量处理** | 并行处理多个请求 | TaskGroup + spawn |
| **健康检查** | 成功率统计 | 状态管理 |

---

## 代码结构

```
examples/api-gateway/
├── README.md                # 本文档
├── gateway.mbt              # API 网关实现（约 250 行）
├── gateway_test.mbt         # 测试用例（10 个测试）
└── moon.pkg.json            # 包配置
```

---

## 关键代码解析

### 1. 网关配置与初始化

```moonbit
pub struct GatewayConfig {
  max_concurrent_requests : Int  // 最大并发
  request_timeout_ms : Int       // 请求超时
  enable_retry : Bool            // 是否重试
}

pub struct Gateway {
  config : GatewayConfig
  limiter : @semaphore.Semaphore  // 限流器
  mut total_requests : Int        // 统计
  mut successful_requests : Int
  mut failed_requests : Int
}
```

**设计要点**：
- 配置与状态分离
- 用 Semaphore 实现限流
- 统计数据用于健康检查和监控

---

### 2. 请求处理流程（综合模式）

```moonbit
pub async fn Gateway::handle_request(
  self : Gateway,
  request : Request
) -> Response raise {
  self.total_requests = self.total_requests + 1
  
  // ✅ 模式 1：限流（Semaphore）
  self.limiter.acquire()
  
  // ✅ 模式 2：结构化并发（TaskGroup）
  @async.with_task_group(fn(group) {
    // 主任务：处理请求
    let response_task = group.spawn(fn() {
      self.handle_request_internal(request)
    })
    
    // ✅ 模式 3：后台任务（spawn_bg）
    group.spawn_bg(fn() {
      self.log_request(request)  // 日志不阻塞主流程
    })
    
    // 等待主任务 + 释放资源
    let response = response_task.wait()
    self.limiter.release()
    response
  })
}
```

**综合运用**：
1. **Semaphore 限流**：保护后端服务
2. **TaskGroup 管理**：确保资源释放
3. **spawn_bg 后台任务**：日志不影响性能

---

### 3. 路由 + 超时 + 重试

```moonbit
async fn Gateway::handle_request_internal(
  self : Gateway,
  request : Request
) -> Response raise {
  // ✅ 模式 4：统一超时
  @async.with_timeout_opt(self.config.request_timeout_ms, fn() {
    // ✅ 模式 5：路由分发
    match request.path {
      "/api/users" => self.call_user_service(request)
      "/api/orders" => self.call_order_service(request)
      "/api/products" => self.call_product_service(request)
      "/health" => self.health_check()
      _ => { status: 404, body: "Not Found" }
    }
  }) match {
    Some(response) => response
    None => { status: 504, body: "Gateway Timeout" }
  }
}
```

---

### 4. 后端服务调用（infra 层封装）

```moonbit
async fn Gateway::call_user_service(
  self : Gateway,
  request : Request
) -> Response raise {
  if self.config.enable_retry {
    // ✅ 模式 6：复用 infra 层封装
    @infra.call_with_timeout_and_retry(2000, fn() {
      self.simulate_user_service_call(request)
    }) match {
      Ok(response) => response
      Err(e) => { status: 503, body: "User Service Error: \{e}" }
    }
  } else {
    self.simulate_user_service_call(request)
  }
}
```

**设计要点**：
- 统一使用 `@infra` 层封装
- 错误转为 HTTP 状态码
- 可配置是否启用重试

---

### 5. 批量处理（并发优化）

```moonbit
pub async fn Gateway::handle_batch_requests(
  self : Gateway,
  requests : Array[Request]
) -> Array[Response] raise {
  @async.with_task_group(fn(group) {
    // ✅ 模式 7：并行发起所有请求
    let tasks = Array::new()
    for request in requests {
      tasks.push(group.spawn(fn() {
        self.handle_request(request)
      }))
    }
    
    // 收集所有结果
    let responses = Array::new()
    for task in tasks {
      responses.push(task.wait())
    }
    responses
  })
}
```

**性能优势**：
- 并行发起（受 limiter 限制）
- 批量收集结果
- 自动限流保护

---

## 测试覆盖

| 测试用例 | 验证内容 |
|---------|---------|
| `single_request_success` | 单个请求成功 |
| `route_to_different_services` | 路由到不同后端 |
| `404_for_unknown_path` | 未知路径返回 404 |
| `health_check` | 健康检查端点 |
| `batch_requests_parallel` | 批量并行处理 |
| `concurrent_limit` | 并发数限制生效 |
| `retry_on_transient_failure` | 瞬态失败重试 |
| `gateway_stats` | 统计数据正确 |
| `timeout_protection` | 超时保护生效 |

---

## 运行示例

### 运行测试

```bash
cd examples/api-gateway
moon test --target native
```

**预期输出**：

```
Total tests: 9, passed: 9, failed: 0.
```

---

## 性能调优建议

### 1. 并发数设置

```moonbit
let config = {
  max_concurrent_requests: 100,  // 根据后端能力调整
  request_timeout_ms: 3000,
  enable_retry: true
}
```

**调整依据**：
- 后端服务能力（QPS、延迟）
- 资源限制（内存、连接数）
- 观测 P99 延迟动态调整

---

### 2. 超时时间设置

| 路径 | 推荐超时 | 理由 |
|------|---------|------|
| `/api/users` | 1s | 简单查询 |
| `/api/orders` | 2s | 可能有关联查询 |
| `/api/products` | 500ms | 缓存命中率高 |

---

### 3. 重试策略

**建议**：
- ✅ 用户服务：启用重试（可能网络抖动）
- ✅ 订单服务：启用重试（但需要确保幂等）
- ❌ 商品服务：不重试（假设幂等性问题）

---

## 扩展建议

### 1. 添加熔断器

```moonbit
struct CircuitBreaker {
  mut failure_count : Int
  mut last_failure_time : Int
  threshold : Int
}

fn CircuitBreaker::should_allow_request(self : CircuitBreaker) -> Bool {
  if self.failure_count > self.threshold {
    // 熔断状态：拒绝请求
    false
  } else {
    true
  }
}
```

---

### 2. 添加缓存层

```moonbit
struct CacheLayer {
  cache : Map[String, Response]
  ttl_ms : Int
}

async fn CacheLayer::get_or_fetch(
  self : CacheLayer,
  key : String,
  fetch : () -> Response
) -> Response {
  match self.cache[key] {
    Some(cached) => cached  // 缓存命中
    None => {
      let response = fetch()
      self.cache[key] = response
      response
    }
  }
}
```

---

### 3. 添加监控指标

```moonbit
struct Metrics {
  mut request_count : Map[String, Int]  // 按路径统计
  mut latency_sum : Map[String, Int]    // 延迟累计
}

fn Metrics::record(self : Metrics, path : String, latency_ms : Int) -> Unit {
  // 记录请求数
  self.request_count[path] = self.request_count[path]? + 1 or 1
  
  // 记录延迟
  self.latency_sum[path] = self.latency_sum[path]? + latency_ms or latency_ms
}
```

---

## 学到了什么？

完成这个示例后，你应该掌握：

1. **综合应用多个 Async 模式**
   - TaskGroup + Semaphore + 超时 + 重试
   - 结构化并发 + 限流 + 后台任务

2. **真实场景的架构设计**
   - 路由层、超时层、重试层的职责分离
   - 统计监控与健康检查

3. **性能优化技巧**
   - 批量处理并行化
   - 后台任务不阻塞主流程
   - 限流保护后端服务

4. **生产级代码质量**
   - 完整的错误处理
   - 可配置的行为
   - 全面的测试覆盖

---

## 下一步

1. **扩展功能**：添加熔断器、缓存层、监控指标
2. **对照检查清单**：用 `docs/best_practices.md` 的 PR 清单审查代码
3. **应用到项目**：把这些模式迁移到你的真实项目

---

## 相关文档

- [完整 API 索引](../../src/README.md)
- [最佳实践](../../docs/best_practices.md)
- [快速参考](../../docs/quick-reference.md)
- [FAQ](../../docs/faq.md)

---

**这是本仓库最复杂的示例，展示了生产级 Async 代码的完整形态！** 🎉

