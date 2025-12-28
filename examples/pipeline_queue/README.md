## examples/pipeline_queue — 生产者-消费者流水线

> **推荐阅读顺序：第 5 个**（理解队列与背压）

---

## 核心知识点

- ✅ **生产者-消费者模式**：用 `aqueue.Queue` 解耦生产与消费
- ✅ **并行消费**：多个 worker 并行处理数据
- ✅ **背压机制**：用 Semaphore 控制队列大小（防止内存爆炸）

---

## 快速运行

```bash
cd examples/pipeline_queue
moon test --target native
```

---

## 关键代码

```moonbit
pub async fn pipeline_sum(n_items : Int, workers : Int) -> Int {
  @async.with_task_group(fn(group) {
    let q = @aqueue.Queue::new()  // ✅ 创建队列

    // Producer：生产 1..n_items
    group.spawn_bg(fn() {
      for i in 1..(n_items + 1) {
        q.put(i)
      }
      // 发送终止信号
      for _ in 0..<workers {
        q.put(0)  // 0 表示结束
      }
    })

    // Consumers：多个 worker 并行消费
    let tasks = Array::new()
    for _ in 0..<workers {
      tasks.push(group.spawn(fn() -> Int raise {
        let mut acc = 0
        for {
          let v = q.get()  // ✅ 阻塞获取数据
          guard v != 0 else { break }  // 收到终止信号
          acc = acc + v
        }
        acc
      }))
    }

    // Aggregate：汇总所有 worker 的结果
    let mut sum = 0
    for task in tasks {
      sum = sum + task.wait()
    }
    sum
  })
}
```

**要点**：
- `q.put(item)` 放入数据（非阻塞）
- `q.get()` 阻塞获取数据
- 用特殊值（0）作为终止信号
- 多个 worker 并行消费，提升吞吐量

**真实场景**：
- 爬虫抓取 URL，多个 worker 并行解析内容
- 日志收集，多个 worker 并行写入 DB
- 图片处理，多个 worker 并行压缩/上传

**⚠️ 注意**：`aqueue.Queue` 是无界缓冲，生产速度 > 消费速度时会导致内存增长。实际项目中需要用 Semaphore 控制队列大小。

---

## 学到了什么？

1. **解耦生产与消费**：生产者不需要等待消费者处理完
2. **并行处理**：多个 worker 并行消费，提升吞吐量
3. **背压控制**：用 Semaphore 防止队列无限增长

---

## 下一步

- 继续学习 [`examples/api-gateway`](../api-gateway/README.md)（综合真实案例）
- 参考 [`docs/quick-reference.md`](../../docs/quick-reference.md) 查看 Queue API
- 查看 [`docs/best_practices.md`](../../docs/best_practices.md) 了解队列最佳实践
