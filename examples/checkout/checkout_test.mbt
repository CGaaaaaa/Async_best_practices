///|
async test "checkout_orders_flow" {
  let out = checkout_orders([101, 102])
  inspect(
    out,
    content=(
      #|start order 101
      #|order 101 success
      #|start order 102
      #|order 102 success
      #|
    ),
  )
}


