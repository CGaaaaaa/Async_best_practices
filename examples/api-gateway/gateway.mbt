///|
/// API 网关示例：综合展示 Async 最佳实践
/// 
/// 功能：
/// - 路由转发（/api/users, /api/orders, /api/products）
/// - 统一超时与重试
/// - 并发限流（Semaphore）
/// - 请求日志与错误处理
/// - 健康检查与熔断

///|
/// 请求结构
pub struct Request {
  path : String
  http_method : String
  body : String
} derive(Show, Eq)

///|
/// 创建请求
pub fn Request::new(path : String, http_method : String, body : String) -> Request {
  { path, http_method, body }
}

///|
/// 响应结构
pub struct Response {
  status : Int
  body : String
} derive(Show, Eq)

///|
/// 创建响应
pub fn Response::new(status : Int, body : String) -> Response {
  { status, body }
}

///|
/// 网关配置
pub struct GatewayConfig {
  max_concurrent_requests : Int  // 最大并发请求数
  request_timeout_ms : Int       // 请求超时时间
  enable_retry : Bool            // 是否启用重试
} derive(Show)

///|
/// 创建配置
pub fn GatewayConfig::new(max_concurrent_requests : Int, request_timeout_ms : Int, enable_retry : Bool) -> GatewayConfig {
  { max_concurrent_requests, request_timeout_ms, enable_retry }
}

///|
/// 默认配置
pub fn GatewayConfig::default() -> GatewayConfig {
  GatewayConfig::new(100, 3000, true)
}

///|
/// API 网关
pub struct Gateway {
  config : GatewayConfig
  limiter : @async.Semaphore
  mut total_requests : Int
  mut successful_requests : Int
  mut failed_requests : Int
}

///|
/// 创建网关实例
pub fn Gateway::new(config : GatewayConfig) -> Gateway {
  {
    config,
    limiter: @async.Semaphore::new(config.max_concurrent_requests),
    total_requests: 0,
    successful_requests: 0,
    failed_requests: 0,
  }
}

///|
/// 处理请求（入口）
pub async fn Gateway::handle_request(
  self : Gateway,
  request : Request
) -> Response raise {
  self.total_requests = self.total_requests + 1
  
  // 限流：阻塞等待槽位
  self.limiter.acquire()
  
  // 使用 TaskGroup 确保资源释放
  @async.with_task_group(fn(group) {
    let response_task = group.spawn(fn() {
      self.handle_request_internal(request)
    })
    
    // 后台任务：记录请求日志（允许失败）
    group.spawn_bg(fn() {
      self.log_request(request)
    })
    
    // 等待主任务完成
    let response = response_task.wait()
    self.limiter.release()  // 释放槽位
    response
  })
}

///|
/// 内部请求处理（带超时和重试）
async fn Gateway::handle_request_internal(
  self : Gateway,
  request : Request
) -> Response raise {
  // 统一超时保护
  let result = @async.with_timeout_opt(self.config.request_timeout_ms, fn() {
    // 根据路径路由到不同的后端服务
    match request.path {
      "/api/users" => self.call_user_service(request)
      "/api/orders" => self.call_order_service(request)
      "/api/products" => self.call_product_service(request)
      "/health" => self.health_check()
      _ => { status: 404, body: "Not Found" }
    }
  })
  
  match result {
    Some(response) => {
      self.successful_requests = self.successful_requests + 1
      response
    }
    None => {
      self.failed_requests = self.failed_requests + 1
      { status: 504, body: "Gateway Timeout" }
    }
  }
}

///|
/// 调用用户服务（带重试）
async fn Gateway::call_user_service(self : Gateway, request : Request) -> Response raise {
  if self.config.enable_retry {
    // 使用 infra 层的超时+重试封装
    let result = @src.call_with_timeout_and_retry(
      2000,
      @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
      fn() { self.simulate_user_service_call(request) },
    )
    match result {
      Ok(response) => response
      Err(e) => { status: 503, body: "User Service Error: \{e}" }
    }
  } else {
    self.simulate_user_service_call(request)
  }
}

///|
/// 调用订单服务
async fn Gateway::call_order_service(self : Gateway, request : Request) -> Response raise {
  if self.config.enable_retry {
    let result = @src.call_with_timeout_and_retry(
      2000,
      @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
      fn() { self.simulate_order_service_call(request) },
    )
    match result {
      Ok(response) => response
      Err(e) => { status: 503, body: "Order Service Error: \{e}" }
    }
  } else {
    self.simulate_order_service_call(request)
  }
}

///|
/// 调用商品服务
async fn Gateway::call_product_service(self : Gateway, request : Request) -> Response raise {
  // 商品服务不重试（假设幂等性问题）
  self.simulate_product_service_call(request)
}

///|
/// 健康检查
fn Gateway::health_check(self : Gateway) -> Response {
  let success_rate = if self.total_requests == 0 {
    100
  } else {
    self.successful_requests * 100 / self.total_requests
  }
  
  {
    status: 200,
    body: "OK - Success rate: \{success_rate}% - Total: \{self.total_requests}",
  }
}

///|
/// 记录请求日志（后台任务）
async fn Gateway::log_request(_self : Gateway, _request : Request) -> Unit {
  @async.sleep(10)  // 模拟日志写入延迟
  // 实际项目应写入日志系统
}

///|
/// 模拟用户服务调用
async fn Gateway::simulate_user_service_call(
  _self : Gateway,
  request : Request
) -> Response raise {
  @async.sleep(50)  // 模拟网络延迟
  { status: 200, body: "User data for \{request.path}" }
}

///|
/// 模拟订单服务调用
async fn Gateway::simulate_order_service_call(
  _self : Gateway,
  request : Request
) -> Response raise {
  @async.sleep(80)  // 模拟网络延迟
  { status: 200, body: "Order data for \{request.path}" }
}

///|
/// 模拟商品服务调用
async fn Gateway::simulate_product_service_call(
  _self : Gateway,
  request : Request
) -> Response raise {
  @async.sleep(30)  // 模拟网络延迟
  { status: 200, body: "Product data for \{request.path}" }
}

///|
/// 批量处理请求（展示并发处理）
pub async fn Gateway::handle_batch_requests(
  self : Gateway,
  requests : Array[Request]
) -> Array[Response] raise {
  @async.with_task_group(fn(group) {
    let tasks = Array::new()
    
    // 并发发起所有请求（受 limiter 限制）
    for request in requests {
      tasks.push(group.spawn(fn() {
        self.handle_request(request)
      }))
    }
    
    // 收集所有结果
    let responses = Array::new()
    for task in tasks {
      responses.push(task.wait())
    }
    responses
  })
}

///|
/// 获取网关统计信息
pub fn Gateway::get_stats(self : Gateway) -> String {
  let success_rate = if self.total_requests == 0 {
    100
  } else {
    self.successful_requests * 100 / self.total_requests
  }
  
  "Total: \{self.total_requests}, Success: \{self.successful_requests}, Failed: \{self.failed_requests}, Rate: \{success_rate}%"
}

