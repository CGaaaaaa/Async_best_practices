## src/ 鈥?涓绘暀瀛﹀寘锛堝畬鏁?API 绱㈠紩锛?
> `src/` 鐩綍鎻愪緵**绯荤粺鍖栫殑 Async 绀轰緥**锛氱敤涓€浠界浉瀵归泦涓殑浠ｇ爜锛岃鐩栨洿澶?API 涓庣粍鍚堟ā寮忥紝骞剁敤澶ч噺 `async test` 鍋氬彲杩愯楠岃瘉銆?
---

## 杩欎釜鍖呮槸浠€涔堬紵

`src/` 鏄湰浠撳簱鐨?*"API 鎵嬪唽"**锛?- **鍔熻兘鐩綍寮?*锛氭瘡涓?Async API 閮芥湁瀵瑰簲鐨勭ず渚嬪嚱鏁?- **鍙繍琛岄獙璇?*锛氭墍鏈夌ず渚嬮兘閰嶅 `async test`锛岃繍琛?`moon test` 鍗冲彲楠岃瘉琛屼负
- **蹇€熸煡闃?*锛氶渶瑕?鎬庝箞鐢?`with_timeout_opt`"鏃讹紝鐩存帴鎼滅储 `demo_with_timeout_opt`

涓?`examples/` 鐨勫尯鍒細
- `examples/`锛?*涓氬姟鍦烘櫙**锛屽睍绀哄浣曠粍鍚堝涓?API锛堥€傚悎"瀛︿範濡備綍鍐欑湡瀹炰唬鐮?锛?- `src/`锛?*API 鎵嬪唽**锛岀郴缁熷寲瑕嗙洊鎵€鏈夊師璇紙閫傚悎"鏌ユ壘鏌愪釜 API 鎬庝箞鐢?锛?
---

## 寤鸿鐢ㄦ硶

### 鍦烘櫙 A锛氬揩閫熶笂鎵嬩笟鍔″啓娉?
**浼樺厛鐪?`examples/` + `infra/`**
1. `examples/checkout`锛?0 鍒嗛挓锛?2. `examples/task_group`锛?0 鍒嗛挓锛?3. `examples/retry_timeout`锛?0 鍒嗛挓锛?
### 鍦烘櫙 B锛氱郴缁熷涔?Async API

**鎸?`src/Async_best_practices.mbt` 鐨勭ず渚嬬珷鑺傞『搴忛槄璇?*
1. 杩愯 `moon test --target native src/`
2. 瀵圭収杈撳嚭鐞嗚В姣忎釜 API 鐨勮涓?3. 淇敼绀轰緥浠ｇ爜锛岃瀵熺粨鏋滃彉鍖?
### 鍦烘櫙 C锛氭煡鎵炬煇涓?API 鐨勭敤娉?
**鐢ㄦ湰鏂囨。鐨?API 绱㈠紩蹇€熷畾浣?*
- 闇€瑕佽秴鏃讹紵鈫?鏌ラ槄 `demo_with_timeout` / `demo_with_timeout_opt`
- 闇€瑕侀噸璇曪紵鈫?鏌ラ槄 `demo_retry_fixed_delay` / `demo_retry_exponential`
- 闇€瑕侀檺娴侊紵鈫?鏌ラ槄 `demo_semaphore` / `demo_try_acquire`

---

## 瀹屾暣 API 绱㈠紩

### 鍩虹寮傛鎿嶄綔

#### 1. `hello_async` 鈥?鍩烘湰瓒呮椂

```moonbit
pub async fn hello_async() -> String
```

**鍔熻兘**锛氭紨绀哄熀鏈殑瓒呮椂鍔熻兘

**鍏抽敭 API**锛?- `@async.with_timeout_opt(timeout_ms, fn() { ... })`锛氳秴鏃惰繑鍥?`None`

**娴嬭瘯**锛?```moonbit
async test "hello_async_test" {
  let result = hello_async()
  inspect(result, content=(#|Hello, Async with timeout!|))
}
```

**瀛︿範閲嶇偣**锛?- 鐞嗚В `with_timeout_opt` 鐨勫熀鏈敤娉?- 瓒呮椂鏃惰繑鍥?`None`锛屼笉鎶涘嚭寮傚父

---

#### 2. `concurrent_tasks` 鈥?骞跺彂鎵ц澶氫釜浠诲姟

```moonbit
pub async fn concurrent_tasks() -> Array[Int]
```

**鍔熻兘**锛氭紨绀?`TaskGroup` 鐨勭敤娉曪紝骞跺彂鎵ц澶氫釜浠诲姟

