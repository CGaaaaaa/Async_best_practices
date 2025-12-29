## examples/task_group 鈥?缁撴瀯鍖栧苟鍙戜笌鍙栨秷浼犳挱

> **鎺ㄨ崘闃呰椤哄簭锛氱 2 涓?*锛堢悊瑙ｅ苟鍙戜换鍔＄鐞嗭級

---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**缁撴瀯鍖栧苟鍙?*锛氱敤 `TaskGroup` 绠＄悊浠诲姟鐢熷懡鍛ㄦ湡
- 鉁?**fail-fast 鍙栨秷浼犳挱**锛氫竴涓换鍔″け璐ユ椂锛岃嚜鍔ㄥ彇娑堝厔寮熶换鍔?- 鉁?**浠诲姟绛夊緟**锛氱敤 `wait()` 鑾峰彇浠诲姟缁撴灉

---

## 蹇€熻繍琛?
```bash
cd examples/task_group
moon test --target native
```

---

## 鍏抽敭浠ｇ爜

```moonbit
pub async fn demo_task_group() -> String {
  let log = StringBuilder::new()
  
  // 鉁?鐢?TaskGroup 绠＄悊骞跺彂浠诲姟
  ignore(
    @async.with_task_group(fn(group) {
      let task1 = group.spawn(fn() {
        @async.sleep(100)
        log.write_string("Task 1 finished\n")
        1
      })
      
      let task2 = group.spawn(fn() {
        @async.sleep(50)
        log.write_string("Task 2 failed\n")
        raise Failure("Task 2 error")  // 妯℃嫙澶辫触
        2
      })
      
      let task3 = group.spawn(fn() {
        @async.sleep(200)
        log.write_string("Task 3 finished\n")
        3
      })

      // 绛夊緟浠诲姟锛堝鏋滃叾涓竴涓け璐ワ紝鏁翠釜缁勪細鍙栨秷锛?      let res1 = task1.wait()
      let res3 = task3.wait()
      log.write_string("All tasks completed: \{res1}, \{res3}\n")
    })
  ) catch {
    err => log.write_string("TaskGroup failed: \{err}\n")
  }
  
  log.to_string()
}
```

**瑕佺偣**锛?- `group.spawn()` 鍒涘缓鍏抽敭浠诲姟锛堝け璐ヤ細鍙栨秷鍏勫紵浠诲姟锛?- `task.wait()` 绛夊緟浠诲姟瀹屾垚
- TaskGroup 閫€鍑烘椂鑷姩娓呯悊鎵€鏈夊瓙浠诲姟

---

## 瀛﹀埌浜嗕粈涔堬紵

1. **缁撴瀯鍖栧苟鍙?*锛氭墍鏈変换鍔￠兘鍦?TaskGroup 鍐咃紝鐢熷懡鍛ㄦ湡鍙帶
2. **fail-fast**锛氬叧閿换鍔″け璐ユ椂锛岃嚜鍔ㄥ彇娑堝叾浠栦换鍔?3. **璧勬簮绠＄悊**锛氱埗浠诲姟閫€鍑烘椂锛屽瓙浠诲姟鑷姩娓呯悊

---

## 涓嬩竴姝?
- 缁х画瀛︿範 [`examples/retry_timeout`](../retry_timeout/README.md)锛堣秴鏃?閲嶈瘯锛?- 鍙傝€?[`docs/quick-reference.md`](../../docs/quick-reference.md) 鏌ョ湅 TaskGroup API
- 鏌ョ湅 [`docs/faq.md`](../../docs/faq.md) 浜嗚В甯歌闂
