///|
pub async fn demo_spawn() -> String {
  let buf = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.spawn_bg(fn() {
      @async.sleep(100)
      buf.write_string("task 1, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 1, tick 3\n")
    })
    root.spawn_bg(fn() {
      @async.sleep(200)
      buf.write_string("task 2, tick 1\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 2\n")
      @async.sleep(200)
      buf.write_string("task 2, tick 3\n")
    })
  })
  buf.to_string()
}

///|
pub async fn demo_with_timeout() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        @async.sleep(300)
        log.write_string("300ms tick\n")
      })
      @async.with_timeout(200, fn() {
        @async.sleep(400) catch {
          _ => log.write_string("task cancelled\n")
        }
      }) catch {
        _ => log.write_string("`with_timeout` fail with TimeoutError\n")
      }
      log.write_string("main task finished\n")
    }),
  )
  log.to_string()
}

///|
pub async fn demo_semaphore() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let semaphore = @semaphore.Semaphore::new(2)
    for i in 0..<6 {
      root.spawn_bg(fn() {
        semaphore.acquire()
        log.write_string("task \{i} obtained resource\n")
        @async.sleep(200)
        semaphore.release()
      })
    }
    @async.sleep(100)
    for _ in 0..<3 {
      log.write_string("tick\n")
      @async.sleep(200)
    }
  })
  log.to_string()
}

///|
pub async fn demo_protect_from_cancel() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.spawn_bg(fn() {
      @async.protect_from_cancel(fn() {
        @async.sleep(300) catch {
          err => {
            log.write_string("critical job cancelled with error \{err}\n")
            raise err
          }
        }
        log.write_string("critical job finished\n")
      }) catch {
        _ => log.write_string("job cancelled after critical part\n")
      }
      @async.sleep(150)
      log.write_string("non-critical part finished\n")
    })
    // Cause timeout after 200ms to cancel the group
    @async.with_timeout(200, fn() { @async.sleep(1000) })
  }) catch {
    err => log.write_object(err)
  }
  log.to_string()
}

///|
pub async fn demo_retry_fixed() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    // timeline logger to visualize delays
    root.spawn_bg(fn() {
      for i in 0..<3 {
        @async.sleep(200)
        log.write_string("tick \{i}\n")
      }
    })
    @async.sleep(100)
    let mut i = 0
    @async.retry(FixedDelay(200), fn() {
      log.write_string("loop \{i}\n")
      i = i + 1
      if i < 3 {
        raise Failure("transient")
      }
    })
  })
  log.to_string()
}

///|
pub async fn demo_with_timeout_opt() -> String {
  let log = StringBuilder::new()
  let out = @async.with_timeout_opt(200, fn() {
    @async.sleep(300)
    "done"
  })
  match out {
    Some(v) => log.write_string("value=\{v}\n")
    None => log.write_string("timeout -> None\n")
  }
  log.to_string()
}

///|
pub async fn demo_queue_pipeline() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer
    root.spawn_bg(fn() {
      for i in 0..<3 {
        q.put(i)
        log.write_string("produced \{i}\n")
        @async.sleep(100)
      }
    })
    // consumer
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    @async.sleep(500)
  })
  log.to_string()
}

///|
pub async fn demo_retry_exponential() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        for i in 0..<7 {
          @async.sleep(200)
          log.write_string("tick \{i}\n")
        }
      })
      @async.sleep(100)
      let mut i = 0
      @async.retry(ExponentialDelay(initial=200, factor=2, maximum=600), fn() {
        log.write_string("loop \{i}\n")
        i = i + 1
        if i < 4 {
          raise Failure("transient")
        }
      })
      log.write_string("retry completed\n")
    }),
  )
  log.to_string()
}

///|
pub async fn demo_semaphore_try_acquire() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let semaphore = @semaphore.Semaphore::new(1)
    // occupy once so try_acquire initially fails
    root.spawn_bg(fn() {
      semaphore.acquire()
      log.write_string("occupied\n")
      @async.sleep(300)
      semaphore.release()
      log.write_string("released\n")
    })
    @async.sleep(100)
    log.write_object(semaphore.try_acquire())
    log.write_string("\n")
    @async.sleep(300)
    log.write_object(semaphore.try_acquire())
    log.write_string("\n")
  })
  log.to_string()
}

