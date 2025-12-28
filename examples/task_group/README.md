## examples/task_group — 结构化并发与取消传播

> **推荐阅读顺序：第 2 个**（理解并发任务管理）

---

## 核心知识点

- ✅ **结构化并发**：用 `TaskGroup` 管理任务生命周期
- ✅ **fail-fast 取消传播**：一个任务失败时，自动取消兄弟任务
- ✅ **任务等待**：用 `wait()` 获取任务结果

---

## 快速运行

```bash
cd examples/task_group
moon test --target native
```

---

## 关键代码

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

**要点**：
- `group.spawn()` 创建关键任务（失败会取消兄弟任务）
- `task.wait()` 等待任务完成
- TaskGroup 退出时自动清理所有子任务

---

## 学到了什么？

1. **结构化并发**：所有任务都在 TaskGroup 内，生命周期可控
2. **fail-fast**：关键任务失败时，自动取消其他任务
3. **资源管理**：父任务退出时，子任务自动清理

---

## 下一步

- 继续学习 [`examples/retry_timeout`](../retry_timeout/README.md)（超时/重试）
- 参考 [`docs/quick-reference.md`](../../docs/quick-reference.md) 查看 TaskGroup API
- 查看 [`docs/faq.md`](../../docs/faq.md) 了解常见问题
