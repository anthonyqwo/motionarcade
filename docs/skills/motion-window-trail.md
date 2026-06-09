# Motion Window Trail

## 狀態

Ready for Test

## 目的

建立連續 motion sample 的共用資料層，讓體感遊戲不只依賴單次離散事件。揮劍需要連續軌跡來畫劍痕與判定切線，投籃需要一段時間的 motion window 來辨識抬手、出手 peak 與 follow-through。

## 兩種消費模式

MotionWindowBuffer 是共用的資料源，但 Saber 和 Basketball 用不同方式取用：

| 遊戲 | 消費方式 | 說明 |
|---|---|---|
| Saber | 連續 trail stream | MotionTrailStreamer 持續以 20-30Hz 把 buffer 中的最新 samples 送到電腦端，用於即時劍痕繪製 |
| Basketball | 觸控閘門快照 | 玩家放開螢幕（touch up）時，ShootDetector 一次性取出 buffer 中 touch up 前 500-900ms 的 samples 做投籃分析 |

兩種消費方式可同時存在，因為 buffer 本身是被動的 ring buffer，不會因為 Saber 的連續讀取而清空 Basketball 需要的歷史資料。

## 使用階段

Phase 4.5

## 輸入

- `FusedMotionSample`。
- Gameplay-local acceleration。
- Gameplay-local rotationRate。
- Timestamp。
- Calibration / grip frame。

## 輸出

- `MotionWindow`：最近 300-900ms 的 fused samples（保留完整 `FusedMotionSample`）。
- `MotionTrailEvent`：送到電腦端的簡化軌跡，包含姿態投影的劍尖位置。
- 可供 Saber / Basketball detector 使用的 motion features。

## 劍尖位置計算（姿態投影）

MotionTrailSample 的 `tipX`、`tipY` 不使用加速度，而是用手機姿態（attitude quaternion）投影計算。

加速度的問題：

```text
手機停住 → acceleration 歸零 → 劍痕跳回中央 ❌
手機減速 → acceleration 反向 → 劍痕方向反了 ❌
```

姿態投影的優勢：

```text
手機轉到右邊 → attitude 維持 → 劍尖停在右邊 ✅
手機停住 → attitude 不變 → 劍尖位置不動 ✅
```

計算方式（在 `MotionTrailStreamer` 中）：

```dart
// controllerSample.attitude 已經是相對於校正的 relative attitude
final swordTip = controllerSample.attitude.rotate(
  const Vector3Sample(x: 0, y: 1, z: 0), // 劍尖沿 Y 軸
);
final tipX = swordTip.x;  // 左右 [-1, 1]
final tipY = swordTip.y;  // 上下 [-1, 1]
final strength = controllerSample.userAcceleration.magnitude;
```

現有程式碼 `QuaternionSample.rotate()`、`toControllerFrame()`、`CalibrationService.applyToFusedMotion()` 已完整支援，不需要修改。

## 主要檔案

- `lib/controller/motion_window_buffer.dart`
- `lib/controller/motion_trail_streamer.dart`
- `lib/shared/models/motion_trail_sample.dart`
- `lib/shared/models/motion_event.dart`
- `test/motion_window_buffer_test.dart`
- `test/motion_trail_streamer_test.dart`

## 依賴 Skills

- Fused Motion
- Calibration
- Motion Protocol
- WebSocket Connection

## 實作項目

- [x] 建立 `MotionTrailSample` model，包含 `tMs`、`tipX`、`tipY`、`strength`。
- [x] `tipX`、`tipY` 由手機端將 `controllerSample.attitude` 旋轉參考向量 `(0, 1, 0)` 後取 x、y 分量。
- [x] `strength` 由 `userAcceleration.magnitude` 計算，反映揮動力道。
- [x] 不送 raw acceleration 或 quaternion 到電腦端，降低封包大小。
- [x] 建立 `MotionWindowBuffer`（ring buffer），保留最近 900ms samples，使用固定大小 array + head/tail index，避免頻繁 GC。
- [x] buffer 保留原始 60Hz 完整 `FusedMotionSample`，供 ShootDetector 分析用。
- [x] 建立 sample smoothing，降低抖動。
- [x] 建立 downsampling，把 60Hz sensor data 降到 20-30Hz 傳送（僅用於 trail stream，不影響 buffer 本身）。
- [x] 建立 `MotionTrailEvent` 協定，包含 `referenceTimestamp`（絕對時間）供電腦端對齊 slash event。
- [x] 建立 `MotionTrailStreamer`（Saber 用途）：遊戲進行中持續送 trail packets。
- [x] 實作 adaptive rate：magnitude < idleThreshold 時降到 5Hz，超過 threshold 時回到 30Hz。
- [x] 建立 `getWindowSnapshot(durationMs)` 方法（Basketball 用途）：touch up 時一次性取出指定時間範圍的 samples。
- [x] 電腦端接收 trail packets 並保留最近軌跡。
- [ ] 從 window snapshot 產生 features：peak、duration、dominantAxis、stability、releasePoint。
- [ ] 控制資料量，避免 WebSocket 因連續資料造成延遲。

## 驗收標準

- [x] 手機端可維持最近 900ms motion window。
- [x] 電腦端可接收 20-30Hz trail packets。
- [ ] trail packet 不會造成 WebSocket 明顯延遲。
- [ ] 揮動手機時，電腦端能畫出連續軌跡。
- [ ] 停止揮動後，軌跡可在 300-600ms 內淡出。

## 測試方式

- 單元測試：window 只保留指定時間範圍內 samples。
- 單元測試：downsampling 不會輸出過量 samples。
- 單元測試：`getWindowSnapshot(700)` 在 buffer 有 900ms 資料時回傳正確範圍。
- 單元測試：adaptive rate 在 idle 時降到 5Hz。
- 手動測試：手機連續甩動時，電腦端 trail 跟手感同步。
- 手動測試：快速連續揮動 20 次，確認封包與畫面不卡頓。
- 手動測試：投籃模式按住螢幕 → 投 → 放開後，getWindowSnapshot 能取到完整投籃序列。

## 後續擴充

- Replay debug。
- CSV recording。
- 更細緻的 curve fitting / Bezier trail。
- 依遊戲模式調整 sample rate。