///|
pub async fn demo_queue_mpmc() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer 0 produces 0,2,4
    root.spawn_bg(fn() {
      for i in 0..<3 {
        let v = i * 2
        q.put(v)
        log.write_string("produced \{v}\n")
        @async.sleep(100)
      }
    })
    // producer 1 produces 1,3,5, staggered to interleave
    root.spawn_bg(fn() {
      @async.sleep(50)
      for i in 0..<3 {
        let v = i * 2 + 1
        q.put(v)
        log.write_string("produced \{v}\n")
        @async.sleep(100)
      }
    })
    // two consumers; we only assert FIFO of values, not consumer id
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    root.spawn_bg(fn() {
      for _ in 0..<3 {
        let v = q.get()
        log.write_string("consumed \{v}\n")
      }
    })
    @async.sleep(800)
  })
  log.to_string()
}

///|
pub async fn demo_task_wait_and_try_wait() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let task = root.spawn(fn() {
      @async.sleep(200)
      42
    })
    log.write_object(task.try_wait())
    log.write_string("\n")
    let v = task.wait()
    log.write_string("value=\{v}\n")
  })
  log.to_string()
}

///|
pub async fn demo_spawn_loop_retry_exponential() -> String {
  let log = StringBuilder::new()
  log.write_object(
    try? @async.with_task_group(fn(root) {
      root.spawn_bg(fn() {
        for i in 0..<9 {
          @async.sleep(200)
          log.write_string("tick \{i}\n")
        }
      })
      @async.sleep(100)
      let mut i = 0
      root.spawn_loop(
        retry=ExponentialDelay(initial=200, factor=2, maximum=600),
        fn() {
          log.write_string("loop \{i}\n")
          i = i + 1
          match i {
            1 | 2 | 3 => raise Failure("transient")
            4 => IterContinue
            5 | 6 => raise Failure("transient")
            _ => IterEnd
          }
        },
      )
    }),
  )
  log.to_string()
}

///|
pub async fn demo_group_defer() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    root.add_defer(() => log.write_string("first group defer\n"))
    root.spawn_bg(fn() {
      defer log.write_string("defer for first task\n")
      @async.sleep(100)
    })
    root.spawn_bg(no_wait=true, fn() {
      defer log.write_string("defer for cancelled task\n")
      @async.sleep(1000)
    })
    root.add_defer(() => log.write_string("second group defer\n"))
  })
  log.to_string()
}

///|
pub async fn demo_retry_immediate() -> String {
  let log = StringBuilder::new()
  let mut i = 0
  @async.retry(Immediate, fn() {
    log.write_string("tick \{i}\n")
    i = i + 1
    if i < 3 {
      raise Failure("transient")
    }
  })
  log.to_string()
}

///|
pub async fn demo_retry_fatal_error() -> String {
  let log = StringBuilder::new()
  fn fatal_error(err) {
    not(err is @async.TimeoutError)
  }

  let mut i = 0
  async fn worker() {
    log.write_string("worker run #\{i}\n")
    i = i + 1
    if i < 3 {
      @async.with_timeout(100, () => @async.sleep(1000))
    } else {
      raise Failure("fatal error")
    }
  }

  log.write_object(try? @async.retry(Immediate, fatal_error~, worker))
  log.to_string()
}

///|
pub async fn demo_queue_try_get_nonblocking() -> String {
  let log = StringBuilder::new()
  @async.with_task_group(fn(root) {
    let q = @aqueue.Queue::new()
    // producer fills three values with gaps
    root.spawn_bg(fn() {
      for i in 0..<3 {
        @async.sleep(120)
        q.put(i)
        log.write_string("produced \{i}\n")
      }
    })
    // consumer: prefer non阻塞读取，若为空则短暂让出
    root.spawn_bg(fn() {
      let mut consumed = 0
      while consumed < 3 {
        match q.try_get() {
          Some(v) => {
            log.write_string("consumed \{v}\n")
            consumed = consumed + 1
          }
          None => @async.pause()
        }
      }
    })
    @async.sleep(600)
  })
  log.to_string()
}
