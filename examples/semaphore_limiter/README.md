## examples/semaphore_limiter 鈥?骞跺彂闄愭祦涓庤祫婧愭帶鍒?
> **鎺ㄨ崘闃呰椤哄簭锛氱 4 涓?*锛堢悊瑙ｅ苟鍙戞帶鍒讹級

---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**骞跺彂闄愭祦**锛氱敤 `Semaphore` 闄愬埗鏈€澶у苟鍙戞暟
- 鉁?**璧勬簮淇濇姢**锛氶槻姝?DB 杩炴帴姹犮€丄PI 璋冪敤琚墦鐖?- 鉁?**鑳屽帇鏈哄埗**锛氫换鍔¤嚜鍔ㄧ瓑寰咃紝涓嶄細鏃犻檺鍫嗙Н

---

## 蹇€熻繍琛?
```bash
cd examples/semaphore_limiter
moon test --target native
```

---

## 鍏抽敭浠ｇ爜

```moonbit
pub async fn demo_semaphore_limiter() -> String {
  let log = StringBuilder::new()
  
  @async.with_task_group(fn(group) {
    let semaphore = @semaphore.Semaphore::new(2)  // 鉁?鏈€澶у苟鍙?2
    
    // 鍒涘缓 5 涓换鍔★紝浣嗘渶澶氬悓鏃惰繍琛?2 涓?    for i in 0..<5 {
      group.spawn_bg(fn() raise {
        semaphore.acquire()  // 闃诲绛夊緟妲戒綅
        log.write_string("Task \{i} acquired semaphore\n")
        
        @async.sleep(100)  // 妯℃嫙宸ヤ綔
        
        semaphore.release()
        log.write_string("Task \{i} released semaphore\n")
      })
    }
    
    @async.sleep(500)  // 绛夊緟鎵€鏈変换鍔″畬鎴?  })
  
  log.to_string()
}
```

**瑕佺偣**锛?- `Semaphore::new(2)` 琛ㄧず鏈€澶?2 涓苟鍙?- `acquire()` 浼氶樆濉炵洿鍒版湁绌洪棽妲戒綅
- `release()` 閲婃斁妲戒綅锛岃绛夊緟鐨勪换鍔＄户缁?
**鐪熷疄鍦烘櫙**锛?- 鎵归噺澶勭悊 10000 涓鍗曪紝浣?DB 杩炴帴姹犲彧鏈?20 涓?- 璋冪敤绗笁鏂?API锛屽鏂归檺鍒?QPS 100
- CPU 瀵嗛泦浠诲姟锛堝浘鐗囧鐞嗭級锛岄伩鍏?CPU 100%

---

## 瀛﹀埌浜嗕粈涔堬紵

1. **璧勬簮淇濇姢**锛氶檺娴佷繚鎶ゅ閮ㄤ緷璧栵紙DB銆丄PI锛夊拰鑷韩璧勬簮锛圕PU銆佸唴瀛橈級
2. **鑷姩鎺掗槦**锛氫换鍔¤嚜鍔ㄧ瓑寰咃紝鏃犻渶鎵嬪姩绠＄悊闃熷垪
3. **瑙傛祴楠岃瘉**锛氶€氳繃鏃ュ織楠岃瘉鏈€澶у苟鍙戞暟纭疄琚檺鍒?
---

## 涓嬩竴姝?
- 缁х画瀛︿範 [`examples/pipeline_queue`](../pipeline_queue/README.md)锛堢敓浜ц€?娑堣垂鑰咃級
- 鍙傝€?[`docs/quick-reference.md`](../../docs/quick-reference.md) 鏌ョ湅 Semaphore API
- 鏌ョ湅 [`docs/faq.md`](../../docs/faq.md) 浜嗚В骞跺彂鎺у埗甯歌闂