**鍏抽敭 API**锛?- `@async.with_task_group(fn(group) { ... })`锛氬垱寤轰换鍔＄粍
- `group.spawn(fn() { ... })`锛氬垱寤哄瓙浠诲姟
- `task.wait()`锛氱瓑寰呬换鍔″畬鎴?
**娴嬭瘯**锛?```moonbit
async test "concurrent_tasks_test" {
  let results = concurrent_tasks()
  inspect(results, content=(#|[1, 2, 3]|))
}
```

**瀛︿範閲嶇偣**锛?- 鐢?`TaskGroup` 绠＄悊骞跺彂浠诲姟
- 鎵€鏈変换鍔￠兘鍦?group 鍐咃紝鐢熷懡鍛ㄦ湡鍙帶

---

#### 3. `timeout_example` 鈥?瓒呮椂澶勭悊

```moonbit
pub async fn timeout_example() -> String
```

**鍔熻兘**锛氭紨绀鸿秴鏃跺満鏅紙浠诲姟鑰楁椂瓒呰繃瓒呮椂鏃堕棿锛?
**鍏抽敭 API**锛?- `@async.with_timeout_opt(timeout_ms, fn() { ... })`
- `@async.sleep(ms)`锛氭ā鎷熻€楁椂鎿嶄綔

**娴嬭瘯**锛?```moonbit
async test "timeout_example_test" {
  let result = timeout_example()
  inspect(result, content=(#|Operation timed out|))
}
```

**瀛︿範閲嶇偣**锛?- 瓒呮椂鏃惰繑鍥?`None`
- 涓氬姟灞傚彲浠ユ牴鎹?`None` 鍋氶檷绾у鐞?
---

### 楂樼骇骞跺彂妯″紡

#### 4. `sequential_pipeline` 鈥?椤哄簭娴佹按绾?
```moonbit
pub async fn sequential_pipeline() -> Int
```

**鍔熻兘**锛氶『搴忔墽琛屽紓姝ユ搷浣滐紝鏋勫缓鏁版嵁澶勭悊娴佹按绾?
**鍏抽敭 API**锛?- 閾惧紡璋冪敤澶氫釜 `async fn`

**娴嬭瘯**锛?```moonbit
async test "sequential_pipeline_test" {
  let result = sequential_pipeline()
  inspect(result, content=(#|30|))
}
```

**瀛︿範閲嶇偣**锛?- 寮傛鎿嶄綔鍙互椤哄簭缁勫悎
- 姣忎竴姝ョ殑杈撳嚭鏄笅涓€姝ョ殑杈撳叆

---

#### 5. `race_example` 鈥?绔炰簤鍦烘櫙

```moonbit
pub async fn race_example() -> String
```

**鍔熻兘**锛氭紨绀哄涓换鍔＄珵浜夛紝绗竴涓畬鎴愯€呰儨鍑?
**鍏抽敭 API**锛?- `group.spawn(...)`锛氬垱寤哄涓换鍔?- 鐢?`@ref.new(...)` 璁板綍绗竴涓畬鎴愮殑浠诲姟

**娴嬭瘯**锛?```moonbit
async test "race_example_test" {
  let result = race_example()
  inspect(result, content=(#|Task 1 wins|))
}
```

**瀛︿範閲嶇偣**锛?- 澶氫釜浠诲姟骞跺彂锛屽彧鍏冲績绗竴涓畬鎴愮殑
- 閫傜敤鍦烘櫙锛氬涓暟鎹簮鏌ヨ锛岃繑鍥炴渶蹇殑缁撴灉

---

### 閿欒澶勭悊涓庨噸璇?
#### 6. `retry_example` 鈥?閲嶈瘯鏈哄埗

```moonbit
pub async fn retry_example() -> Result[String, String]
```

**鍔熻兘**锛氭紨绀虹灛鎬佸け璐ョ殑閲嶈瘯鏈哄埗

**鍏抽敭 API**锛?- `@async.retry(strategy, fn() { ... })`锛氳嚜鍔ㄩ噸璇?- `ExponentialDelay(initial, factor, maximum)`锛氭寚鏁伴€€閬?
**娴嬭瘯**锛?```moonbit
async test "retry_example_test" {
  let result = retry_example()
  inspect(result, content=(#|Ok("Success after retries")|))
}
```

**瀛︿範閲嶇偣**锛?- 鐬€佸け璐ュ彲浠ラ噸璇曪紙缃戠粶鎶栧姩銆佹湇鍔¤繃杞斤級
- 鐢ㄦ寚鏁伴€€閬块伩鍏嶉洩宕?
---

