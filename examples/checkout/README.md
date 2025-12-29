## examples/checkout 鈥?鏈€灏忎笟鍔￠棴鐜ず渚?
> **鎺ㄨ崘闃呰椤哄簭锛氱 1 涓?*锛?0 鍒嗛挓涓婃墜锛?
---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**涓氬姟涓?infra 鍒嗗眰**锛氫笟鍔′唬鐮佸彧澶勭悊 `Result`锛岀瓥鐣ュ湪 `infra` 缁熶竴
- 鉁?**蹇収娴嬭瘯**锛氱敤 `inspect` 楠岃瘉瀹屾暣杈撳嚭
- 鉁?**閿欒澶勭悊**锛氬睍绀烘垚鍔?澶辫触涓ょ璺緞

---

## 蹇€熻繍琛?
```bash
cd examples/checkout
moon test --target native
```

---

## 鍏抽敭浠ｇ爜

### 涓氬姟灞傦紙checkout.mbt锛?
```moonbit
pub async fn checkout_orders(order_ids : Array[Int]) -> String {
  let log = StringBuilder::new()
  for id in order_ids {
    log.write_string("start order \{id}\n")
    
    // 鉁?涓氬姟灞傚彧璋冪敤 infra wrapper锛屼笉鍏冲績瓒呮椂/閲嶈瘯缁嗚妭
    let outcome = @infra.call_payment_with_retry(id)
    
    match outcome {
      Ok(_) => log.write_string("order \{id} success\n")
      Err(e) => log.write_string("order \{id} failed: \{e}\n")
    }
  }
  log.to_string()
}
```

**瑕佺偣**锛氫笟鍔′唬鐮佸彧琛ㄨ揪"澶勭悊璁㈠崟鍒楄〃锛岃褰曠粨鏋?锛岃秴鏃?閲嶈瘯绛栫暐閮藉湪 `infra/clients.mbt` 涓€?
### 娴嬭瘯锛坈heckout_test.mbt锛?
```moonbit
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
```

**瑕佺偣**锛氱敤 `inspect` 鍋氬揩鐓ф祴璇曪紝楠岃瘉瀹屾暣杈撳嚭銆?
---

## 瀛﹀埌浜嗕粈涔堬紵

1. **鑱岃矗鍒嗙**锛氫笟鍔″眰涓嶅叧蹇?鎬庝箞璋冪敤"锛屽彧澶勭悊 `Result`
2. **绛栫暐缁熶竴**锛氳秴鏃?閲嶈瘯绛栫暐鍦?`infra/` 灞傜粺涓€灏佽
3. **娴嬭瘯绠€鍗?*锛氬揩鐓ф祴璇曚竴鐪肩湅鎳傞鏈熻涓?
---

## 涓嬩竴姝?
- 鏌ョ湅 [`infra/README.md`](../../infra/README.md) 浜嗚В infra 灞傝璁?- 缁х画瀛︿範 [`examples/task_group`](../task_group/README.md)锛堢粨鏋勫寲骞跺彂锛?- 鍙傝€?[`docs/best_practices.md`](../../docs/best_practices.md) 浜嗚В瀹屾暣鍘熷垯
