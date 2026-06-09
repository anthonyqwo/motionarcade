# Motion Sensor

## 狀態

Accepted

## 目的

讀取手機 accelerometer 與 gyroscope 資料，提供 raw sensor debug、感測器可用性確認與 fallback 診斷。

正式 motion detection 不直接使用 raw x/y/z 判斷方向，後續會由 Fused Motion skill 取得姿態補償後的資料。

## 使用階段

Phase 3

## 輸入

- 手機 IMU 感測器資料流。

## 輸出

- Accelerometer sample。
- Gyroscope sample。
- Motion magnitude。
- Sensor debug UI。

## 主要檔案

- `lib/controller/motion_sensor_service.dart`
- `lib/controller/sensor_debug_panel.dart`
- `lib/shared/models/sensor_sample.dart`

## 依賴 Skills

- 無

## 實作項目

- [x] 加入 `sensors_plus`。
- [x] 讀取 accelerometer。
- [x] 讀取 gyroscope。
- [x] 建立 sensor stream service。
- [x] 建立即時數值 Debug 面板。
- [x] 管理 stream 生命週期。

## 驗收標準

- [x] 手機端可顯示 accelerometer 數值。
- [x] 手機端可顯示 gyroscope 數值。
- [x] 移動手機時數值會即時變化。
- [x] 離開頁面後 stream 可以停止。

## 測試方式

- 單元測試：用注入 stream 驗證 sensor snapshot 更新。
- 手動測試：實機移動手機觀察 x/y/z 變化。

## 後續擴充

- Sampling rate 設定。
- Sensor smoothing。
- 感測器資料錄製與回放。
- 與 fused motion debug panel 並排比較 raw / fused data。
