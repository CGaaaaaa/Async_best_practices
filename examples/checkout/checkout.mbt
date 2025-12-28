///|
/// checkout 示例：演示如何在业务层使用策略收口层
/// 业务代码只处理 Result，不关心超时/重试细节
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  for id in order_ids {
    log.write_string("start order \{id}\n")
    let outcome = @src.call_payment_with_retry(id)
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  log.to_string()
}


