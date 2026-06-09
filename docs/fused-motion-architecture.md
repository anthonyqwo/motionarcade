# Fused Motion Architecture

## 為什麼要改

原本使用 raw accelerometer / gyroscope 直接判斷方向，會遇到兩個問題：

- Accelerometer 包含重力，手機靜止時也會有約 9.8 m/s^2。
- 手機會 roll / pitch / yaw，重力與玩家動作會投影到不同裝置軸上。

因此不能只看 raw x/y/z，也不能只扣某一軸 baseline。Motion Arcade 的體感判定需要使用姿態補償後的加速度資料。

## 參考資料結論

Apple Core Motion 的 `CMDeviceMotion` 提供系統處理後的 motion data，包含 attitude、rotation rate、gravity、userAcceleration 與 magneticField。Apple 文件說 Core Motion 可以用 gyroscope 與 accelerometer 追蹤姿態，並區分 gravity 與 userAcceleration。

Android 提供 rotation vector、gravity、linear acceleration 等 motion sensors。Android 文件也建議 rotation vector 適合 gesture、orientation change、game control 等 motion tasks。

Flutter 的 `sensors_plus` 提供 raw accelerometer、userAccelerometer、gyroscope、magnetometer，但沒有直接提供完整 attitude / quaternion。若要取得 fused attitude，建議使用 native bridge 或先評估 fused motion plugin。

## 6DoF 與 9DoF 定義

本專案需要的是「姿態補償後的動作方向」，不是用手機 IMU 做可靠的絕對空間位置追蹤。

| 名稱 | 在本專案中的意思 | 可行性 |
| --- | --- | --- |
| Raw IMU | accelerometer + gyroscope raw x/y/z | 已可讀取，但不適合直接判方向 |
| 6-axis fusion | accelerometer + gyroscope 推算 attitude，並移除 gravity | 可用於相對姿態與短時間動作 |
| 9-axis fusion | accelerometer + gyroscope + magnetometer，改善 yaw / heading drift | iPhone / Android 可支援，但受磁場干擾 |
| VR-style 6DoF | 3D position + 3D orientation | 不建議用手機 IMU 單獨實作 |

## iPhone 9DoF 可行性

iPhone 可透過 Core Motion 取得 `CMDeviceMotion`，其中包含：

- attitude
- rotationRate
- gravity
- userAcceleration
- magneticField

Core Motion 也提供 magnetic north / true north 相關 reference frames。使用 magnetic reference frame 時需要 magnetometer 可用，並可能要求使用者做磁力計校正。

對 Motion Arcade 來說：

- 劍砍、揮拍：優先用 `xArbitraryCorrectedZVertical` 或相對 reference frame，避免磁場干擾。
- 指北、絕對 heading：才需要 magnetic north / true north。
- 9DoF 可作為 yaw drift correction，但不是每個展示環境都應強依賴磁力計。

## 建議資料流程

```text
Native fused motion API
        ↓
FusedMotionSample
        ↓
校正：記錄 q0 / initial attitude
        ↓
把 userAcceleration 轉到 controller-local frame
        ↓
MotionDetector 判斷 left/right/up/down/forward/backward
        ↓
產生 SwingEvent / SlashEvent
```

## 核心資料

```text
attitude: Quaternion
gravity: Vector3
userAcceleration: Vector3
rotationRate: Vector3
timestamp: DateTime
```

## 座標轉換概念

校正時：

```text
q0 = current attitude
```

每次取樣：

```text
q = current attitude
a = userAcceleration in device frame
relativeRotation = inverse(q0) * q
aController = transform a into calibrated controller frame
```

簡化理解：

```text
不要問「手機 z 軸現在是多少」
要問「相對於校正握法，玩家正在往哪個控制器方向加速」
```

## 實作路線

### Option A：Native Bridge

iOS：

- 使用 Core Motion `CMMotionManager`
- 讀取 `CMDeviceMotion`
- 輸出 attitude quaternion、gravity、userAcceleration、rotationRate

Android：

- 使用 `TYPE_ROTATION_VECTOR`
- 使用 `TYPE_LINEAR_ACCELERATION`
- 必要時搭配 gyroscope / gravity sensor
- 輸出 quaternion、linearAcceleration、rotationRate

優點：

- 使用系統 sensor fusion，穩定度較好。
- 不需要在 Dart 自己實作 Madgwick / Mahony filter。

缺點：

- 需要寫 platform channel。

### Option B：Flutter Plugin Spike

先評估 `motion_core` 等 fused motion plugin。若能穩定取得 attitude quaternion 與 userAcceleration，可先用 plugin 加速開發。

優點：

- 開發速度快。

缺點：

- 需要確認套件維護狀態、平台支援、資料頻率與實機穩定度。

## 對現有架構的調整

目前 `MotionSensorService` 保留為 debug / fallback：

- 顯示 raw accelerometer / gyroscope。
- 協助比較 fused data 是否合理。
- 感測器不可用時提供診斷。

新增 `FusedMotionService` 作為主要輸入：

```text
lib/controller/fused_motion_service.dart
lib/shared/models/fused_motion_sample.dart
lib/controller/fused_motion_debug_panel.dart
```

`MotionDetector` 之後改吃 `FusedMotionSample`，不直接吃 raw accelerometer / gyroscope。

## 參考連結

- Apple Core Motion processed device motion data: https://developer.apple.com/documentation/coremotion/getting-processed-device-motion-data
- Apple CMDeviceMotion: https://developer.apple.com/documentation/coremotion/cmdevicemotion
- Apple magnetic north reference frame: https://developer.apple.com/documentation/coremotion/cmattitudereferenceframe/cmattitudereferenceframexmagneticnorthzvertical
- Android motion sensors: https://developer.android.com/develop/sensors-and-location/sensors/sensors_motion
- Android sensor types / rotation vector: https://source.android.com/docs/core/interaction/sensors/sensor-types
- sensors_plus docs: https://pub.dev/documentation/sensors_plus/latest/sensors_plus/
- motion_core package candidate: https://pub.dev/packages/motion_core

