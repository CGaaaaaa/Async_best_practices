## examples/task_group — 结构化并发与取消传播

> **推荐阅读顺序：第 2 个**（理解并发任务管理）

---

## 核心知识点

- ✅ **结构化并发（Structured Concurrency）**：用 `TaskGroup` 管理任务生命周期
- ✅ **fail-fast 取消传播**：一个任务失败时，自动取消兄弟任务
- ✅ **任务等待**：用 `wait()` 获取任务结果

---

## 场景说明

这个示例展示：
1. 如何用 `TaskGroup` 并发执行多个任务
2. 当某个任务失败时，如何自动取消其他任务（fail-fast）
3. 如何处理任务失败的异常

**为什么需要 TaskGroup？**
- **资源管理**：防止任务泄漏（父任务退出时子任务还在跑）
- **取消传播**：父任务取消时，子任务也被取消
- **fail-fast**：关键任务失败时，立即取消兄弟任务（避免浪费资源）

---

## 代码结构

```
examples/task_group/
├── README.mbt.md         # 本文档
├── task_group.mbt        # 结构化并发示例
├── task_group_test.mbt   # 取消传播测试
└── moon.pkg.json         # 包配置
```

---

## 关键代码解析

### 示例代码（task_group.mbt）

```moonbit
pub async fn demo_task_group() -> String {
  let log = StringBuilder::new()
  
  // ✅ 用 TaskGroup 管理并发任务
  ignore(
    @async.with_task_group(fn(group) {
      let task1 = group.spawn(fn() {
        @async.sleep(100)
        log.write_string("Task 1 finished\n")
        1
      })
      
      let task2 = group.spawn(fn() {
        @async.sleep(50)
        log.write_string("Task 2 failed\n")
        raise Failure("Task 2 error")  // 模拟失败
        2
      })
      
      let task3 = group.spawn(fn() {
        @async.sleep(200)
        log.write_string("Task 3 finished\n")
        3
      })

      // 等待任务（如果其中一个失败，整个组会取消）
      let res1 = task1.wait()
      let res3 = task3.wait()
      log.write_string("All tasks completed: \{res1}, \{res3}\n")
    })
  ) catch {
    err => log.write_string("TaskGroup failed: \{err}\n")
  }
  
  log.to_string()
}
```

**关键点**：
1. **用 `with_task_group` 包裹**：所有并发任务都在 group 内创建
2. **用 `group.spawn` 创建任务**：不要用野生 `@async.spawn`
3. **fail-fast 行为**：task2 失败后，task1/task3 被自动取消
4. **异常捕获**：用 `catch` 处理 TaskGroup 失败

### 测试代码（task_group_test.mbt）

```moonbit
async test "demo_task_group_flow" {
  let out = demo_task_group()
  inspect(
    out,
    content=(
      #|Task 2 failed
      #|TaskGroup failed: Failure("Task 2 error")
      #|
    ),
  )
}
```

**观察到什么？**
- Task 2 在 50ms 时失败
- Task 1（100ms）和 Task 3（200ms）没有输出 "finished" → 被取消了
- 整个 TaskGroup 返回错误

---

## 反模式对比

### 反模式：野生 spawn ❌

```moonbit
async fn bad_example() -> Int {
  // ❌ 野生 spawn，没有 TaskGroup 管理
  let t1 = @async.spawn(fn() { 
    @async.sleep(100)
    1
  })
  let t2 = @async.spawn(fn() { 
    @async.sleep(50)
    raise Failure("error")  // t1 不会被取消！
    2
  })
  
  // 问题：
  // 1. t2 失败，t1 还在跑（浪费资源）
  // 2. 父任务取消时，t1/t2 不会被取消
  t1.wait() + t2.wait()
}
```

### 正例：用 TaskGroup ✅

```moonbit
async fn good_example() -> Int {
  // ✅ 用 TaskGroup 管理
  @async.with_task_group(fn(group) {
    let t1 = group.spawn(fn() { 
      @async.sleep(100)
      1
    })
    let t2 = group.spawn(fn() { 
      @async.sleep(50)
      raise Failure("error")  // t1 会被自动取消
      2
    })
    
    t1.wait() + t2.wait()
  })
}
```

---

## 什么时候用 `spawn_bg`？

`spawn_bg` 用于**后台可选任务**（允许失败，不影响主流程）：

```moonbit
@async.with_task_group(fn(group) {
  let main_task = group.spawn(fn() { 
    // 关键任务：处理订单
    process_order()
  })
  
  // ✅ 后台任务：打点日志（允许失败）
  group.spawn_bg(fn() {
    log_metrics()  // 即使失败也不取消 main_task
  })
  
  main_task.wait()
})
```

**什么是"后台可选任务"**：
- 打点/监控日志
- 非关键缓存预热
- 异步通知（失败了用户也能继续操作）

---

## 运行示例

### 运行测试

```bash
cd examples/task_group
moon test --target native
```

**预期输出**：
```
Finished. moon: no work to do
Total tests: 1, passed: 1, failed: 0.
```

### 修改示例：所有任务成功

尝试注释掉 task2 的 `raise`：

```moonbit
let task2 = group.spawn(fn() {
  @async.sleep(50)
  log.write_string("Task 2 finished\n")  // 不再失败
  2
})
```

**预期行为**：
- 所有任务都完成
- 输出包含 "Task 1 finished", "Task 2 finished", "Task 3 finished"

---

## 学到了什么？

完成这个示例后，你应该理解：

1. **结构化并发**
   - 用 `with_task_group` 管理任务生命周期
   - 用 `group.spawn` 创建子任务（不要用野生 `@async.spawn`）

2. **fail-fast 取消传播**
   - 默认 `allow_failure=false`，一个任务失败会取消兄弟任务
   - 用 `spawn_bg` 创建允许失败的后台任务

3. **为什么这样设计**
   - 防止任务泄漏（父任务退出时子任务也结束）
   - 节省资源（关键任务失败时立即取消其他任务）

---

## 下一步

继续学习其他模式：

- **[examples/retry_timeout](../retry_timeout/)**：超时/重试的详细场景
- **[examples/semaphore_limiter](../semaphore_limiter/)**：并发限流

---

## 常见问题

### Q1：什么时候用 `spawn` vs `spawn_bg`？

**A**：
- `spawn`：关键任务（失败时整个 group 失败）
- `spawn_bg`：后台可选任务（失败不影响主流程）

### Q2：如何让所有任务都执行完（不要 fail-fast）？

**A**：不推荐！如果确实需要，可以在每个任务内 `catch` 异常：

```moonbit
let task2 = group.spawn(fn() {
  (fn() {
    @async.sleep(50)
    raise Failure("error")
    2
  })() catch { _ => -1 }  // 捕获异常，返回默认值
})
```

但这样会失去 fail-fast 的好处。

### Q3：为什么示例中用 `ignore(...)`？

**A**：
- `with_task_group` 返回最后一个表达式的值
- 我们只关心日志输出（`log.to_string()`），不关心 group 的返回值
- 用 `ignore` 明确忽略返回值，避免类型推断错误

---

**掌握 TaskGroup 后，你的异步代码会更安全、更易维护！** 🚀

