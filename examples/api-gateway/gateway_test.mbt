///|
/// API 网关测试

///|
async test "single_request_success" {
  let gateway = Gateway::new(GatewayConfig::default())
  let request = Request::new("/api/users", "GET", "")
  
  let response = gateway.handle_request(request)
  
  assert_eq(response.status, 200)
  assert_true(response.body.contains("User data"))
  assert_eq(gateway.total_requests, 1)
  assert_eq(gateway.successful_requests, 1)
}

///|
async test "route_to_different_services" {
  let gateway = Gateway::new(GatewayConfig::default())
  
  let user_req = Request::new("/api/users", "GET", "")
  let order_req = Request::new("/api/orders", "GET", "")
  let product_req = Request::new("/api/products", "GET", "")
  
  let user_resp = gateway.handle_request(user_req)
  let order_resp = gateway.handle_request(order_req)
  let product_resp = gateway.handle_request(product_req)
  
  assert_true(user_resp.body.contains("User"))
  assert_true(order_resp.body.contains("Order"))
  assert_true(product_resp.body.contains("Product"))
}

///|
async test "404_for_unknown_path" {
  let gateway = Gateway::new(GatewayConfig::default())
  let request = Request::new("/api/unknown", "GET", "")
  
  let response = gateway.handle_request(request)
  
  assert_eq(response.status, 404)
  assert_eq(response.body, "Not Found")
}

///|
async test "health_check" {
  let gateway = Gateway::new(GatewayConfig::default())
  let request = Request::new("/health", "GET", "")
  
  let response = gateway.handle_request(request)
  
  assert_eq(response.status, 200)
  assert_true(response.body.contains("OK"))
}

///|
async test "batch_requests_parallel" {
  let gateway = Gateway::new(GatewayConfig::default())
  
  let requests = [
    Request::new("/api/users", "GET", ""),
    Request::new("/api/orders", "GET", ""),
    Request::new("/api/products", "GET", ""),
  ]
  
  let responses = gateway.handle_batch_requests(requests)
  
  assert_eq(responses.length(), 3)
  assert_eq(responses[0].status, 200)
  assert_eq(responses[1].status, 200)
  assert_eq(responses[2].status, 200)
}

///|
async test "concurrent_limit" {
  // 限制最大并发为 2
  let config = GatewayConfig::new(2, 5000, false)
  let gateway = Gateway::new(config)
  
  let requests = [
    Request::new("/api/users", "GET", ""),
    Request::new("/api/orders", "GET", ""),
    Request::new("/api/products", "GET", ""),
    Request::new("/api/users", "GET", ""),
  ]
  
  let responses = gateway.handle_batch_requests(requests)
  
  // 所有请求应该成功，但受限于并发数
  assert_eq(responses.length(), 4)
  for response in responses {
    assert_eq(response.status, 200)
  }
}

///|
async test "retry_disabled" {
  // 测试禁用重试的场景
  let config = GatewayConfig::new(10, 3000, false)
  let gateway = Gateway::new(config)
  
  let request = Request::new("/api/users", "GET", "")
  let response = gateway.handle_request(request)
  
  // 即使禁用重试，正常请求也应该成功
  assert_eq(response.status, 200)
}

///|
async test "gateway_stats" {
  let gateway = Gateway::new(GatewayConfig::default())
  
  let request = Request::new("/api/users", "GET", "")
  let _ = gateway.handle_request(request)
  let _ = gateway.handle_request(request)
  
  let stats = gateway.get_stats()
  
  assert_true(stats.contains("Total: 2"))
  assert_true(stats.contains("Success: 2"))
}

///|
async test "timeout_protection" {
  // 设置非常短的超时时间
  let config = GatewayConfig::new(10, 1, false)  // 1ms 超时（必然超时）
  let gateway = Gateway::new(config)
  
  let request = Request::new("/api/users", "GET", "")
  let response = gateway.handle_request(request)
  
  // 应该返回超时错误
  assert_eq(response.status, 504)
  assert_true(response.body.contains("Timeout"))
  assert_eq(gateway.failed_requests, 1)
}
