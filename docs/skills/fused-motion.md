# Fused Motion

## 狀態

In Progress

## 目的

使用系統 sensor fusion 取得 attitude / quaternion、gravity、userAcceleration 與 rotationRate，解決 raw accelerometer / gyroscope 會受手機姿態與重力投影影響的問題。

## 使用階段

Phase 4

## 輸入

- iOS `CMDeviceMotion` 或 Android rotation vector / linear acceleration。
- 使用者校正姿態。
- Motion sample timestamp。

## 輸出

- `FusedMotionSample`。
- 姿態補償後的 controller-local acceleration。
- 依照菜刀握法轉換後的 gameplay-local acceleration。
- 可供 `MotionDetector` 使用的方向與力道資料。

## 主要檔案

- `lib/controller/fused_motion_service.dart`
- `lib/shared/models/fused_motion_sample.dart`
- `lib/controller/fused_motion_debug_panel.dart`
- `test/fused_motion_sample_test.dart`

## 依賴 Skills

- Motion Sensor
- Calibration (共同開發，同一 Phase)
- Motion Protocol

## 實作項目

- [x] 決定先走 native bridge，不把 `motion_core` 當長期依賴。
- [x] 建立 iOS Core Motion platform channel。
- [x] 建立 Android rotation vector / linear acceleration platform channel。
- [x] 建立 `FusedMotionSample` model。
- [x] 校正時記錄 initial attitude quaternion。
- [x] 將 userAcceleration 轉到校正後 controller-local frame。
- [x] 用校正時的 gravity 建立菜刀握法 gameplay frame。
- [x] 依實機測試結果套用 fused direction remap。
- [x] 更新 `MotionDetector`，改用 fused sample 判斷方向。
- [x] 保留 raw sensor debug panel 作為診斷工具。
- [ ] 實機調整 threshold 與方向 sign mapping。
- [ ] Android 實機編譯與測試。

## 驗收標準

- [ ] 手機 roll / pitch / yaw 改變時，方向判定仍以校正握法為基準。
- [ ] raw accelerometer gravity 不會造成 forward/backward 誤判。
- [ ] 可穩定取得 userAcceleration 或等價的 linear acceleration。
- [ ] 實機測試六方向各 20 次，方向判定達展示可接受水準。

## 測試方式

- 單元測試：quaternion / vector transform。
- 手動測試：不同握持姿態下做 left/right/up/down/forward/backward。
- 手動測試：用菜刀握法，手機側邊向下，校正後測六方向。
- 手動測試：未校正、校正後、手機 roll 90 度後比較方向判定。

## 驗證紀錄

- `flutter test` 通過。
- `flutter analyze` 通過。
- `flutter build ios --simulator --no-codesign` 通過。
- Android build 尚未驗證，因目前本機環境沒有 Android SDK。

## 實機方向 Remap (已棄用)

在舊版本中，由於 `ControllerGripFrame.knifeSideDown` 錯誤地使用螢幕法向量 Z 軸計算朝前軸，造成前後/左右軸向發生 90 度對調，且在不同側拿方向（螢幕朝左/朝右）時會因為重力符號反轉而方向相反，因而使用了一個硬編碼的對照表來手動轉換方向。

經過修正校正坐標投影演算法（將手機頂端 Y 軸投影為朝前軸並外積出正確的左右軸）後，我們建立了標準右手坐標系，使轉換後的 `x`、`y`、`z` 直接對齊物理的右、上、前。因此，手動 Remap 對照表已**完全棄用**（改為 identity 映射），所有的手勢偵測皆直接基於物理一致的坐標系統。

## 後續擴充

- 使用 magnetometer 修正 yaw drift。
- 增加 sample smoothing。
- 記錄 motion samples 供 replay debug。
