## examples/api-gateway 鈥?缁煎悎鐪熷疄妗堜緥锛欰PI 缃戝叧

> **鎺ㄨ崘闃呰椤哄簭锛氬畬鎴愬叾浠栫ず渚嬪悗**锛堢患鍚堝簲鐢級

---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**缁煎悎搴旂敤**锛歍askGroup + Semaphore + 瓒呮椂 + 閲嶈瘯 + infra 灞?- 鉁?**鐪熷疄鍦烘櫙**锛欰PI 缃戝叧鐨勮矾鐢便€侀檺娴併€佺啍鏂€佸仴搴锋鏌?- 鉁?**骞跺彂澶勭悊**锛氭壒閲忚姹傚苟琛屽鐞?- 鉁?**鍚庡彴浠诲姟**锛氭棩蹇楄褰曚笉闃诲涓绘祦绋?- 鉁?**缁熻鐩戞帶**锛氳姹傝鏁般€佹垚鍔熺巼缁熻

---

## 蹇€熻繍琛?
```bash
cd examples/api-gateway
moon test --target native
```

---

## 鍔熻兘娓呭崟

| 鍔熻兘 | 瀹炵幇鏂瑰紡 | Async 妯″紡 |
|------|---------|-----------|
| **璺敱杞彂** | 鏍规嵁璺緞鍒嗗彂鍒颁笉鍚屽悗绔?| TaskGroup |
| **骞跺彂闄愭祦** | 鏈€澶у苟鍙戣姹傛暟鎺у埗 | Semaphore |
| **瓒呮椂淇濇姢** | 缁熶竴璇锋眰瓒呮椂 | with_timeout_opt |
| **閲嶈瘯鏈哄埗** | 鐬€佸け璐ヨ嚜鍔ㄩ噸璇?| infra 灞傚皝瑁?|
| **鏃ュ織璁板綍** | 鍚庡彴寮傛鏃ュ織 | spawn_bg |
| **鎵归噺澶勭悊** | 骞惰澶勭悊澶氫釜璇锋眰 | TaskGroup + spawn |
| **鍋ュ悍妫€鏌?* | 鎴愬姛鐜囩粺璁?| 鐘舵€佺鐞?|

---

## 鍏抽敭浠ｇ爜

### 璇锋眰澶勭悊娴佺▼锛堢患鍚堟ā寮忥級

```moonbit
pub async fn Gateway::handle_request(
  self : Gateway,
  request : Request
) -> Response raise {
  self.total_requests = self.total_requests + 1
  
  // 鉁?妯″紡 1锛氶檺娴侊紙Semaphore锛?  self.limiter.acquire()
  
  // 鉁?妯″紡 2锛氱粨鏋勫寲骞跺彂锛圱askGroup锛?  @async.with_task_group(fn(group) {
    // 涓讳换鍔★細澶勭悊璇锋眰
    let response_task = group.spawn(fn() {
      self.handle_request_internal(request)
    })
    
    // 鉁?妯″紡 3锛氬悗鍙颁换鍔★紙spawn_bg锛?    group.spawn_bg(fn() {
      self.log_request(request)  // 鏃ュ織涓嶉樆濉炰富娴佺▼
    })
    
    // 绛夊緟涓讳换鍔?+ 閲婃斁璧勬簮
    let response = response_task.wait()
    self.limiter.release()
    response
  })
}
```

### 璺敱 + 瓒呮椂 + 閲嶈瘯

```moonbit
async fn Gateway::handle_request_internal(
  self : Gateway,
  request : Request
) -> Response raise {
  // 鉁?缁熶竴瓒呮椂
  let result = @async.with_timeout_opt(self.config.request_timeout_ms, fn() {
    // 鉁?璺敱鍒嗗彂
    match request.path {
      "/api/users" => self.call_user_service(request)
      "/api/orders" => self.call_order_service(request)
      "/api/products" => self.call_product_service(request)
      "/health" => self.health_check()
      _ => Response::new(404, "Not Found")
    }
  })
  
  match result {
    Some(response) => {
      self.successful_requests = self.successful_requests + 1
      response
    }
    None => {
      self.failed_requests = self.failed_requests + 1
      Response::new(504, "Gateway Timeout")
    }
  }
}
```

### 鎵归噺澶勭悊锛堝苟鍙戜紭鍖栵級

```moonbit
pub async fn Gateway::handle_batch_requests(
  self : Gateway,
  requests : Array[Request]
) -> Array[Response] raise {
  @async.with_task_group(fn(group) {
    // 鉁?骞惰鍙戣捣鎵€鏈夎姹傦紙鍙?limiter 闄愬埗锛?    let tasks = Array::new()
    for request in requests {
      tasks.push(group.spawn(fn() {
        self.handle_request(request)
      }))
    }
    
    // 鏀堕泦鎵€鏈夌粨鏋?    let responses = Array::new()
    for task in tasks {
      responses.push(task.wait())
    }
    responses
  })
}
```

---

## 瀛﹀埌浜嗕粈涔堬紵

1. **缁煎悎搴旂敤澶氫釜 Async 妯″紡**锛歍askGroup + Semaphore + 瓒呮椂 + 閲嶈瘯
2. **鐪熷疄鍦烘櫙鐨勬灦鏋勮璁?*锛氳矾鐢卞眰銆佽秴鏃跺眰銆侀噸璇曞眰鐨勮亴璐ｅ垎绂?3. **鎬ц兘浼樺寲鎶€宸?*锛氭壒閲忓鐞嗗苟琛屽寲锛屽悗鍙颁换鍔′笉闃诲涓绘祦绋?4. **鐢熶骇绾т唬鐮佽川閲?*锛氬畬鏁寸殑閿欒澶勭悊銆佸彲閰嶇疆鐨勮涓恒€佸叏闈㈢殑娴嬭瘯瑕嗙洊

---

## 涓嬩竴姝?
- 鍙傝€?[`docs/best_practices.md`](../../docs/best_practices.md) 鐨?PR 妫€鏌ユ竻鍗曞鏌ヤ唬鐮?- 鏌ョ湅 [`docs/quick-reference.md`](../../docs/quick-reference.md) 蹇€熸煡闃?API
- 搴旂敤鍒颁綘鐨勯」鐩細鎶婅繖浜涙ā寮忚縼绉诲埌鐪熷疄涓氬姟鍦烘櫙

---

**杩欐槸鏈粨搴撴渶澶嶆潅鐨勭ず渚嬶紝灞曠ず浜嗙敓浜х骇 Async 浠ｇ爜鐨勫畬鏁村舰鎬侊紒** 馃帀
