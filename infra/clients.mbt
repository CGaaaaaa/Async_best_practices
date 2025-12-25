///|
/// infra: 基础设施客户端封装（超时 + 重试）示例实现
/// 将该文件放入 `infra/` 包，供示例和业务代码 import 复用。
///
/// 注意：这是示例实现，便于教学与测试；实际项目应替换为真实 HTTP/DB 客户端调用。
pub async fn call_payment_with_retry(order_id : Int) -> Result[String, String] {
  let mut attempt = 0
  let out = @async.with_timeout_opt(500, fn() {
    @async.retry(ExponentialDelay(initial=50, factor=2, maximum=200), fn() {
      attempt = attempt + 1
      // 模拟瞬态失败：order_id==101 第2次成功；order_id==102 第3次成功
      if order_id == 101 && attempt < 2 {
        raise Failure("transient")
      }
      if order_id == 102 && attempt < 3 {
        raise Failure("transient")
      }
    })
    "ok"
  })
  match out {
    Some(v) => Ok(v)
    None => Err("timeout")
  }
}


