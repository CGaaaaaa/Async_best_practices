///|
/// 超时 + 重试示例：业务代码只表达“我要调用什么”，策略由 infra 统一控制。

pub async fn retry_then_ok() -> Result[Int, String] {
  let attempt = @ref.new(0)
  @infra.call_with_timeout_and_retry(
    1_000,
    @async.ExponentialDelay(initial=1, factor=2, maximum=10),
    fn() {
      attempt.val = attempt.val + 1
      if attempt.val < 3 {
        raise Failure("transient")
      }
      42
    },
    max_retry=5,
  )
}

pub async fn timeout_returns_err() -> Result[Int, String] {
  @infra.call_with_timeout_and_retry(
    1,
    @async.FixedDelay(1),
    fn() {
      @async.sleep(10)
      1
    },
    max_retry=1,
  )
}


