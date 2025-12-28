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

## 快速运行

```bash
cd examples/api-gateway
moon test --target native
```

---

## 功能清单

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

## 关键代码

### 请求处理流程（综合模式）

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

### 路由 + 超时 + 重试

```moonbit
async fn Gateway::handle_request_internal(
  self : Gateway,
  request : Request
) -> Response raise {
  // ✅ 统一超时
  let result = @async.with_timeout_opt(self.config.request_timeout_ms, fn() {
    // ✅ 路由分发
    match request.path {
      "/api/users" => self.call_user_service(request)
      "/api/orders" => self.call_order_service(request)
      "/api/products" => self.call_product_service(request)
      "/health" => self.health_check()
      _ => Response::new(404, "Not Found")
    }
  })
  
  match result {
    Some(response) => {
      self.successful_requests = self.successful_requests + 1
      response
    }
    None => {
      self.failed_requests = self.failed_requests + 1
      Response::new(504, "Gateway Timeout")
    }
  }
}
```

### 批量处理（并发优化）

```moonbit
pub async fn Gateway::handle_batch_requests(
  self : Gateway,
  requests : Array[Request]
) -> Array[Response] raise {
  @async.with_task_group(fn(group) {
    // ✅ 并行发起所有请求（受 limiter 限制）
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

---

## 学到了什么？

1. **综合应用多个 Async 模式**：TaskGroup + Semaphore + 超时 + 重试
2. **真实场景的架构设计**：路由层、超时层、重试层的职责分离
3. **性能优化技巧**：批量处理并行化，后台任务不阻塞主流程
4. **生产级代码质量**：完整的错误处理、可配置的行为、全面的测试覆盖

---

## 下一步

- 参考 [`docs/best_practices.md`](../../docs/best_practices.md) 的 PR 检查清单审查代码
- 查看 [`docs/quick-reference.md`](../../docs/quick-reference.md) 快速查阅 API
- 应用到你的项目：把这些模式迁移到真实业务场景

---

**这是本仓库最复杂的示例，展示了生产级 Async 代码的完整形态！** 🎉
