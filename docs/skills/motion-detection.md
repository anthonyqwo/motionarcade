# Motion Detection

## 狀態

In Progress

## 目的

將姿態補償後的 fused motion data 轉換為遊戲可使用的 swing/slash event，支援方向、力道與持續時間判定。此 skill 負責離散事件；連續軌跡與投籃序列交給 Motion Window Trail。

目前 raw accelerometer / gyroscope 版本只保留為 debug / fallback。正式方向判定必須使用 `FusedMotionSample`，避免手機 roll / pitch / yaw 或重力投影造成誤判。

## 使用階段

Phase 4

## 輸入

- `FusedMotionSample`。
- Controller-local user acceleration。
- Rotation rate。
- Calibration initial attitude。
- Sensitivity setting。

## 輸出

- `SwingEvent`。
- `SlashEvent`。
- Direction。
- Power。
- Duration。
- Motion window features 的基礎資料。

## 主要檔案

- `lib/controller/motion_detector.dart`
- `lib/controller/sensitivity_settings.dart`
- `lib/controller/recent_motion_events_panel.dart`
- `test/motion_detector_test.dart`

## 依賴 Skills

- Motion Sensor
- Fused Motion
- Calibration
- Motion Protocol

## 實作項目

- [x] 計算 motion magnitude。
- [x] 實作 threshold 判定。
- [x] 實作 cooldown。
- [x] 改用 `FusedMotionSample` 判斷 left/right/up/down/forward/backward。
- [x] 以 controller-local frame 取代 raw x/y/z 軸判斷。
- [x] 計算 power。
- [x] 計算 duration。
- [x] 建立 Low / Medium / High 靈敏度切換。
- [x] 最近事件紀錄擴充到 10 筆。
- [x] 送出 slash event。

## 驗收標準

- [ ] 可辨識 left、right、up、down、forward、backward。
- [ ] 手機 roll / pitch / yaw 改變後，方向仍以校正握法為基準。
- [ ] forward/backward 不受 accelerometer gravity 影響。
- [x] 一次揮動不會重複觸發多次。
- [x] power 數值介於 0.0 到 1.0。
- [x] 事件可傳送到電腦端。

## 測試方式

- 單元測試：用模擬 sample 測試方向判定。
- 手動測試：實機六方向各揮 20 次。
- 單元測試：用 fused sample 測試 forward/backward 不依賴 raw gravity。
- 手動測試：用 Low / Medium / High 比較誤觸率與漏判率。

## 後續擴充

- 斜向判定。
- Thrust 判定。
- Motion samples 軌跡輸出。

## 實作備註

- `forward/backward` 不能使用 raw accelerometer z 值或單軸 baseline，因為重力會隨手機姿態投影到不同軸。
- 方向判定流程改為：取得 `userAcceleration`、套用 attitude / quaternion、轉成 controller-local frame，再做 threshold / cooldown / power 判定。
- Gyroscope / rotationRate 用於辨識旋轉型揮動與輔助判定，不應取代去重力後的線性加速度。
