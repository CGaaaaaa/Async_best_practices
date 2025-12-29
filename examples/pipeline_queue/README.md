## examples/pipeline_queue 鈥?鐢熶骇鑰?娑堣垂鑰呮祦姘寸嚎

> **鎺ㄨ崘闃呰椤哄簭锛氱 5 涓?*锛堢悊瑙ｉ槦鍒椾笌鑳屽帇锛?
---

## 鏍稿績鐭ヨ瘑鐐?
- 鉁?**鐢熶骇鑰?娑堣垂鑰呮ā寮?*锛氱敤 `aqueue.Queue` 瑙ｈ€︾敓浜т笌娑堣垂
- 鉁?**骞惰娑堣垂**锛氬涓?worker 骞惰澶勭悊鏁版嵁
- 鉁?**鑳屽帇鏈哄埗**锛氱敤 Semaphore 鎺у埗闃熷垪澶у皬锛堥槻姝㈠唴瀛樼垎鐐革級

---

## 蹇€熻繍琛?
```bash
cd examples/pipeline_queue
moon test --target native
```

---

## 鍏抽敭浠ｇ爜

```moonbit
pub async fn pipeline_sum(n_items : Int, workers : Int) -> Int {
  @async.with_task_group(fn(group) {
    let q = @aqueue.Queue::new()  // 鉁?鍒涘缓闃熷垪

    // Producer锛氱敓浜?1..n_items
    group.spawn_bg(fn() {
      for i in 1..(n_items + 1) {
        q.put(i)
      }
      // 鍙戦€佺粓姝俊鍙?      for _ in 0..<workers {
        q.put(0)  // 0 琛ㄧず缁撴潫
      }
    })

    // Consumers锛氬涓?worker 骞惰娑堣垂
    let tasks = Array::new()
    for _ in 0..<workers {
      tasks.push(group.spawn(fn() -> Int raise {
        let mut acc = 0
        for {
          let v = q.get()  // 鉁?闃诲鑾峰彇鏁版嵁
          guard v != 0 else { break }  // 鏀跺埌缁堟淇″彿
          acc = acc + v
        }
        acc
      }))
    }

    // Aggregate锛氭眹鎬绘墍鏈?worker 鐨勭粨鏋?    let mut sum = 0
    for task in tasks {
      sum = sum + task.wait()
    }
    sum
  })
}
```

**瑕佺偣**锛?- `q.put(item)` 鏀惧叆鏁版嵁锛堥潪闃诲锛?- `q.get()` 闃诲鑾峰彇鏁版嵁
- 鐢ㄧ壒娈婂€硷紙0锛変綔涓虹粓姝俊鍙?- 澶氫釜 worker 骞惰娑堣垂锛屾彁鍗囧悶鍚愰噺

**鐪熷疄鍦烘櫙**锛?- 鐖櫕鎶撳彇 URL锛屽涓?worker 骞惰瑙ｆ瀽鍐呭
- 鏃ュ織鏀堕泦锛屽涓?worker 骞惰鍐欏叆 DB
- 鍥剧墖澶勭悊锛屽涓?worker 骞惰鍘嬬缉/涓婁紶

**鈿狅笍 娉ㄦ剰**锛歚aqueue.Queue` 鏄棤鐣岀紦鍐诧紝鐢熶骇閫熷害 > 娑堣垂閫熷害鏃朵細瀵艰嚧鍐呭瓨澧為暱銆傚疄闄呴」鐩腑闇€瑕佺敤 Semaphore 鎺у埗闃熷垪澶у皬銆?
---

## 瀛﹀埌浜嗕粈涔堬紵

1. **瑙ｈ€︾敓浜т笌娑堣垂**锛氱敓浜ц€呬笉闇€瑕佺瓑寰呮秷璐硅€呭鐞嗗畬
2. **骞惰澶勭悊**锛氬涓?worker 骞惰娑堣垂锛屾彁鍗囧悶鍚愰噺
3. **鑳屽帇鎺у埗**锛氱敤 Semaphore 闃叉闃熷垪鏃犻檺澧為暱

---

## 涓嬩竴姝?
- 缁х画瀛︿範 [`examples/api-gateway`](../api-gateway/README.md)锛堢患鍚堢湡瀹炴渚嬶級
- 鍙傝€?[`docs/quick-reference.md`](../../docs/quick-reference.md) 鏌ョ湅 Queue API
- 鏌ョ湅 [`docs/best_practices.md`](../../docs/best_practices.md) 浜嗚В闃熷垪鏈€浣冲疄璺?
