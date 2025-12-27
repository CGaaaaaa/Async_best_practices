///|
async test "semaphore_limits_max_concurrency" {
  let limit = 3
  let jobs = 20
  let max_seen = max_concurrency_observed(limit, jobs)
  inspect(max_seen, content="3")
}


