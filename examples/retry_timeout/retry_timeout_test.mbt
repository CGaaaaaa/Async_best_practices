///|
async test "retry_timeout_retry_then_ok" {
  let out = retry_then_ok()
  inspect(out, content="Ok(42)")
}

///|
async test "retry_timeout_timeout_returns_err" {
  let out = timeout_returns_err()
  inspect(out, content="Err(\"timeout\")")
}


