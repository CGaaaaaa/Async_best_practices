///|
async test "task_group_fail_fast_cancels_sibling" {
  let ok = fail_fast_cancels_sibling()
  inspect(ok, content="true")
}

///|
async test "task_group_spawn_wait_sum" {
  let v = sum_two_tasks()
  inspect(v, content="3")
}


