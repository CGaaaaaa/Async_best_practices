///|
/// Semaphore 示例：用信号量限制并发，避免把关键资源（DB/第三方）打爆。

///|
/// 启动 `jobs` 个任务，每个任务会占用一段时间的“资源”。
/// 返回运行过程中观测到的最大并发数（应 <= limit）。
pub async fn max_concurrency_observed(limit : Int, jobs : Int) -> Int {
  let sem = @async.Semaphore::new(limit)
  let in_flight = @ref.new(0)
  let max_seen = @ref.new(0)
  @async.with_task_group(fn(group) {
    let tasks : Array[@async.Task[Unit]] = []
    for _i in 0..<jobs {
      tasks.push(group.spawn(fn() {
        sem.acquire()
        defer sem.release()
        in_flight.val = in_flight.val + 1
        if in_flight.val > max_seen.val {
          max_seen.val = in_flight.val
        }
        @async.sleep(5)
        in_flight.val = in_flight.val - 1
      }))
    }
    for t in tasks {
      t.wait()
    }
    max_seen.val
  })
}