#### 7. `error_handling_example` 鈥?閿欒澶勭悊涓庡彇娑堜紶鎾?
```moonbit
pub async fn error_handling_example() -> String
```

**鍔熻兘**锛氭紨绀哄紓姝ヤ换鍔′腑鐨勯敊璇鐞嗕笌鍙栨秷浼犳挱

**鍏抽敭 API**锛?- `try...catch`锛氭崟鑾峰紓甯?- `TaskGroup` 鐨?fail-fast 鍙栨秷

**娴嬭瘯**锛?```moonbit
async test "error_handling_example_test" {
  let result = error_handling_example()
  inspect(result, content=(#|Error: Task failed|))
}
```

**瀛︿範閲嶇偣**锛?- 浠诲姟澶辫触鏃讹紝鍏勫紵浠诲姟琚嚜鍔ㄥ彇娑?- 鐢?`catch` 澶勭悊寮傚父

---

### 鎵归噺澶勭悊涓庡苟鍙戞帶鍒?
#### 8. `batch_processing` 鈥?鎵归噺澶勭悊浠诲姟

```moonbit
pub async fn batch_processing() -> Array[Int]
```

**鍔熻兘**锛氭紨绀烘壒閲忓鐞嗕换鍔★紝缁撳悎骞跺彂涓庨檺娴?
**鍏抽敭 API**锛?- `TaskGroup` + `Semaphore` 闄愭祦

**娴嬭瘯**锛?```moonbit
async test "batch_processing_test" {
  let results = batch_processing()
  inspect(results, content=(#|[2, 4, 6, 8, 10]|))
}
```

**瀛︿範閲嶇偣**锛?- 鎵归噺浠诲姟闇€瑕侀檺娴侊紝閬垮厤璧勬簮鑰楀敖
- 鐢?Semaphore 鎺у埗鏈€澶у苟鍙?
---

### TaskGroup 璇︾粏绀轰緥

#### 9. `demo_spawn` 鈥?TaskGroup.spawn 鍜?spawn_bg

```moonbit
pub async fn demo_spawn() -> String
```

**鍔熻兘**锛氭紨绀?`spawn` 鍜?`spawn_bg` 鐨勫尯鍒?
**鍏抽敭 API**锛?- `group.spawn(fn() { ... })`锛氬叧閿换鍔★紙澶辫触浼氬彇娑?group锛?- `group.spawn_bg(fn() { ... })`锛氬悗鍙颁换鍔★紙澶辫触涓嶅奖鍝?group锛?
**娴嬭瘯**锛?```moonbit
async test "demo_spawn_test" {
  let result = demo_spawn()
  inspect(result, content=(...))
}
```

**瀛︿範閲嶇偣**锛?- `spawn`锛氬叧閿换鍔★紝fail-fast
- `spawn_bg`锛氬悗鍙颁换鍔★紝鍏佽澶辫触

---

### 瓒呮椂璇︾粏绀轰緥

#### 10. `demo_with_timeout` 鈥?with_timeout锛堟姏鍑哄紓甯革級

```moonbit
pub async fn demo_with_timeout() -> String
```

**鍔熻兘**锛氭紨绀?`with_timeout` 瓒呮椂鏃舵姏鍑?`Failure`

**鍏抽敭 API**锛?- `@async.with_timeout(timeout_ms, fn() { ... })`锛氳秴鏃舵姏鍑哄紓甯?
**瀛︿範閲嶇偣**锛?- 瓒呮椂鏃朵細鍙栨秷鐖朵换鍔?- 閫傜敤鍦烘櫙锛氳秴鏃跺嵆澶辫触鐨勫叧閿搷浣?
---

#### 11. `demo_with_timeout_opt` 鈥?with_timeout_opt锛堣繑鍥?Option锛?
```moonbit
pub async fn demo_with_timeout_opt() -> String
```

**鍔熻兘**锛氭紨绀?`with_timeout_opt` 瓒呮椂鏃惰繑鍥?`None`

**鍏抽敭 API**锛?- `@async.with_timeout_opt(timeout_ms, fn() { ... })`锛氳秴鏃惰繑鍥?`None`

**瀛︿範閲嶇偣**锛?- 瓒呮椂鏃朵笉褰卞搷鐖朵换鍔?- 閫傜敤鍦烘櫙锛氳秴鏃跺悗闇€瑕侀檷绾у鐞?
---

### Semaphore 璇︾粏绀轰緥

#### 12. `demo_semaphore` 鈥?Semaphore 闄愭祦

```moonbit
pub async fn demo_semaphore() -> String
```

