///|
/// TaskGroup 示例：结构化并发 + fail-fast + 取消传播

///|
/// fail-fast：当组内一个关键任务失败时（allow_failure=false 默认），组会失败，
/// 其它子任务会被取消。
///
/// 返回值：是否观测到“兄弟任务被取消”（通过 sleep 被中断来判断）。
pub async fn fail_fast_cancels_sibling() -> Bool {
  let sibling_cancelled = @ref.new(false)
  try {
    ignore(@async.with_task_group(fn(group) {
      // 一个会长期 sleep 的任务：如果被取消，sleep 会抛错提前返回
      group.spawn_bg(fn() {
        try {
          @async.sleep(60_000)
        } catch {
          _ => sibling_cancelled.val = true
        }
      })

      // 一个关键任务立即失败 -> 触发 fail-fast
      group.spawn_bg(fn() { raise Failure("boom") })

      // 给调度器一个机会，让取消传播发生
      @async.sleep(1)
      0
    }))
    false
  } catch {
    _ => sibling_cancelled.val
  }
}

///|
/// 典型模式：并发发起多个子任务，wait 汇总结果。
pub async fn sum_two_tasks() -> Int {
  @async.with_task_group(fn(group) {
    let a = group.spawn(fn() {
      @async.sleep(10)
      1
    })
    let b = group.spawn(fn() {
      @async.sleep(1)
      2
    })
    a.wait() + b.wait()
  })
}


