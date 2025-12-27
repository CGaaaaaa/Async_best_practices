## examples/semaphore_limiter — 并发限流与资源控制

> **推荐阅读顺序：第 4 个**（理解并发控制）

---

## 核心知识点

- ✅ **并发限流**：用 `Semaphore` 限制最大并发数
- ✅ **资源保护**：防止 DB 连接池、API 调用被打爆
- ✅ **背压机制**：任务自动等待，不会无限堆积

---

## 场景说明

这个示例展示：
1. 如何用 `Semaphore` 限制并发任务数量
2. 观测最大并发数（验证限流生效）
3. 任务如何排队等待槽位

**为什么需要限流？**
- **保护外部依赖**：DB 连接池、第三方 API 有并发上限
- **保护自身资源**：CPU/内存有限，无限并发会导致服务崩溃
- **避免级联故障**：过载的服务会拖垮下游依赖

**真实场景**：
- 批量处理 10000 个订单，但 DB 连接池只有 20 个
- 调用第三方 API，对方限制 QPS 100
- CPU 密集任务（图片处理），避免 CPU 100%

---

## 代码结构

```
examples/semaphore_limiter/
├── README.mbt.md         # 本文档
├── limiter.mbt           # 限流示例
├── limiter_test.mbt      # 并发观测测试
└── moon.pkg.json         # 包配置
```

---

## 关键代码解析

### 示例代码（limiter.mbt）

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

**关键点**：
1. **创建 Semaphore**：`Semaphore::new(2)` 表示最多 2 个并发
2. **阻塞获取**：`acquire()` 会阻塞直到有空闲槽位
3. **释放槽位**：`release()` 释放槽位，让等待的任务继续
4. **用 `spawn_bg`**：后台任务，不阻塞主流程

### 测试代码（limiter_test.mbt）

```moonbit
async test "demo_semaphore_limiter_flow" {
  let out = demo_semaphore_limiter()
  inspect(
    out,
    content=(
      #|Task 0 acquired semaphore
      #|Task 1 acquired semaphore
      #|Task 0 released semaphore
      #|Task 2 acquired semaphore
      #|Task 1 released semaphore
      #|Task 3 acquired semaphore
      #|Task 2 released semaphore
      #|Task 4 acquired semaphore
      #|Task 3 released semaphore
      #|Task 4 released semaphore
      #|
    ),
  )
}
```

**观察到什么？**
- Task 0 和 Task 1 先获取槽位（最多 2 个并发）
- Task 0 释放后，Task 2 才获取槽位
- Task 1 释放后，Task 3 才获取槽位
- 最多同时有 2 个任务在 "acquired" 和 "released" 之间

---

## 反模式对比

### 反模式：无限并发 ❌

```moonbit
async fn bad_batch_process(orders : Array[Order]) {
  @async.with_task_group(fn(group) {
    // ❌ 如果 orders 有 10000 个，会同时发起 10000 个 DB 连接
    for order in orders {
      group.spawn_bg(fn() {
        db_update(order)  // DB 连接池被打爆
      })
    }
  })
}
```

**问题**：
- DB 连接池耗尽（例如 MySQL 默认最大连接 151）
- 第三方 API 限流（返回 429 Too Many Requests）
- 服务器 CPU/内存耗尽

### 正例：用 Semaphore 限流 ✅

```moonbit
async fn good_batch_process(orders : Array[Order]) {
  let sem = @semaphore.Semaphore::new(20)  // ✅ 最大 20 并发
  
  @async.with_task_group(fn(group) {
    for order in orders {
      group.spawn_bg(fn() raise {
        sem.acquire()  // 阻塞等待槽位
        db_update(order)
        sem.release()
      })
    }
  })
}
```

**好处**：
- 最多 20 个并发，保护 DB 连接池
- 自动背压：新任务等待旧任务完成
- 不会因为并发过高导致服务崩溃

---

## 阻塞 vs 非阻塞获取

### `acquire()`：阻塞等待

```moonbit
let sem = @semaphore.Semaphore::new(5)
sem.acquire()  // 如果没有槽位，会一直等
// ... 关键区操作
sem.release()
```

**适用场景**：必须执行的任务（例如订单处理）

### `try_acquire()`：非阻塞尝试

```moonbit
let sem = @semaphore.Semaphore::new(5)
match sem.try_acquire() {
  Some(_) => {
    // 获取成功，执行关键区操作
    process_task()
    sem.release()
  }
  None => {
    // 快速失败，或者加入队列稍后重试
    log("too busy, skip this task")
  }
}
```

**适用场景**：可降级的任务（例如实时推荐，繁忙时跳过）

---

## 运行示例

### 运行测试

```bash
cd examples/semaphore_limiter
moon test --target native
```

**预期输出**：
```
Finished. moon: no work to do
Total tests: 1, passed: 1, failed: 0.
```

### 修改示例：观察不同并发数

尝试修改 Semaphore 的大小：

```moonbit
let semaphore = @semaphore.Semaphore::new(1)  // 改为 1（串行）
```

**预期行为**：
- 只有 1 个任务在运行
- Task 0 → Task 1 → Task 2 → Task 3 → Task 4（完全串行）

尝试修改为 5：

```moonbit
let semaphore = @semaphore.Semaphore::new(5)  // 改为 5（全并发）
```

**预期行为**：
- 所有 5 个任务同时运行
- 所有任务几乎同时 acquire 和 release

---

## 学到了什么？

完成这个示例后，你应该理解：

1. **并发限流**
   - 用 `Semaphore::new(N)` 限制最大并发数
   - `acquire()` 阻塞等待槽位，`release()` 释放槽位

2. **资源保护**
   - 保护外部依赖（DB、API）不被打爆
   - 保护自身资源（内存、CPU）不耗尽

3. **背压机制**
   - 新任务自动等待旧任务完成
   - 不会因为并发过高导致 OOM

---

## 下一步

继续学习最后一个模式：

- **[examples/pipeline_queue](../pipeline_queue/)**：生产者-消费者流水线

---

## 常见问题

### Q1：如何确定合适的并发数？

**A**：根据瓶颈资源确定：
- **DB 连接池**：连接池大小 - 10（留余量）
- **第三方 API**：对方的 QPS 限制 / 请求耗时
- **CPU 密集任务**：CPU 核心数 * 1.5 ~ 2

### Q2：忘记 `release()` 会怎样？

**A**：
- 槽位永久被占用，后续任务永远等待
- 建议用 `defer` 确保释放：

```moonbit
sem.acquire()
defer { sem.release() }  // 保证一定会释放
process_task()
```

（注：MoonBit 是否支持 `defer` 需要查阅文档，如果不支持可以用 `try...catch...finally` 模式）

### Q3：`Semaphore` 和 `Mutex` 有什么区别？

**A**：
- `Semaphore(N)`：允许 N 个并发
- `Mutex`：等价于 `Semaphore(1)`，只允许 1 个并发

### Q4：如何观测当前并发数？

**A**：需要手动计数：

```moonbit
let active_count = @ref.new(0)
let max_count = @ref.new(0)

sem.acquire()
active_count.val = active_count.val + 1
if active_count.val > max_count.val {
  max_count.val = active_count.val
}

// ... 关键区操作

active_count.val = active_count.val - 1
sem.release()
```

---

**掌握 Semaphore 后，你的服务会更加稳定、不会因为并发过高而崩溃！** 🚀

