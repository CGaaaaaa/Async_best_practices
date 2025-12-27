///|
async test "call_payment_with_retry_examples" {
  // order 101: will succeed on attempt 2
  let r1 = call_payment_with_retry(101)
  inspect(r1, content="Ok(\"ok\")")

  // order 102: will succeed on attempt 3
  let r2 = call_payment_with_retry(102)
  inspect(r2, content="Ok(\"ok\")")
}


