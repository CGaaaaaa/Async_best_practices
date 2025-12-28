## examples/semaphore_limiter — 并发限流与资源控制

> **推荐阅读顺序：第 4 个**（理解并发控制）

---

## 核心知识点

- ✅ **并发限流**：用 `Semaphore` 限制最大并发数
- ✅ **资源保护**：防止 DB 连接池、API 调用被打爆
- ✅ **背压机制**：任务自动等待，不会无限堆积

---

## 快速运行

```bash
cd examples/semaphore_limiter
moon test --target native
```

---

## 关键代码

```moonbit
pub async fn demo_semaphore_limiter() -> String {
  let log = StringBuilder::new()
  
  @async.with_task_group(fn(group) {
    let semaphore = @semaphore.Semaphore::new(2)  // ✅ 最大并发 2
    
    // 创建 5 个任务，但最多同时运行 2 个
    for i in 0..<5 {
      group.spawn_bg(fn() raise {
        semaphore.acquire()  // 阻塞等待槽位
        log.write_string("Task \{i} acquired semaphore\n")
        
        @async.sleep(100)  // 模拟工作
        
        semaphore.release()
        log.write_string("Task \{i} released semaphore\n")
      })
    }
    
    @async.sleep(500)  // 等待所有任务完成
  })
  
  log.to_string()
}
```

**要点**：
- `Semaphore::new(2)` 表示最多 2 个并发
- `acquire()` 会阻塞直到有空闲槽位
- `release()` 释放槽位，让等待的任务继续

**真实场景**：
- 批量处理 10000 个订单，但 DB 连接池只有 20 个
- 调用第三方 API，对方限制 QPS 100
- CPU 密集任务（图片处理），避免 CPU 100%

---

## 学到了什么？

1. **资源保护**：限流保护外部依赖（DB、API）和自身资源（CPU、内存）
2. **自动排队**：任务自动等待，无需手动管理队列
3. **观测验证**：通过日志验证最大并发数确实被限制

---

## 下一步

- 继续学习 [`examples/pipeline_queue`](../pipeline_queue/README.md)（生产者-消费者）
- 参考 [`docs/quick-reference.md`](../../docs/quick-reference.md) 查看 Semaphore API
- 查看 [`docs/faq.md`](../../docs/faq.md) 了解并发控制常见问题
