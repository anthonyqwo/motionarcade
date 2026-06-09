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

## 驗收標準

- [ ] 可以看到最近事件延遲。
- [ ] 可以知道平均延遲與最大延遲。
- [ ] 可以確認遊戲畫面沒有明顯卡頓。
- [ ] 測試紀錄可放進專題報告。

## 測試方式

- 手動測試：連續揮動 20 次並記錄平均延遲。
- 手動測試：遊玩 Saber 2 分鐘並觀察 FPS 與卡頓。

## 後續擴充

- 匯出 CSV 測試紀錄。
- 顯示網路抖動。
- 比較不同手機與不同 Wi-Fi 環境。

