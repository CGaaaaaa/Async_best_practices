///|
async test "pipeline_queue_sum" {
  // 1..100 的和 = 5050
  let out = pipeline_sum(100, 2)
  inspect(out, content="5050")
}