**鍔熻兘**锛氭紨绀?Semaphore 闄愭祦锛屾帶鍒跺苟鍙戞暟

**鍏抽敭 API**锛?- `@semaphore.Semaphore::new(n)`锛氬垱寤轰俊鍙烽噺
- `semaphore.acquire()`锛氶樆濉炶幏鍙?- `semaphore.release()`锛氶噴鏀?
**瀛︿範閲嶇偣**锛?- 鐢?Semaphore 闄愬埗鏈€澶у苟鍙?- 淇濇姢澶栭儴渚濊禆锛圖B銆丄PI锛?
---

#### 13. `demo_semaphore_try_acquire` 鈥?闈為樆濉炶幏鍙?
```moonbit
pub async fn demo_semaphore_try_acquire() -> String
```

**鍔熻兘**锛氭紨绀?`try_acquire` 闈為樆濉炶幏鍙?
**鍏抽敭 API**锛?- `semaphore.try_acquire()`锛氱珛鍗宠繑鍥?`Option`

**瀛︿範閲嶇偣**锛?- 闈為樆濉炶幏鍙栵紝閫傜敤浜庡彲闄嶇骇鍦烘櫙
- 绻佸繖鏃跺揩閫熷け璐?
---

### 鍏抽敭鍖轰繚鎶?
#### 14. `demo_protect_from_cancel` 鈥?闃插彇娑堝叧閿尯

```moonbit
pub async fn demo_protect_from_cancel() -> String
```

**鍔熻兘**锛氭紨绀?`protect_from_cancel` 淇濇姢涓嶅彲涓柇鎿嶄綔

**鍏抽敭 API**锛?- `@async.protect_from_cancel(fn() { ... })`

**瀛︿範閲嶇偣**锛?- 鍙湪"涓嶅彲涓柇鐨勫叧閿尯"浣跨敤
- 渚嬪锛欴B 浜嬪姟銆佹枃浠跺啓鍏?
---

### 閲嶈瘯璇︾粏绀轰緥

#### 15. `demo_retry_fixed_delay` 鈥?鍥哄畾寤惰繜閲嶈瘯

```moonbit
pub async fn demo_retry_fixed_delay() -> String
```

**鍔熻兘**锛氭紨绀哄浐瀹氬欢杩熼噸璇曠瓥鐣?
**鍏抽敭 API**锛?- `@async.retry(FixedDelay(delay, max_retry), fn() { ... })`

**瀛︿範閲嶇偣**锛?- 姣忔閲嶈瘯闂撮殧鍥哄畾
- 閫傜敤浜庡揩閫熺灛鎬佸け璐?
---

#### 16. `demo_retry_exponential` 鈥?鎸囨暟閫€閬块噸璇?
```moonbit
pub async fn demo_retry_exponential() -> String
```

**鍔熻兘**锛氭紨绀烘寚鏁伴€€閬块噸璇曠瓥鐣?
**鍏抽敭 API**锛?- `@async.retry(ExponentialDelay(initial, factor, maximum), fn() { ... })`

**瀛︿範閲嶇偣**锛?- 閲嶈瘯闂撮殧鎸囨暟澧為暱
- 閫傜敤浜庢湇鍔¤繃杞藉満鏅?
---

### 闃熷垪涓庢祦姘寸嚎

#### 17. `demo_queue_pipeline` 鈥?闃熷垪娴佹按绾?
```moonbit
pub async fn demo_queue_pipeline() -> String
```

**鍔熻兘**锛氭紨绀?aqueue 鐢熶骇鑰?娑堣垂鑰呮祦姘寸嚎

**鍏抽敭 API**锛?- `@aqueue.Queue::new()`锛氬垱寤洪槦鍒?- `queue.put(item)`锛氭斁鍏ユ暟鎹?- `queue.get()`锛氬彇鍑烘暟鎹?
**瀛︿範閲嶇偣**锛?- 瑙ｈ€︾敓浜т笌娑堣垂
- 澶?worker 骞惰澶勭悊

---

## 杩愯涓庢祴璇?
### 杩愯鎵€鏈夋祴璇?
```bash
cd /path/to/Async_best_practices
moon test --target native src/
```

**棰勬湡杈撳嚭**锛?```
Total tests: 33, passed: 33, failed: 0.
```

### 杩愯鍗曚釜娴嬭瘯

```bash
moon test --target native src/ -f hello_async_test
```

---

## 濡備綍寮曞叆鍒颁綘鐨勯」鐩?
濡傛灉浣犳兂鍦ㄨ嚜宸辩殑椤圭洰涓紩鐢ㄨ繖涓寘锛堝涔犵敤锛夛細

