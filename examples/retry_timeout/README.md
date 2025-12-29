## examples/retry_timeout 鈥?瓒呮椂涓庨噸璇曠瓥鐣?
> **鎺ㄨ崘闃呰椤哄簭锛氱 3 涓?*锛堢悊瑙ｇ瓥鐣ュ皝瑁咃級

---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**缁熶竴瓒呮椂灏佽**锛氭墍鏈夊閮ㄨ皟鐢ㄩ兘閫氳繃 `infra` 璁剧疆瓒呮椂
- 鉁?**閲嶈瘯绛栫暐**锛氬尯鍒嗙灛鎬佸け璐ワ紙鍙噸璇曪級涓庨€昏緫閿欒锛堜笉鍙噸璇曪級
- 鉁?**閿欒褰掍竴鍖?*锛氳繑鍥?`Result[X, String]`锛屼笟鍔″眰缁熶竴澶勭悊

---

## 蹇€熻繍琛?
```bash
cd examples/retry_timeout
moon test --target native
```

---

## 鍏抽敭浠ｇ爜

### 鍦烘櫙 1锛氭搷浣滄垚鍔?
```moonbit
pub async fn demo_retry_timeout_success() -> String {
  let result = @infra.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(100)  // 妯℃嫙鎿嶄綔鑰楁椂 100ms
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

### 鍦烘櫙 2锛氭搷浣滆秴鏃?
```moonbit
pub async fn demo_retry_timeout_fail() -> String {
  let result = @infra.call_with_timeout_and_retry(
    50,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      @async.sleep(200)  // 鎿嶄綔鑰楁椂 200ms锛岃秴鏃?50ms
      "Operation successful"
    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

### 鍦烘櫙 3锛氱灛鎬佸け璐ュ悗閲嶈瘯鎴愬姛

```moonbit
pub async fn demo_retry_timeout_transient_success() -> String {
  let mut attempts = 0
  let result = @infra.call_with_timeout_and_retry(
    1000,
    @async.ExponentialDelay(initial=100, factor=2, maximum=1000),
    fn() {
      attempts = attempts + 1
      if attempts < 3 {
        raise Failure("Transient error")  // 鍓?2 娆″け璐?      }
      "Operation successful after retry"  // 绗?3 娆℃垚鍔?    }
  )
  
  match result {
    Ok(s) => s
    Err(e) => "Error: \{e}"
  }
}
```

**瑕佺偣**锛?- 瓒呮椂淇濇姢閬垮厤鏃犵晫绛夊緟
- 閲嶈瘯鍙敤浜庣灛鎬侀敊璇紙缃戠粶鎶栧姩銆佹湇鍔¤繃杞斤級
- 閫昏緫閿欒锛堝弬鏁伴敊璇€佹潈闄愰敊璇級涓嶅簲璇ラ噸璇?
---

## 瀛﹀埌浜嗕粈涔堬紵

1. **绛栫暐缁熶竴**锛氳秴鏃?閲嶈瘯绛栫暐鍦?`infra/` 灞傜粺涓€灏佽
2. **閿欒鍖哄垎**锛氭槑纭尯鍒嗙灛鎬侀敊璇紙鍙噸璇曪級涓庨€昏緫閿欒锛堜笉鍙噸璇曪級
3. **娴嬭瘯瑕嗙洊**锛氳鐩栨垚鍔?瓒呮椂/鐬€佸け璐ヤ笁绉嶅満鏅?
---

## 涓嬩竴姝?
- 鏌ョ湅 [`infra/README.md`](../../infra/README.md) 浜嗚В infra 灞傚疄鐜?- 缁х画瀛︿範 [`examples/semaphore_limiter`](../semaphore_limiter/README.md)锛堝苟鍙戦檺娴侊級
- 鍙傝€?[`docs/faq.md`](../../docs/faq.md) 浜嗚В瓒呮椂/閲嶈瘯甯歌闂
