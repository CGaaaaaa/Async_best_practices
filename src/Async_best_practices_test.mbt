///|
async test "hello_async" {
  let result = hello_async()
  inspect(result, content="Hello, Async!")
}

///|
async test "concurrent_tasks" {
  let result = concurrent_tasks()
  inspect(result, content="[1, 2, 3]")
}

///|
async test "timeout_example" {
  let result = timeout_example()
  inspect(result, content="Task timed out after 50ms")
}

///|
async test "sequential_pipeline" {
  let result = sequential_pipeline()
  inspect(result, content="84")
}

///|
async test "race_example" {
  let result = race_example()
  inspect(result, content="Task 2 finished")
}

///|
async test "retry_example" {
  let result = retry_example()
  inspect(
    result,
    content=(
      #|Ok("Success on attempt 2")
    ),
  )
}

///|
async test "error_handling_example" {
  let result = error_handling_example()
  inspect(result, content="Main task completed successfully")
}

///|
async test "batch_processing" {
  let result = batch_processing()
  inspect(result, content="[1, 4, 9, 16, 25]")
}

///|
async test "demo_spawn" {
  let out = demo_spawn()
  inspect(
    out,
    content=(
      #|task 1, tick 1
      #|task 2, tick 1
      #|task 1, tick 2
      #|task 2, tick 2
      #|task 1, tick 3
      #|task 2, tick 3
      #|
    ),
  )
}

///|
async test "demo_with_timeout" {
  let out = demo_with_timeout()
  inspect(
    out,
    content=(
      #|task cancelled
      #|`with_timeout` fail with TimeoutError
      #|main task finished
      #|300ms tick
      #|Ok(())
    ),
  )
}

///|
async test "demo_semaphore" {
  let out = demo_semaphore()
  inspect(
    out,
    content=(
      #|task 0 obtained resource
      #|task 1 obtained resource
      #|tick
      #|task 2 obtained resource
      #|task 3 obtained resource
      #|tick
      #|task 4 obtained resource
      #|task 5 obtained resource
      #|tick
      #|
    ),
  )
}

///|
async test "demo_protect_from_cancel" {
  let out = demo_protect_from_cancel()
  inspect(
    out,
    content=(
      #|critical job finished
      #|job cancelled after critical part
      #|TimeoutError
    ),
  )
}

///|
async test "demo_retry_fixed" {
  let out = demo_retry_fixed()
  inspect(
    out,
    content=(
      #|loop 0
      #|tick 0
      #|loop 1
      #|tick 1
      #|loop 2
      #|tick 2
      #|
    ),
  )
}

///|
async test "demo_with_timeout_opt" {
  let out = demo_with_timeout_opt()
  inspect(
    out,
    content=(
      #|timeout -> None
      #|
    ),
  )
}

///|
async test "demo_queue_pipeline" {
  let out = demo_queue_pipeline()
  inspect(
    out,
    content=(
      #|produced 0
      #|consumed 0
      #|produced 1
      #|consumed 1
      #|produced 2
      #|consumed 2
      #|
    ),
  )
}

///|
async test "demo_retry_exponential" {
  let out = demo_retry_exponential()
  inspect(
    out,
    content=(
      #|loop 0
      #|tick 0
      #|loop 1
      #|tick 1
      #|tick 2
      #|loop 2
      #|tick 3
      #|tick 4
      #|tick 5
      #|loop 3
      #|retry completed
      #|tick 6
      #|Ok(())
    ),
  )
}

///|
async test "demo_semaphore_try_acquire" {
  let out = demo_semaphore_try_acquire()
  inspect(
    out,
    content=(
      #|occupied
      #|false
      #|released
      #|true
      #|
    ),
  )
}

///|
async test "demo_queue_mpmc" {
  let out = demo_queue_mpmc()
  inspect(
    out,
    content=(
      #|produced 0
      #|consumed 0
      #|produced 1
      #|consumed 1
      #|produced 2
      #|consumed 2
      #|produced 3
      #|consumed 3
      #|produced 4
      #|consumed 4
      #|produced 5
      #|consumed 5
      #|
    ),
  )
}

///|
async test "demo_task_wait_and_try_wait" {
  let out = demo_task_wait_and_try_wait()
  inspect(
    out,
    content=(
      #|None
      #|value=42
      #|
    ),
  )
}

///|
async test "demo_spawn_loop_retry_exponential" {
  let out = demo_spawn_loop_retry_exponential()
  inspect(
    out,
    content=(
      #|loop 0
      #|tick 0
      #|loop 1
      #|tick 1
      #|tick 2
      #|loop 2
      #|tick 3
      #|tick 4
      #|tick 5
      #|loop 3
      #|loop 4
      #|tick 6
      #|loop 5
      #|tick 7
      #|tick 8
      #|loop 6
      #|Ok(())
    ),
  )
}

///|
async test "demo_group_defer" {
  let out = demo_group_defer()
  inspect(
    out,
    content=(
      #|defer for first task
      #|defer for cancelled task
      #|second group defer
      #|first group defer
      #|
    ),
  )
}

///|
async test "demo_retry_immediate" {
  let out = demo_retry_immediate()
  inspect(
    out,
    content=(
      #|tick 0
      #|tick 1
      #|tick 2
      #|
    ),
  )
}

///|
async test "demo_retry_fatal_error" {
  let out = demo_retry_fatal_error()
  inspect(
    out,
    content=(
      #|worker run #0
      #|worker run #1
      #|worker run #2
      #|Err(Failure("fatal error"))
    ),
  )
}

///|
async test "demo_queue_try_get_nonblocking" {
  let out = demo_queue_try_get_nonblocking()
  inspect(
    out,
    content=(
      #|produced 0
      #|consumed 0
      #|produced 1
      #|consumed 1
      #|produced 2
      #|consumed 2
      #|
    ),
  )
}

///|
async test "demo_business_checkout_flow" {
  let out = demo_business_checkout_flow()
  inspect(
    out,
    content=(
      #|start order 101
      #|order 101 attempt 0
      #|order 101 attempt 1
      #|order 101 success
      #|start order 102
      #|order 102 attempt 0
      #|order 102 attempt 1
      #|order 102 attempt 2
      #|order 102 success
      #|
    ),
  )
}