### 鏂瑰紡 1锛氫綔涓轰緷璧栧紩鍏?
鍦ㄤ綘鐨?`moon.pkg.json` 涓細

```json
{
  "import": [
    "CGaaaaaa/async-best-practices/src"
  ]
}
```

鐒跺悗鍦ㄤ唬鐮佷腑锛?
```moonbit
let result = @src.hello_async()
```

### 鏂瑰紡 2锛氬鍒剁ず渚嬩唬鐮?
鐩存帴澶嶅埗 `src/Async_best_practices.mbt` 涓殑鍑芥暟鍒颁綘鐨勯」鐩紝淇敼涓虹湡瀹炰笟鍔￠€昏緫銆?
---

## 涓婚绱㈠紩锛堝揩閫熸煡鎵撅級

| 涓婚 | 绀轰緥鍑芥暟 | 鍏抽敭 API |
|------|---------|---------|
| **鍩虹瓒呮椂** | `hello_async`, `timeout_example` | `with_timeout_opt` |
| **骞跺彂浠诲姟** | `concurrent_tasks`, `demo_spawn` | `TaskGroup`, `spawn` |
| **瓒呮椂瀵规瘮** | `demo_with_timeout`, `demo_with_timeout_opt` | `with_timeout` vs `with_timeout_opt` |
| **閲嶈瘯绛栫暐** | `retry_example`, `demo_retry_fixed_delay`, `demo_retry_exponential` | `retry`, `ExponentialDelay` |
| **闄愭祦** | `demo_semaphore`, `demo_semaphore_try_acquire` | `Semaphore`, `acquire`, `try_acquire` |
| **鍏抽敭鍖?* | `demo_protect_from_cancel` | `protect_from_cancel` |
| **闃熷垪** | `demo_queue_pipeline` | `aqueue.Queue` |
| **閿欒澶勭悊** | `error_handling_example` | `try...catch` |
| **鎵归噺澶勭悊** | `batch_processing` | `TaskGroup` + `Semaphore` |

---

## 涓嬩竴姝?
1. **杩愯鎵€鏈夋祴璇?*锛歚moon test --target native src/`
2. **闃呰鎰熷叴瓒ｇ殑绀轰緥**锛氭寜涓婚绱㈠紩鏌ユ壘
3. **淇敼绀轰緥浠ｇ爜**锛氳瀵熻涓哄彉鍖?4. **瀵圭収 `examples/`**锛氱湅濡備綍鍦ㄤ笟鍔′腑缁勫悎杩欎簺 API

---

## 甯歌闂

### Q1锛氫负浠€涔堟湁杩欎箞澶氭祴璇曪紙33+锛夛紵

**A**锛氭瘡涓ず渚嬪嚱鏁伴兘閰嶅娴嬭瘯锛岀‘淇濓細
- 浠ｇ爜鍙繍琛岋紙涓嶆槸浼唬鐮侊級
- 琛屼负绗﹀悎棰勬湡锛堢敤 `inspect` 楠岃瘉杈撳嚭锛?- 淇敼浠撳簱鏃朵笉浼氱牬鍧忕ず渚?
### Q2锛歚src/` 鍜?`infra/` 鏈変粈涔堝叧绯伙紵

**A**锛?- `src/`锛氬睍绀?Async API 鐨?鍘熷瓙鑳藉姏"锛堣秴鏃躲€侀噸璇曘€侀檺娴侊級
- `infra/`锛氭妸杩欎簺鑳藉姏缁勫悎鎴?涓氬姟鍙敤鐨?wrapper"锛坄call_with_timeout_and_retry`锛?
### Q3锛氫负浠€涔堣鍒?`src/` 鍜?`examples/`锛?
**A**锛?- `src/`锛?*API 鎵嬪唽**锛岀郴缁熷寲瑕嗙洊鎵€鏈夊師璇紙閫傚悎"鏌ユ壘 API"锛?- `examples/`锛?*涓氬姟鍦烘櫙**锛屽睍绀哄浣曠粍鍚?API锛堥€傚悎"瀛︿範鍐欎唬鐮?锛?
### Q4锛氬浣曡础鐚柊绀轰緥锛?
**A**锛?1. 鍦?`src/Async_best_practices.mbt` 涓坊鍔犳柊鍑芥暟
2. 鍦?`src/Async_best_practices_test.mbt` 涓坊鍔犳祴璇?3. 鏇存柊鏈?`README.md` 鐨?API 绱㈠紩
4. 鎻愪氦 PR

---

**Happy Learning! 鎺㈢储 MoonBit Async 鐨勬墍鏈夎兘鍔涳紒** 馃殌
