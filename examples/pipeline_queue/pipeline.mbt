///|
/// Queue 示例：生产者-消费者流水线（producer/consumer）。
///
/// 注意：`async.Queue` 是无界缓冲。
/// 真实业务里建议结合 Semaphore/限速，避免生产者无限制 put 导致内存膨胀。

///|
/// 把 1..=n 放入队列，启动 `workers` 个消费者并行消费并求和。
pub async fn pipeline_sum(n : Int, workers : Int) -> Int {
  let q : @aqueue.Queue[Int] = @aqueue.Queue::new()
  @async.with_task_group(fn(group) {
    // producer
    group.spawn_bg(fn() {
      for i in 1..<(n + 1) {
        q.put(i)
      }
      // 为每个 worker 放一个 sentinel(0) 表示结束
      for _ in 0..<workers {
        q.put(0)
      }
    })

    // consumers
    let tasks : Array[@async.Task[Int]] = []
    for _ in 0..<workers {
      tasks.push(group.spawn(fn() {
        let mut acc : Int = 0
        for {
          let v = q.get()
          guard v != 0 else { break }
          acc = acc + v
        }
        acc
      }))
    }

    let mut sum : Int = 0
    for t in tasks {
      sum = sum + t.wait()
    }
    sum
  })
}


