# Performance Diagnostics

## 狀態

Planned

## 目的

量測 Motion Arcade 的端到端延遲、FPS 與感測器取樣穩定度，確保體感互動在展示時有足夠即時性與穩定性。

## 使用階段

Phase 8

## 輸入

- 手機端 motion event timestamp。
- 電腦端收到事件的 timestamp。
- 電腦端畫面顯示結果的 timestamp。
- Flutter frame timing。
- 感測器 sample stream。

## 輸出

- 端到端延遲。
- WebSocket 傳輸延遲。
- 畫面 FPS。
- Sensor sample rate。
- Debug overlay 或測試紀錄。

## 重要流程：Trail 卡頓判斷順序

遇到「軌跡卡、跳格、慢速小動作不跟手」時，不要先猜是網路。先用固定順序拆成三層：

```text
1. Controller 端送出量
   packets/s、samples/s 是否足夠？

2. Host 端收到量
   received packets/s、received samples/s、average arrival gap 是否正常？

3. Render 端畫面負載
   trail points、frame timing、CustomPainter 工作量是否過高？
```

判讀表：

| 現象 | 優先懷疑 | 處理方向 |
|---|---|---|
| 手機端 packets/s 在小幅旋轉時掉很低 | active/idle 判斷錯把旋轉當 idle | `MotionTrailStreamer` active 判斷必須包含 `rotationRate` 與 `tipX/tipY` 變化 |
| 手機端 packets/s 正常，主機端 packets/s 明顯較低 | 傳輸或 UDP 掉包 | 檢查 UDP 是否連上、是否 fallback 到 WebSocket、是否有 stale sequence drop |
| packets/s 正常但 samples/s 偏低 | downsample 或 batch 內容不足 | 降低 `downsampleRatio`，確認每包包含足夠 trail samples |
| 主機端 average arrival gap 接近 100-200ms | 發送 cadence 太慢或網路抖動 | 先查 streamer interval，再查 Wi-Fi/UDP |
| packets/s、samples/s 都正常但畫面仍卡 | 渲染端負載 | 限制 TrailRenderer points、降低 glow/interpolation、檢查 frame timing |

實機目標值：

- active trail：大約 25-35 packets/s。
- 慢速小幅旋轉：不應掉到 5Hz；至少要維持接近 active cadence 或穩定 10Hz 以上。
- host average arrival gap：local Wi-Fi 下盡量低於 50ms；若穩定高於 100ms，肉眼會感到跳格。
- samples/s：應能反映感測器輸入與 batch 內容；不可只看 packets/s。

## 主要檔案

- `docs/performance-checklist.md`
- `lib/shared/diagnostics/latency_tracker.dart`
- `lib/shared/diagnostics/performance_overlay.dart`

## 依賴 Skills

- WebSocket Connection
- Motion Protocol
- Motion Detection
- Saber Gameplay

## 實作項目

- [ ] 在 motion event 中記錄手機端 timestamp。
- [ ] 電腦端記錄收到 event 的時間。
- [ ] 電腦端記錄畫面回饋觸發時間。
- [ ] 顯示最近 N 次事件延遲。
- [ ] 記錄 FPS 或 frame timing。
- [ ] 建立展示前效能檢查清單。
- [x] Trail debug 應顯示 controller packets/s、controller samples/s。
- [x] Trail debug 應顯示 host packets/s、host samples/s、average arrival gap。
- [x] 診斷時先比較 controller sent 與 host received，再判斷是封包量不足、傳輸慢，還是渲染負載。

## 驗收標準

- [ ] 可以看到最近事件延遲。
- [ ] 可以知道平均延遲與最大延遲。
- [ ] 可以確認遊戲畫面沒有明顯卡頓。
- [ ] 測試紀錄可放進專題報告。
- [x] 可以用 packets/s、samples/s、arrival gap 判斷 trail 卡頓來源。

## 測試方式

- 手動測試：連續揮動 20 次並記錄平均延遲。
- 手動測試：遊玩 Saber 2 分鐘並觀察 FPS 與卡頓。
- 手動測試：慢速小幅轉動手機，確認 controller packets/s 不會因 acceleration 低而掉到 5Hz。
- 手動測試：對照手機端 sent p/s 與主機端 received p/s，確認不是傳輸掉包造成卡頓。

## 後續擴充

- 匯出 CSV 測試紀錄。
- 顯示網路抖動。
- 比較不同手機與不同 Wi-Fi 環境。

