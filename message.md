# Motion Arcade 詳細專案計劃

## 1. 專案概述

### 1.1 專案名稱

**Motion Arcade：手機體感控制器互動遊戲集合**

### 1.2 一句話介紹

Motion Arcade 是一款以智慧型手機作為體感控制器、以電腦作為主遊戲畫面的跨平台互動遊戲集合。玩家拿著手機進行揮拍、投籃、斬擊等動作，電腦端即時顯示遊戲結果與視覺回饋。

### 1.3 核心概念

```text
手機端：讀取玩家動作，作為體感控制器
電腦端：顯示遊戲畫面，負責判定、分數、特效與結算
連線層：透過 WebSocket 在區網內傳遞 motion event
```

### 1.4 專案目標

- 使用 Flutter 建立手機端與桌面端的跨平台互動系統。
- 使用手機 IMU 感測器偵測玩家揮動、投籃、斬擊等動作。
- 使用 WebSocket 達成低延遲雙裝置同步。
- 先完成一個完整且可展示的 Motion Saber 劍砍模式。
- 後續擴充 Motion Basketball 與 Motion Ping Pong，形成遊戲集合平台。

### 1.5 預期成果

- 一個可在電腦端執行的 Motion Arcade 主畫面。
- 一個可在手機端執行的 Motion Controller 控制器畫面。
- 手機可連線至電腦端，並即時傳送體感事件。
- 電腦端可根據手機動作產生劍痕、命中判定、分數與震動回饋。
- 專題展示時可完整演示「連線、校正、揮動、判定、結算」流程。

---

## 2. 專案定位

### 2.1 使用情境

玩家打開電腦端 Motion Arcade，建立遊戲房間後，手機端透過 IP 或 QR Code 連線。連線完成後，玩家拿手機當作球拍、籃球或光劍，透過實際肢體動作控制電腦端遊戲。

### 2.2 目標使用者

- 想體驗體感遊戲的玩家。
- 對 Flutter 跨平台互動有興趣的開發者。
- 專題展示、課堂成果展、互動媒體展示場景。

### 2.3 專案特色

- 手機作為體感控制器，不需要額外硬體。
- 電腦作為大螢幕主機，適合多人觀看與展示。
- 使用 Flutter 同時支援手機端與桌面端。
- 使用 WebSocket 實作區網低延遲同步。
- 使用加速度計與陀螺儀辨識動作。
- 可從單一遊戲擴充為多遊戲集合平台。

---

## 3. MVP 範圍

### 3.1 第一版必做功能

第一版不追求三個遊戲全部完成，而是先把核心體驗做完整。

| 模組 | 必做項目 | 完成標準 |
| --- | --- | --- |
| 電腦端 | WebSocket server | 手機可連線至電腦 |
| 電腦端 | 房間資訊畫面 | 顯示 IP、Port、連線狀態 |
| 手機端 | WebSocket client | 可輸入 IP 並連線 |
| 手機端 | IMU 感測器讀取 | 可讀取 accelerometer 與 gyroscope |
| 手機端 | 揮動偵測 | 可辨識 left、right、up、down、forward、backward |
| 手機端 | 校正功能 | 可記錄目前握持姿態 |
| 共用層 | Motion event 協定 | 手機可傳送 swing/slash event |
| 遊戲 | Motion Saber | 可產生方塊、劍痕、命中判定 |
| 遊戲 | 分數與 Combo | 命中可加分，連擊可累積 |
| 回饋 | Haptic feedback | Perfect/Miss 可讓手機震動 |

### 3.2 第一版不做或延後

- 精準 3D 空間定位。
- 完整物理模擬。
- 真實多人競賽。
- 完整桌球與籃球模式。
- 帳號系統與雲端排行榜。
- 網際網路跨網段連線。

### 3.3 MVP 成功定義

```text
玩家使用手機連線至電腦後，按下校正，揮動手機即可在電腦畫面上看到對應方向的劍痕。
當劍痕方向符合目標方塊提示時，系統判定命中並加分；判定失敗時顯示 Miss 並給予震動回饋。
```

---

## 4. 系統架構

### 4.1 雙端分工

```text
手機端 Flutter App
├── 感測器讀取
├── 動作偵測
├── 校正
├── WebSocket client
├── 控制器 UI
└── 震動回饋

電腦端 Flutter App
├── WebSocket server
├── 房間與玩家管理
├── 遊戲主畫面
├── 遊戲邏輯判定
├── 分數與 Combo
├── 視覺特效
└── 結算畫面
```

### 4.2 系統流程

```text
電腦端建立房間
        ↓
電腦顯示 IP / QR Code
        ↓
手機輸入 IP 或掃描 QR Code
        ↓
手機連線成功
        ↓
玩家按下校正
        ↓
手機讀取 IMU 並偵測動作
        ↓
手機產生 motion event
        ↓
WebSocket 傳送事件到電腦
        ↓
電腦端遊戲邏輯判定
        ↓
畫面顯示結果與特效
        ↓
電腦端回傳 feedback event
        ↓
手機端震動或顯示提示
```

### 4.3 建議專案結構

目前專案是單一 Flutter project。第一版可以先用同一個專案完成雙模式入口，降低架構成本。

```text
lib/
├── main.dart
├── app/
│   ├── motion_arcade_app.dart
│   └── app_mode.dart
├── controller/
│   ├── controller_home_page.dart
│   ├── motion_sensor_service.dart
│   ├── motion_detector.dart
│   └── haptic_feedback_service.dart
├── desktop/
│   ├── desktop_home_page.dart
│   ├── room_page.dart
│   └── game_shell_page.dart
├── games/
│   └── saber/
│       ├── saber_game_page.dart
│       ├── saber_game_state.dart
│       ├── saber_target.dart
│       └── saber_painter.dart
├── network/
│   ├── websocket_server_service.dart
│   ├── websocket_client_service.dart
│   └── motion_protocol.dart
└── shared/
    ├── models/
    │   ├── motion_event.dart
    │   ├── feedback_event.dart
    │   └── player.dart
    └── scoring/
        └── scoring_system.dart
```

第二版若專案變大，再拆成 monorepo：

```text
apps/
├── controller_app/
└── desktop_game/

packages/
├── motion_core/
├── network_core/
├── game_core/
└── ui_core/
```

---

## 5. 技術選型

| 功能 | 建議技術 | 用途 |
| --- | --- | --- |
| UI | Flutter | 手機與桌面介面 |
| 遊戲繪製 | CustomPainter 或 Flame | 劍痕、方塊、球路、特效 |
| 狀態管理 | Riverpod | 管理連線、玩家、遊戲狀態 |
| Raw 感測器 Debug | sensors_plus | accelerometer / gyroscope / userAccelerometer / magnetometer debug 與 fallback |
| Fused Motion | iOS Core Motion、Android Rotation Vector / Linear Acceleration、或 motion_core spike | attitude / quaternion、gravity、userAcceleration、姿態補償 |
| WebSocket client | web_socket_channel | 手機端連線 |
| WebSocket server | shelf + shelf_web_socket | 電腦端建立 server |
| QR Code | qr_flutter | 顯示連線資訊 |
| 震動 | vibration 或 Flutter HapticFeedback | 命中與失誤回饋 |
| 音效 | audioplayers 或 flame_audio | 命中、Combo、結算音效 |
| 2.5D 視覺 | Transform、Canvas、陰影、透明度、縮放 | 用平面技術營造 3D 互動感 |
| 平台權限設定 | AndroidManifest、Info.plist、macOS entitlements | 感測器、區網連線、震動與桌面 server 權限 |
| 效能與延遲量測 | Stopwatch、Flutter DevTools、Debug overlay | 量測 motion event 延遲、FPS、感測器取樣穩定度 |

第一版若要快速做出成果，遊戲畫面可以先用 `CustomPainter`，等遊戲模式增加後再導入 Flame。

### 5.1 視覺呈現策略

本專案第一版不採用完整 3D 電腦圖學管線，而是採用 **2.5D 平面化互動設計**。也就是遊戲邏輯維持 2D，畫面則透過縮放、透明度、陰影、速度線、發光軌跡與動畫節奏，讓玩家感覺物件正在靠近、飛出或被擊中。

這個選擇可以讓專案重點集中在手機體感、雙裝置連線、即時互動與遊戲回饋，而不是把大量時間投入 3D 建模、光照、攝影機、投影矩陣與物理引擎。

### 5.2 是否需要電腦圖學技術

第一版不需要使用完整的 3D 電腦圖學技術，例如：

- OpenGL / Metal / Vulkan。
- 自訂 Shader。
- 3D 模型與材質。
- 真實光照與陰影。
- 3D 攝影機與投影矩陣。
- 3D 剛體物理引擎。

但會使用一些基礎圖學概念：

| 概念 | 用途 | 難度 |
| --- | --- | --- |
| 2D 座標系 | 控制方塊、球、劍痕、UI 位置 | 低 |
| 向量 | 判斷方向、速度、拋物線移動 | 低 |
| 縮放 | 讓物件看起來靠近或遠離玩家 | 低 |
| 透明度 | 製造遠近感、殘影與淡出 | 低 |
| 曲線 | 籃球拋物線、劍痕弧線 | 中低 |
| 碰撞判定 | 方塊命中、籃球進框、桌球回擊 | 中低 |
| 簡單透視錯覺 | 梯形桌面、遠小近大 | 中低 |

### 5.3 Flutter 2.5D 實作方式

2.5D 畫面可以用 Flutter 原生能力完成。

| 技術 | 用途 |
| --- | --- |
| `CustomPainter` | 畫方塊、劍痕、粒子、球路、桌球桌、籃框 |
| `AnimationController` | 控制方塊靠近、劍痕淡出、球飛行、Combo 跳動 |
| `Transform.scale` | 讓物件由小變大，產生靠近感 |
| `Transform.rotate` | 讓方塊、劍痕、球拍效果更動態 |
| `Opacity` | 做遠近感、命中閃爍、軌跡淡出 |
| `BoxShadow` / `MaskFilter.blur` | 做發光、陰影、速度感 |
| `Stack` | 分出背景、中景、前景與 HUD |
| `Tween` / `Curve` | 調整動畫節奏，使動作更有打擊感 |

### 5.4 Motion Saber 的 2.5D 設計

Motion Saber 是最適合展示 2.5D 效果的模式。方塊不需要真的在 3D 空間移動，只要用「遠小近大」與「透明度變化」即可產生飛向玩家的錯覺。

```text
方塊剛生成：小、透明、位於畫面中央
        ↓
方塊靠近：逐漸放大、變清楚、陰影加重
        ↓
進入擊中區：大小最大、方向箭頭最明顯
        ↓
玩家揮動：畫出發光劍痕
        ↓
命中：方塊切開、粒子飛散、畫面短暫震動
```

實作重點：

- 方塊的 `scale` 由 0.4 動畫到 1.2。
- 方塊的 `opacity` 由 0.3 動畫到 1.0。
- 方塊越靠近，陰影與發光越明顯。
- 劍痕使用粗線條、漸層、blur 與 fade out。
- 命中時加入 screen shake 與粒子，增加打擊感。

### 5.5 Motion Basketball 的平面化設計

Motion Basketball 可以採用側面 2D 拋物線。玩家投籃後，球從畫面下方飛向右上方籃框。

```text
球的位置 x：隨時間往籃框方向移動
球的位置 y：依照拋物線公式上升後下降
球的大小：可在靠近籃框時略微縮小
球的殘影：顯示速度與路徑
```

簡化公式：

```text
x = startX + velocityX * t
y = startY - velocityY * t + gravity * t * t
```

這樣不需要 3D 物理，也能讓玩家清楚感受到投籃力道與角度。

### 5.6 Motion Ping Pong 的假透視設計

Motion Ping Pong 可以使用斜視角或俯視角。桌球桌畫成梯形，遠端比較窄、近端比較寬，球靠近玩家時變大，飛回對面時變小。

```text
遠端桌面：較窄
近端桌面：較寬
球靠近玩家：放大、速度感增加
球遠離玩家：縮小、透明度略降
擊球瞬間：加入閃光、速度線、球拍殘影
```

第一版不做完整桌球物理，只做固定路徑與擊球時間窗，能大幅降低難度並提高展示穩定度。

### 5.7 視覺策略結論

本專案的視覺策略可以描述為：

> Motion Arcade 採用 Flutter 2D Canvas 與動畫系統實作 2.5D 平面化互動設計。遊戲邏輯維持 2D，畫面透過縮放、透明度、簡單透視、陰影、發光軌跡、速度線與震動音效回饋，營造類似 3D 體感遊戲的空間感與打擊感。

### 5.8 Fused Motion 與 6DoF / 9DoF 策略

體感方向判定不能直接使用 raw accelerometer / gyroscope，因為手機會 roll / pitch / yaw，且 accelerometer 包含重力。若只看 raw z 或只扣 z baseline，手機姿態一變，重力投影就會換軸，forward/backward 很容易誤觸發。

本專案的正式體感架構改為 **Fused Motion**：

```text
attitude / quaternion
gravity
userAcceleration
rotationRate
        ↓
校正時記錄 initial attitude
        ↓
將 userAcceleration 轉到校正後 controller-local frame
        ↓
依照菜刀握法建立 gameplay-local frame
        ↓
MotionDetector 判斷 left/right/up/down/forward/backward
```

6DoF / 9DoF 在本專案中的定義：

| 名稱 | 用途 | 策略 |
| --- | --- | --- |
| 6-axis fusion | accelerometer + gyroscope，取得相對姿態與去重力加速度 | 可做主要體感判定 |
| 9-axis fusion | accelerometer + gyroscope + magnetometer，改善 yaw / heading drift | 可用，但需注意磁場干擾 |
| VR-style 6DoF | 3D position + 3D orientation | 不用手機 IMU 單獨實作 |

iPhone 可透過 Core Motion `CMDeviceMotion` 取得 attitude、gravity、userAcceleration、rotationRate 與 magneticField；若使用 magnetic reference frame，可接近 9DoF sensor fusion，但會受磁力計可用性與校正狀態影響。Android 則可使用 rotation vector 與 linear acceleration。Flutter 端優先評估 `motion_core` 這類 fused motion plugin；若不穩，再寫 native platform channel。

實際遊玩姿勢預設為「菜刀握法」：手機不是平躺，而是側邊向下。校正時會用 gravity 判斷哪個方向是上下，並用手機螢幕法線作為 forward/backward 的基準，再推導左右軸。平躺姿勢只作為 debug，不作為正式預設測試姿勢。

參考資料：

- Apple Core Motion / `CMDeviceMotion`：系統處理後的 attitude、gravity、userAcceleration、rotationRate、magneticField。
- Apple `xArbitraryCorrectedZVertical`：可使用 magnetometer 改善 yaw，但需要磁力計可用且校正。
- Android Motion Sensors：`TYPE_ROTATION_VECTOR` 適合 gesture、orientation change、game control；`TYPE_LINEAR_ACCELERATION` 是扣除 gravity 後的加速度。
- `sensors_plus`：可讀 raw accelerometer、gyroscope、magnetometer、userAccelerometer，但沒有完整 fused attitude / quaternion。
- `motion_core`：可作為 spike 候選，宣稱封裝 iOS Core Motion 與 Android Rotation Vector，但套件維護狀態仍需實機驗證。

### 5.9 平台權限與系統設定

體感與雙裝置連線會碰到平台權限問題，必須在開發早期處理，不能等到展示前才補。

需要確認的設定：

| 平台 | 需要確認的項目 | 用途 |
| --- | --- | --- |
| Android | Internet/network 權限 | 手機端 WebSocket 連線 |
| Android | 感測器可用性與實機測試 | accelerometer / gyroscope / rotation vector / linear acceleration |
| iOS | Motion usage description | 讀取動作感測器時避免權限或系統阻擋 |
| iOS | Local network usage description | 掃描或連線區網電腦 |
| macOS | Network server / incoming connection 設定 | 桌面端建立 WebSocket server |
| 全平台 | 震動能力 fallback | 某些裝置震動強度或模式支援不同 |

驗收時至少要用一台 Android 或 iOS 實機測試，不只用模擬器，因為模擬器無法代表真實感測器與震動回饋。

---

## 6. 資料協定設計

### 6.1 設計原則

手機端不要傳送大量 raw sensor data。第一版建議在手機端完成初步動作辨識，再傳送乾淨的事件資料給電腦端。

這樣有三個好處：

- 降低網路傳輸量。
- 電腦端遊戲邏輯更單純。
- Debug 時可以直接看 motion event，不必分析大量感測器數值。

### 6.2 通用事件格式

```json
{
  "type": "swing",
  "playerId": "p1",
  "timestamp": 1710000000000
}
```

### 6.3 Join Event

```json
{
  "type": "join",
  "playerId": "p1",
  "name": "Player 1",
  "device": "android",
  "timestamp": 1710000000000
}
```

### 6.4 Calibrate Event

```json
{
  "type": "calibrate",
  "playerId": "p1",
  "neutral": {
    "pitch": 0.1,
    "roll": -0.02,
    "yaw": 0.5
  },
  "timestamp": 1710000000000
}
```

### 6.5 Swing Event

```json
{
  "type": "swing",
  "playerId": "p1",
  "direction": "right",
  "power": 0.84,
  "durationMs": 140,
  "timestamp": 1710000000000
}
```

### 6.6 Slash Event

第一版建議只傳 direction 與 power，由電腦端生成好看的劍痕。

```json
{
  "type": "slash",
  "playerId": "p1",
  "direction": "down",
  "power": 0.88,
  "durationMs": 120,
  "timestamp": 1710000000000
}
```

Saber 不應只依賴離散 slash event。離散 slash event 負責命中、分數與 combo，連續劍痕則由 `motionTrail` event 提供。

### 6.7 Motion Trail Event

`motionTrail` 用於即時視覺軌跡，不直接作為最終命中判定。劍尖位置由手機姿態（attitude quaternion）投影計算，不使用加速度映射，因為加速度會在停止時歸零、減速時反向。手機端應先做 smoothing 與 downsampling，避免傳送大量 raw sensor data。

```json
{
  "type": "motionTrail",
  "playerId": "p1",
  "samples": [
    {"tMs": 0, "tipX": 0.12, "tipY": 0.24, "strength": 0.42},
    {"tMs": 16, "tipX": 0.18, "tipY": 0.31, "strength": 0.55},
    {"tMs": 33, "tipX": 0.24, "tipY": 0.39, "strength": 0.71}
  ],
  "referenceTimestamp": 1710000000000,
  "timestamp": 1710000000000
}
```

欄位說明：

| 欄位 | 來源 | 說明 |
|---|---|---|
| `tipX` | attitude quaternion 投影 | 劍尖左右位置 [-1, 1]，手機轉到哪劍尖就在哪 |
| `tipY` | attitude quaternion 投影 | 劍尖上下位置 [-1, 1] |
| `strength` | userAcceleration magnitude | 揮動力道，用於劍痕粗細與發光強度 |
| `referenceTimestamp` | 本批 samples 的絕對參考時間 | 讓電腦端對齊 slash event |

### 6.8 Shoot Hold Event

玩家按住螢幕時送出，通知電腦端玩家進入投籃準備狀態。

```json
{
  "type": "shootHold",
  "playerId": "p1",
  "pressed": true,
  "timestamp": 1710000000000
}
```

### 6.9 Shoot Event

玩家放開螢幕時，手機端取放開前 500-900ms 的 `MotionWindow` 分析投籃品質後產生。如果 window 資料不符合投籃特徵（例如 upwardEnergy 太低或 horizontalNoise 太高），則不送出 ShootEvent。

```json
{
  "type": "shoot",
  "playerId": "p1",
  "power": 0.76,
  "angle": 42,
  "offset": -0.08,
  "stability": 0.91,
  "holdDurationMs": 680,
  "timestamp": 1710000000000
}
```

### 6.10 Feedback Event

```json
{
  "type": "feedback",
  "playerId": "p1",
  "result": "perfect",
  "haptic": "strong",
  "durationMs": 120,
  "timestamp": 1710000000000
}
```

---

## 7. 手機端規劃

### 7.1 手機端畫面

手機端定位為控制器，不需要顯示完整遊戲畫面。

```text
Motion Controller

連線狀態：已連線 / 未連線
目前遊戲：Motion Saber
玩家名稱：Player 1

[連線設定]
[校正姿態]
[震動測試]
[技能按鈕]

揮動強度：███████░░░
偵測方向：right
```

### 7.2 手機端功能

- 輸入電腦端 IP 與 Port。
- 連線至電腦端 WebSocket server。
- 顯示目前連線狀態。
- 讀取 accelerometer 與 gyroscope。
- 提供校正按鈕，記錄 neutral position。
- 偵測 swing / slash / shoot 等 motion event。
- 傳送 motion event 至電腦端。
- 接收 feedback event 並觸發震動。

### 7.3 感測器使用

| 感測器 | 用途 |
| --- | --- |
| Accelerometer | 偵測甩動、爆發力、投籃出手 |
| Gyroscope | 偵測旋轉方向、揮拍方向、斬擊方向 |
| Touch | 校正、技能、連線、模式切換 |
| Haptic | 命中、Miss、Combo、受擊回饋 |

### 7.4 Swing 偵測流程

```text
讀取 accelerometer / gyroscope
        ↓
取得 fused motion sample
        ↓
套用校正姿態
        ↓
把 userAcceleration 轉到 controller-local frame
        ↓
計算 motion magnitude
        ↓
超過 threshold 時進入 swing 狀態
        ↓
記錄短時間內最大軸與峰值
        ↓
根據校正後控制器座標軸判斷方向
        ↓
計算 power 與 duration
        ↓
產生 swing/slash event
        ↓
進入 cooldown，避免重複觸發
```

### 7.5 Swing Power 簡化公式

```text
power = normalize(
  userAccelerationMagnitude * 0.7 + rotationRateMagnitude * 0.3
)
```

### 7.6 Direction 判定

第一版支援六方向：

```text
left
right
up
down
forward
backward
```

其中 `forward/backward` 必須使用去除重力後的 `userAcceleration`，並轉換到校正後的 controller-local frame；不能直接使用 raw accelerometer z。這適合突刺、推進、投籃出手等動作。第二版再加入：

```text
up-left
up-right
down-left
down-right
thrust
```

### 7.7 Debounce 與 Threshold

為了避免一次揮動被判定為多次：

```text
偵測到 swing
        ↓
發送事件
        ↓
進入 300ms cooldown
        ↓
cooldown 結束後才可再次觸發
```

靈敏度設定：

| 靈敏度 | 效果 |
| --- | --- |
| Low | 需要較大力揮動 |
| Medium | 預設值 |
| High | 小幅度即可觸發 |

---

## 8. 電腦端規劃

### 8.1 電腦端職責

- 建立 WebSocket server。
- 顯示房間 IP、Port 與 QR Code。
- 管理玩家連線狀態。
- 接收手機 motion event。
- 執行遊戲邏輯與命中判定。
- 顯示劍痕、方塊、球路、分數與 Combo。
- 回傳 feedback event 給手機端。

### 8.2 電腦端畫面流程

```text
首頁
 ↓
建立房間
 ↓
顯示 IP / QR Code
 ↓
等待手機連線
 ↓
手機完成校正
 ↓
選擇遊戲模式
 ↓
開始遊戲
 ↓
結算畫面
```

### 8.3 首頁線框

```text
Motion Arcade

[建立房間]
[遊戲設定]
[操作說明]

目前連線玩家：0
```

### 8.4 連線畫面線框

```text
請使用手機連線

IP：192.168.1.20:8080
QR Code：連線資訊

等待玩家加入...
```

### 8.5 遊戲殼層

所有遊戲共用一個外層 UI：

```text
左上：遊戲名稱 / 模式
右上：分數 / 時間
中間：遊戲主要畫面
下方：玩家狀態 / 連線狀態
右側：Combo / 判定結果
```

---

## 9. Motion Saber 詳細規劃

### 9.1 遊戲概念

玩家拿手機當光劍，電腦畫面會產生帶有方向提示的方塊。玩家必須依照方塊上的方向揮動手機，電腦端顯示對應劍痕並判斷是否命中。

### 9.2 核心玩法流程

```text
方塊生成
        ↓
方塊顯示斬擊方向
        ↓
方塊往玩家方向移動
        ↓
玩家揮動手機
        ↓
手機傳送 slash event
        ↓
電腦生成劍痕
        ↓
比對 slash direction 與 target direction
        ↓
計算 Perfect / Good / Miss
        ↓
更新分數與 Combo
        ↓
回傳震動回饋
```

### 9.3 目標方塊資料

```json
{
  "id": "target_001",
  "direction": "down",
  "spawnTime": 1710000000000,
  "hitWindowStart": 1710000001200,
  "hitWindowEnd": 1710000001700,
  "speed": 1.0,
  "lane": 0
}
```

### 9.4 命中判定

| 判定 | 條件 | 分數 |
| --- | --- | --- |
| Perfect | 方向正確，且在最佳時間窗內 | +100 |
| Good | 方向正確，但時間略偏 | +60 |
| Weak | 方向正確，但 power 過低 | +30 |
| Miss | 沒揮、方向錯誤或時間超出 | +0 |

### 9.5 Combo 規則

```text
連續命中：combo + 1
Miss：combo 歸零
每 10 combo 提升倍率
最高倍率 x3.0
```

分數公式：

```text
finalScore = baseScore * comboMultiplier
```

### 9.6 劍痕生成

Fallback 模式（舊版固定方向線段描述，正式版已改用姿態投影）：

| direction | 起點 | 終點 |
| --- | --- | --- |
| down | top center | bottom center |
| up | bottom center | top center |
| left | right center | left center |
| right | left center | right center |

> [!NOTE]
> 正式版已改用姿態投影（Attitude Projection）由手機端計算連續軌跡 `tipX` / `tipY`，並以 20-30Hz 串流。此表格僅作為無姿態資料時的 Fallback 備用模式。

視覺效果：

- 發光線條。
- 殘影淡出。
- 命中火花。
- 方塊切開動畫。
- Combo 顏色變化。

### 9.7 MVP 畫面

```text
Combo：12                         Score：3200

                    ↓
                 [方塊]

玩家揮動後：

              ╲ 發光劍痕 ╱
```

### 9.8 Motion Saber 成功標準

```text
玩家看到向下箭頭方塊後向下揮手機，電腦端會顯示向下劍痕、方塊切開、分數增加、手機震動。
```

---

## 10. 後續遊戲規劃

### 10.1 Motion Basketball

玩家拿手機做投籃動作，電腦端顯示籃球飛向籃框。投籃偵測採用「觸控閘門」：玩家按住螢幕準備投籃，做出投籃動作後放開螢幕觸發出手分析。

核心參數：

```text
power：投籃力道（由 upwardEnergy 計算）
angle：出手角度（由 releasePeak 的 Y/Z 比計算）
offset：左右偏移（由 horizontalNoise 方向計算）
stability：出手穩定度（由 release 前後方向一致性計算）
```

第一版玩法：

```text
固定位置罰球
        ↓
玩家按住螢幕
        ↓
玩家做投籃動作（抬手、向上加速、出手）
        ↓
玩家放開螢幕 = 出手時刻
        ↓
手機分析放開前 500-900ms motion window
        ↓
通過門檻 → 手機產生 shoot event
        ↓
電腦產生拋物線
        ↓
判斷進球 / 沒進
```

### 10.2 Motion Ping Pong

玩家拿手機當桌球拍，電腦端顯示桌球桌與球。

第一版玩法：

```text
球沿固定路徑飛向玩家
        ↓
球進入擊球時間窗
        ↓
玩家揮手機
        ↓
判斷方向、時機與力道
        ↓
成功則球反彈回對面
        ↓
失敗則對手得分
```

第一版不做完整 3D 物理，先做 2.5D 視角與固定擊球時間窗。

---

## 11. 共用遊戲系統

### 11.1 Motion Event System

負責將手機端輸入轉換成遊戲可理解的事件。

```text
JoinEvent
CalibrateEvent
SwingEvent
SlashEvent
ShootHoldEvent
ShootEvent
ButtonEvent
FeedbackEvent
```

### 11.2 Scoring System

所有遊戲共用分數規則，避免每個遊戲重複實作。

```text
Perfect +100
Good    +60
Weak    +30
Miss    +0
Combo multiplier x1.0 ~ x3.0
```

### 11.3 Calibration System

校正流程：

```text
玩家自然握持手機
        ↓
按下校正按鈕
        ↓
系統記錄目前 pitch / roll / yaw
        ↓
後續動作都以此姿態作為 neutral position
```

目的：

- 降低不同玩家握持角度造成的誤判。
- 讓直立拿、斜拿、橫拿都能有穩定判定。
- 提升展示時的成功率。

### 11.4 Feedback System

電腦端根據遊戲判定回傳手機震動。

| 結果 | 手機回饋 |
| --- | --- |
| Perfect | 短而強的震動 |
| Good | 短震動 |
| Miss | 長震動 |
| Combo | 連續短震動 |
| 受擊 | 強震動 |

---

## 12. 開發階段規劃

本專案採用「先核心、再遊戲、最後包裝」的階段式開發。每個階段都必須產出可驗收成果，避免只完成程式片段但無法展示。

### 12.1 Phase 0：專案整理與基礎架構

目標：把 Flutter 預設專案整理成 Motion Arcade 的可開發架構，建立手機端與電腦端共用的基礎。

主要工作：

- 更新 `pubspec.yaml` 的專案名稱、描述與必要套件。
- 移除 Flutter counter 範例畫面。
- 建立 `Desktop Mode` 與 `Controller Mode` 入口。
- 建立基礎路由與頁面切換。
- 建立共用 theme、color tokens、文字樣式與基礎 UI 元件。
- 建立主要資料模型，例如 player、motion event、feedback event。
- 建立 `lib/app`、`lib/controller`、`lib/desktop`、`lib/network`、`lib/shared`、`lib/games` 目錄。
- 建立 `docs/skills` 作為技能模組統一管理區。
- 建立平台權限檢查清單，包含 Android、iOS、macOS 的網路、感測器與震動設定。

建議產出：

- `lib/app/app_mode.dart`
- `lib/app/motion_arcade_app.dart`
- `lib/desktop/desktop_home_page.dart`
- `lib/controller/controller_home_page.dart`
- `lib/shared/models/motion_event.dart`
- `docs/skills/README.md`
- `docs/platform-setup.md`

驗收成果：

- App 啟動後可以選擇 `Desktop Mode` 或 `Controller Mode`。
- Desktop Mode 有主畫面雛形。
- Controller Mode 有控制器畫面雛形。
- 專案已經不是 Flutter 預設 counter app。
- `flutter analyze` 沒有阻斷性錯誤。
- 已確認實機開發需要的網路、感測器與震動權限項目。

### 12.2 Phase 1：雙裝置連線原型

目標：讓手機與電腦可以在同一個區網內建立 WebSocket 連線，完成最小雙端互動。

主要工作：

- 電腦端建立 WebSocket server。
- 電腦端顯示 IP、Port、連線狀態。
- 電腦端產生 QR Code，內容包含 WebSocket 連線資訊。
- 手機端提供 IP 與 Port 輸入。
- 手機端支援掃描 QR Code 或手動輸入 IP。
- 手機端建立 WebSocket client。
- 手機連線後送出 `join` event。
- 電腦端顯示玩家名稱與裝置資訊。
- 手機端提供測試按鈕，按下後送出 `button` event。
- 電腦端即時顯示收到的事件紀錄。
- 處理基本斷線與重新連線狀態。

建議產出：

- `lib/network/websocket_server_service.dart`
- `lib/network/websocket_client_service.dart`
- `lib/network/motion_protocol.dart`
- `lib/desktop/room_page.dart`
- `lib/controller/connection_page.dart`

驗收成果：

- 電腦端按下「建立房間」後可啟動 WebSocket server。
- 手機端輸入 IP 與 Port 後可成功連線。
- 電腦端畫面可顯示已連線玩家。
- 手機端按下測試按鈕，電腦端能在 0.1 到 0.2 秒內顯示事件。
- 手機斷線後，電腦端可以顯示離線狀態。
- 使用 QR Code 與手動輸入兩種方式至少各成功連線一次。

### 12.3 Phase 2：Motion Protocol 與事件模型

目標：定義雙端溝通資料格式，讓後續所有遊戲都共用同一套 motion event 協定。

主要工作：

- 定義 `MotionEvent` base model。
- 定義 `JoinEvent`、`CalibrateEvent`、`SwingEvent`、`SlashEvent`、`ShootEvent`、`ButtonEvent`、`FeedbackEvent`。
- 實作 JSON encode/decode。
- 加入 event version 欄位，避免後續協定改版難維護。
- 建立事件驗證邏輯，例如 type、playerId、timestamp 必填。
- 建立電腦端事件分派器，把不同 event 送到對應系統。
- 建立手機端 feedback receiver，接收電腦端回傳事件。

建議產出：

- `lib/shared/models/motion_event.dart`
- `lib/shared/models/feedback_event.dart`
- `lib/network/motion_event_codec.dart`
- `lib/network/motion_event_dispatcher.dart`
- `test/motion_event_codec_test.dart`

驗收成果：

- 所有事件都可以從 Dart object 轉成 JSON。
- 所有事件都可以從 JSON 還原成 Dart object。
- 收到未知事件類型時不會造成 App crash。
- 測試覆蓋 join、calibrate、slash、shoot、feedback 事件。

### 12.4 Phase 3：手機感測器讀取

目標：手機端可以穩定讀取 IMU 感測器資料，並提供 Debug 畫面協助調整。

主要工作：

- 加入 `sensors_plus`。
- 讀取 accelerometer。
- 讀取 gyroscope。
- 建立 sensor stream service。
- 建立感測器 Debug 面板，顯示 x、y、z 即時數值。
- 顯示 motion magnitude。
- 加入啟動、暫停、釋放 stream 的生命週期管理。
- 處理手機不支援感測器或權限異常情境。

建議產出：

- `lib/controller/motion_sensor_service.dart`
- `lib/controller/sensor_debug_panel.dart`
- `lib/shared/models/sensor_sample.dart`

驗收成果：

- 手機端可即時顯示 accelerometer 與 gyroscope 數值。
- 移動手機時數值會明顯變化。
- 離開控制器頁面後 sensor stream 可以正確停止。
- 感測器不可用時，畫面會顯示可理解的錯誤狀態。

### 12.5 Phase 4：Fused Motion、揮動偵測、校正與穩定化

目標：把 fused motion data 轉換成穩定的 swing/slash event，支援六方向與力道判定。raw sensor data 只保留為 debug / fallback，不作為正式方向判定主資料源。

主要工作：

- 評估 `motion_core` 是否可直接提供 attitude quaternion 與 userAcceleration。
- 若 plugin 不穩，建立 iOS Core Motion / Android Rotation Vector native bridge。
- 建立 `FusedMotionSample` model。
- 校正時記錄 initial attitude quaternion。
- 將 userAcceleration 轉到校正後 controller-local frame。
- 實作 motion magnitude 計算。
- 實作 threshold 判定。
- 實作 cooldown，避免一次揮動觸發多次。
- 判斷 `left`、`right`、`up`、`down`、`forward`、`backward`。
- 計算 `power` 與 `durationMs`。
- 實作校正按鈕，記錄 neutral position。
- 將 motion sample 轉成相對於校正姿態的 controller-local 值。
- 建立靈敏度設定：Low、Medium、High。
- 建立最近事件紀錄面板，方便展示前調整。
- 將 slash event 傳送到電腦端。

建議產出：

- `lib/controller/fused_motion_service.dart`
- `lib/shared/models/fused_motion_sample.dart`
- `lib/controller/motion_detector.dart`
- `lib/controller/calibration_service.dart`
- `lib/controller/sensitivity_settings.dart`
- `lib/controller/recent_motion_events_panel.dart`
- `test/motion_detector_test.dart`

驗收成果：

- 玩家向左、右、上、下、前、後揮手機時，手機端能顯示正確方向。
- 手機端可把方向、力道、時間送到電腦端。
- 一次揮動不會被重複判定成多次事件。
- 校正後，不同 roll / pitch / yaw 握持角度仍能維持穩定判定。
- 至少 20 次測試揮動中，六方向辨識成功率達到展示可接受水準。

### 12.6 Phase 4.5：Motion Window 與 Trail Stream

目標：建立連續 motion data 的共用能力，避免所有體感都被迫壓成單次離散事件。Saber 用它畫連續劍痕，Basketball 用它分析投籃序列。

MotionTrailSample 的劍尖位置由姿態（attitude quaternion）投影計算，不使用加速度，因為加速度會在停止時歸零、減速時反向。姿態代表手機的朝向，手機轉到哪劍尖就在哪，停住也不會跳回中央。

主要工作：

- 建立 `MotionTrailSample` model，包含 `tMs`、`tipX`、`tipY`、`strength`。
- `tipX`、`tipY` 由手機端將 relative attitude 旋轉參考向量後投影產生。
- `strength` 由 `userAcceleration.magnitude` 計算，反映揮動力道。
- 建立 `MotionWindowBuffer`（ring buffer），保留最近 900ms fused samples。
- 建立 smoothing 與 downsampling。
- 建立 `motionTrail` event 協定，包含 `referenceTimestamp`。
- 手機端以 20-30Hz 傳送 motion trail packets，支援 adaptive rate。
- 建立 `getWindowSnapshot(durationMs)` 方法供 Basketball touch up 時一次性取用。
- 電腦端保留每位玩家最近 trail。
- 從 motion window 產生 features：peak、duration、dominantAxis、stability、releasePoint。
- 控制資料量，避免 WebSocket 因連續資料造成延遲。

建議產出：

- `lib/controller/motion_window_buffer.dart`
- `lib/controller/motion_trail_streamer.dart`
- `lib/shared/models/motion_trail_sample.dart`
- `test/motion_window_buffer_test.dart`
- `test/motion_trail_streamer_test.dart`

驗收成果：

- 手機端可維持最近 900ms motion window。
- 電腦端可收到 20-30Hz trail packets。
- 揮動手機時，電腦端可畫出連續劍尖軌跡。
- 手機停止揮動但保持朝向時，劍尖位置不會跳回中央。
- 停止揮動後，劍痕可在 300-600ms 內淡出。
- 快速連續揮動 20 次不會造成明顯卡頓。

### 12.7 Phase 5：Desktop Game Shell 與 2.5D 視覺基礎

目標：建立電腦端遊戲畫面的共用框架與 2.5D 視覺能力，讓後續遊戲共用。

主要工作：

- 建立遊戲殼層 `GameShellPage`。
- 建立 HUD：分數、Combo、時間、連線狀態。
- 建立遊戲畫布區域。
- 建立共用 `CustomPainter` 繪圖工具。
- 建立 2.5D 物件動畫工具，例如 scale、opacity、depth。
- 建立 screen shake 工具。
- 建立簡單粒子效果。
- 建立共用音效與震動 feedback 呼叫介面。
- 建立 trail renderer，支援 tipX/tipY 姿態投影座標、glow、fade out、寬度依 strength 變化。
- 建立劍尖位置指示器，在玩家不揮動時顯示半透明劍尖位置。

建議產出：

- `lib/desktop/game_shell_page.dart`
- `lib/shared/visual/depth_transform.dart`
- `lib/shared/visual/screen_shake_controller.dart`
- `lib/shared/visual/particle_system.dart`
- `lib/shared/visual/trail_renderer.dart`
- `lib/shared/feedback/feedback_service.dart`

驗收成果：

- 電腦端有可重用的遊戲畫面框架。
- 畫面能展示物件由遠到近的 2.5D 動畫。
- 可觸發一次 screen shake。
- 可產生基本粒子效果。
- HUD 不會擋住主要遊戲畫面。

### 12.8 Phase 6：Motion Saber MVP

目標：完成第一個可展示的完整遊戲模式，證明手機體感到電腦遊戲回饋的完整流程。

Motion Saber 採用「連續視覺 + 離散判定」：

- `motionTrail`：用姿態投影計算劍尖位置，畫出玩家實際揮動軌跡、劍痕、殘影。
- `slash`：判斷方向、命中、分數與 combo。

Trail 與 slash 的互動流程：

1. 電腦端持續接收 motionTrail → 即時畫出劍尖軌跡（淡色、細線）。
2. 玩家不揮動時，劍尖位置指示器仍顯示（因為姿態不會歸零），玩家可提前瞴準方塊。
3. 手機端偵測到 slash → 送 SlashEvent → 電腦端回溯最近 200-300ms trail 作為「命中劍痕」→ 劍痕變亮、加粗、加 glow。
4. 比對 slash.direction 與 target.direction → 匹配則方塊切開 + 分數，不匹配則劍痕顯示但不命中。

主要工作：

- 建立 Saber game state。
- 建立目標方塊資料模型。
- 建立目標方塊生成器。
- 方塊顯示斬擊方向箭頭。
- 方塊以 2.5D 動畫靠近玩家。
- 接收手機端 slash event。
- 接收手機端 motionTrail event。
- 根據 motionTrail 的 tipX/tipY 畫出連續劍尖軌跡。
- 收到 slash event 時回溯最近 trail 作為命中劍痕。
- 根據 slash direction 做命中判定。
- 判斷 Perfect、Good、Weak、Miss。
- 實作方塊切開動畫。
- 實作分數與 Combo。
- 回傳 feedback event 給手機端震動。

建議產出：

- `lib/games/saber/saber_game_page.dart`
- `lib/games/saber/saber_game_state.dart`
- `lib/games/saber/saber_target.dart`
- `lib/games/saber/saber_target_spawner.dart`
- `lib/games/saber/saber_painter.dart`
- `lib/games/saber/slash_trail.dart`

驗收成果：

- 玩家看到方向方塊後，能用手機揮動完成斬擊。
- 電腦端會顯示跟隨手機軌跡的劍痕。
- 方向正確且時間正確時，方塊會切開並加分。
- 方向錯誤或沒揮動時，系統會顯示 Miss。
- 手機會收到 Perfect、Good 或 Miss 的震動回饋。
- 可連續遊玩至少 2 分鐘不崩潰。

### 12.9 Phase 7：Motion Basketball Prototype

目標：基於觸控閘門與 Motion Window 實作投籃動作。玩家按住螢幕準備投籃，放開螢幕觸發出手分析。第一版只做固定距離罰球模式，先驗證觸控閘門 + motion window 分析 + 拋物線回饋的完整流程。

主要工作：

- 建立 `ShootTouchHandler`，管理 touch down / touch up 與 shootHold event。
- 建立 Basketball `ShootDetector`（放在手機端 `lib/controller/`）。
- touch up 時從 `MotionWindowBuffer` 取出前 500-900ms samples。
- 從 window 計算 upwardEnergy、releasePeak（Y 軸過零點）、horizontalNoise。
- 實作最低門檻過濾：upwardEnergy 不足、horizontalNoise 過高、holdDuration < 200ms 時不觸發。
- 產生 `ShootEvent(power, angle, offset, stability, holdDurationMs)`。
- 手機端投籃按住區域 UI 與蓄力提示。
- 建立 2D 拋物線動畫。
- 建立籃框命中區。
- 判斷進球、短球、過高、偏左、偏右。
- 依結果回傳手機震動 feedback。

建議產出：

- `lib/controller/shoot_detector.dart`
- `lib/controller/shoot_touch_handler.dart`
- `lib/games/basketball/basketball_game_page.dart`
- `lib/games/basketball/basketball_game_state.dart`
- `lib/games/basketball/shot_motion_features.dart`
- `lib/games/basketball/basketball_painter.dart`
- `test/shoot_detector_test.dart`

驗收成果：

- 玩家按住螢幕做投籃動作並放開後，電腦端會顯示球飛向籃框。
- 不同 power 與 angle 會產生不同球路。
- 沒有按住螢幕時，任何動作都不會觸發投籃。
- 按住螢幕但沒做投籃動作（靜止或橫甩），放開後不產生 ShootEvent。
- 球通過籃框命中區時判定進球。
- 固定距離投籃 20 次可記錄觸發率（目標 > 90%）與誤觸率。

### 12.10 Phase 8：展示包裝與使用流程

目標：把原型包裝成專題展示時可以順暢操作的產品流程。

主要工作：

- 建立首頁。
- 建立建立房間畫面。
- 建立連線教學畫面。
- 建立遊戲選擇畫面。
- 建立校正提示畫面。
- 建立結算畫面。
- 加入展示模式，讓方塊節奏穩定出現。
- 加入命中、Miss、Combo、結算音效。
- 建立基本設定頁：靈敏度、音量、震動、玩家名稱。
- 建立錯誤提示：連線失敗、手機斷線、感測器不可用。

建議產出：

- `lib/desktop/home_page.dart`
- `lib/desktop/game_select_page.dart`
- `lib/desktop/result_page.dart`
- `lib/controller/controller_status_page.dart`
- `lib/shared/settings/game_settings.dart`

驗收成果：

- 第一次使用者可依照畫面完成連線、校正、開始遊戲、遊玩與結算。
- 展示者不需要手動切換 Debug 工具即可完成 Demo。
- 斷線或感測器錯誤時，畫面有清楚提示。
- Demo 流程可以在 3 到 5 分鐘內完整演示。

### 12.11 Phase 8.5：測試、調整與專題文件

目標：提高展示穩定度，補齊報告、測試紀錄與展示腳本。

主要工作：

- 執行 `flutter analyze`。
- 補上核心邏輯單元測試。
- 進行不同手機的感測器測試。
- 調整 threshold、cooldown、sensitivity 預設值。
- 測試不同 Wi-Fi 或手機熱點環境。
- 量測手機送出 motion event 到電腦顯示反應的端到端延遲。
- 量測遊戲畫面 FPS 與感測器取樣穩定度。
- 建立展示前檢查清單。
- 整理架構圖、流程圖、資料協定表。
- 撰寫專題報告與簡報內容。
- 錄製備用 Demo 影片。

建議產出：

- `docs/test-plan.md`
- `docs/demo-script.md`
- `docs/protocol.md`
- `docs/architecture.md`
- `docs/platform-setup.md`
- `docs/performance-checklist.md`

驗收成果：

- Motion Saber Demo 可穩定執行。
- 主要流程沒有阻斷性錯誤。
- 核心 motion event 與 scoring system 有測試。
- 端到端延遲、FPS、感測器穩定度有基本量測紀錄。
- 展示腳本、備用影片、報告素材準備完成。

### 12.12 Phase 9：擴充 Ping Pong 與多遊戲整合

目標：在 Motion Saber 與 Basketball Prototype 穩定後，將專案擴充為真正的遊戲集合。

主要工作：

- 建立限時投籃模式。
- 建立 Ping Pong 擊球時間窗。
- 建立桌球 2.5D 假透視畫面。
- 建立簡易 AI 對手。
- 將 scoring、feedback、game shell 共用到三個遊戲。

建議產出：

- `lib/games/ping_pong/ping_pong_game_page.dart`
- `lib/games/ping_pong/ping_pong_game_state.dart`

驗收成果：

- 使用者可以從主選單選擇 Motion Saber、Motion Basketball、Motion Ping Pong。
- 三個遊戲都能共用手機控制器連線。
- Basketball 可完成一次投籃與進球判定。
- Ping Pong 可完成一次揮拍回擊判定。

---

## 13. Skills 統一管理設計

這裡的 skills 指專案中的「能力模組」與「可重用功能單元」，例如 motion detection、WebSocket connection、scoring、2.5D visual effect、Saber target spawning。把 skills 統一管理，可以讓開發時知道每個能力目前狀態、負責檔案、依賴關係、驗收標準與後續擴充方向。

### 13.1 Skills 管理目標

- 將每個核心能力獨立建檔管理。
- 明確記錄每個 skill 的用途、輸入、輸出與依賴。
- 讓開發階段可以對應到具體 skills。
- 讓測試與驗收不只看頁面，而是能追蹤能力是否完成。
- 方便後續擴充 Basketball、Ping Pong 或多人模式。

### 13.2 Skills 存放位置

```text
docs/
└── skills/
    ├── README.md
    ├── SKILL_TEMPLATE.md
    ├── platform-setup.md
    ├── motion-sensor.md
    ├── fused-motion.md
    ├── motion-window-trail.md
    ├── motion-detection.md
    ├── calibration.md
    ├── websocket-connection.md
    ├── motion-protocol.md
    ├── feedback-system.md
    ├── performance-diagnostics.md
    ├── scoring-system.md
    ├── visual-2-5d.md
    ├── saber-gameplay.md
    ├── basketball-gameplay.md
    └── ping-pong-gameplay.md
```

### 13.3 Skill 命名規則

| 類型 | 命名方式 | 範例 |
| --- | --- | --- |
| 感測能力 | `motion-*` | `motion-sensor.md`、`fused-motion.md`、`motion-window-trail.md`、`motion-detection.md` |
| 連線能力 | `network-*` 或 `websocket-*` | `websocket-connection.md` |
| 共用系統 | `*-system` | `scoring-system.md`、`feedback-system.md` |
| 視覺能力 | `visual-*` | `visual-2-5d.md` |
| 遊戲能力 | `*-gameplay` | `saber-gameplay.md` |

### 13.4 Skill 文件格式

每個 skill 文件都使用相同格式：

```markdown
# Skill 名稱

## 目的

說明這個 skill 解決什麼問題。

## 使用階段

對應 Phase 編號。

## 輸入

這個 skill 需要哪些資料。

## 輸出

這個 skill 產生哪些資料或效果。

## 主要檔案

列出會實作或影響的程式檔案。

## 依賴 Skills

列出前置能力。

## 實作項目

列出具體工作。

## 驗收標準

列出完成後如何確認可用。

## 測試方式

列出單元測試或手動測試方式。

## 後續擴充

列出第二版可增加的內容。
```

### 13.5 初始 Skills 清單

| Skill | 對應階段 | 優先級 | 說明 |
| --- | --- | --- | --- |
| `motion-protocol` | Phase 2 | 必做 | 定義所有雙端事件格式 |
| `websocket-connection` | Phase 1 | 必做 | 手機與電腦 WebSocket 連線 |
| `platform-setup` | Phase 0 | 必做 | 平台權限、實機設定與桌面連線環境 |
| `motion-sensor` | Phase 3 | 必做 | 手機 IMU 資料讀取 |
| `fused-motion` | Phase 4 | 必做 | 姿態補償、userAcceleration、controller-local motion sample |
| `motion-window-trail` | Phase 4.5 | 必做 | 連續 motion window、trail stream、序列 features |
| `motion-detection` | Phase 4 | 必做 | 將 fused motion data 轉成揮動事件 |
| `calibration` | Phase 4 | 必做 | 建立 neutral position 與校正流程 |
| `visual-2-5d` | Phase 5 | 必做 | 2.5D 平面化視覺效果 |
| `saber-gameplay` | Phase 6 | 必做 | Motion Saber 核心玩法 |
| `scoring-system` | Phase 6 | 必做 | 分數、Combo、判定結果 |
| `feedback-system` | Phase 6 | 必做 | 電腦回傳手機震動與提示 |
| `performance-diagnostics` | Phase 8 | 必做 | 延遲、FPS、感測器取樣穩定度量測 |
| `basketball-gameplay` | Phase 7 | 必做 | 投籃 motion window 與固定距離罰球原型 |
| `ping-pong-gameplay` | Phase 9 | 延後 | 桌球模式 |

### 13.6 Skills 與程式碼對應

```text
docs/skills/motion-detection.md
        ↓
lib/controller/motion_detector.dart
test/motion_detector_test.dart

docs/skills/websocket-connection.md
        ↓
lib/network/websocket_server_service.dart
lib/network/websocket_client_service.dart

docs/skills/saber-gameplay.md
        ↓
lib/games/saber/
```

### 13.7 Skills 狀態管理

每個 skill 使用以下狀態：

| 狀態 | 意義 |
| --- | --- |
| Planned | 已規劃，尚未開始 |
| In Progress | 開發中 |
| Ready for Test | 功能完成，等待測試 |
| Accepted | 已通過驗收 |
| Deferred | 延後處理 |

### 13.8 Skills 管理流程

```text
新增需求
        ↓
判斷是否需要新增 skill
        ↓
建立 skill 文件
        ↓
標記對應 Phase
        ↓
實作主要檔案
        ↓
補上測試方式
        ↓
依驗收標準確認完成
        ↓
狀態改為 Accepted
```

### 13.9 第一版必須完成的 Skills

MVP 展示前至少要完成：

- `websocket-connection`
- `platform-setup`
- `motion-protocol`
- `motion-sensor`
- `fused-motion`
- `motion-window-trail`
- `motion-detection`
- `calibration`
- `visual-2-5d`
- `saber-gameplay`
- `scoring-system`
- `feedback-system`
- `performance-diagnostics`
- `basketball-gameplay`

Ping Pong 可以先保留為 `Deferred`。Basketball 先做固定距離投籃原型，因為它能驗證 motion window 是否能支援揮劍以外的序列型體感。

---

## 14. 建議時程

| 週次 | 目標 | 主要產出 |
| --- | --- | --- |
| Week 1 | 專案整理與架構 | App mode、基礎頁面、資料模型、平台權限清單 |
| Week 2 | WebSocket 連線 | 電腦 server、手機 client、QR/manual connection、join/button event |
| Week 3 | 感測器讀取 | accelerometer、gyroscope、即時數值畫面 |
| Week 4 | 揮動偵測 | 六方向 swing/slash event、power、cooldown |
| Week 5 | Motion Window 與 Trail | 連續軌跡、motionTrail event、trail renderer |
| Week 6 | Motion Saber 核心 | 方塊、連續劍痕、命中判定 |
| Week 7 | Basketball 原型與回饋 | 投籃 window detector、拋物線、震動 |
| Week 8 | 展示包裝與報告 | Demo 穩定化、延遲/FPS 量測、專題文件、展示腳本 |

如果時間較短，優先壓縮 Basketball 與 Ping Pong，保留 Motion Saber 完整度。

---

## 15. 風險與解法

| 風險 | 可能問題 | 解法 |
| --- | --- | --- |
| IMU 無法精準追蹤位置 | 手機無法像 VR 控制器一樣取得絕對位置 | 不做絕對位置，改做方向與事件判定 |
| 延遲影響手感 | 揮動後畫面反應慢 | 使用區網 WebSocket，傳送事件而非 raw data |
| 未量測實際延遲 | 感覺上可用但展示時不穩 | 建立延遲量測 overlay 與測試紀錄 |
| 動作誤判 | 小晃動被判定成揮動 | threshold、cooldown、校正、靈敏度設定 |
| 不同手機感測器差異 | 每台手機數值範圍不同 | 提供校正與 normalize |
| 平台權限遺漏 | 實機無法讀感測器、無法連線或無震動 | Phase 0 建立平台權限清單並提早實機測試 |
| 桌面防火牆阻擋 | 手機無法連到電腦 WebSocket server | 展示前確認防火牆、同網段、手機熱點備案 |
| 展示時網路不穩 | 手機連不上電腦 | 預先測試同一 Wi-Fi，準備手機熱點備案 |
| 三種遊戲做不完 | 範圍過大 | 先完整完成 Motion Saber |
| 真 3D 實作成本過高 | 3D 建模、光照、攝影機與物理會拉高難度 | 第一版採用 Flutter 2.5D 平面化設計 |
| 桌球物理太複雜 | 球路與碰撞難調 | 第一版使用固定路徑與擊球時間窗 |
| 玩家揮動安全 | 手機可能滑落 | 提示小幅度揮動，建議使用腕繩或雙手握持 |

---

## 16. 測試計劃

### 16.1 單元測試

- Motion event JSON encode/decode。
- Direction 判定邏輯。
- Power normalize 邏輯。
- Scoring system。
- Combo multiplier。

### 16.2 手動測試

- 手機可連線電腦。
- 手機斷線後可重新連線。
- 校正後方向判定是否穩定。
- 左右上下揮動是否能正確辨識。
- Motion Saber 命中判定是否符合畫面提示。
- Combo 是否在 Miss 後歸零。
- Feedback event 是否能觸發手機震動。
- QR Code 與手動 IP 連線是否都可用。
- 端到端延遲是否在展示可接受範圍內。

### 16.3 展示前檢查清單

- 電腦端可正常啟動。
- 手機端可正常啟動。
- 兩台設備在同一個 Wi-Fi。
- IP 與 Port 顯示正確。
- QR Code 可掃描且內容正確。
- 平台權限與桌面防火牆已確認。
- 手機可在 10 秒內連線成功。
- 校正按鈕可用。
- 至少連續遊玩 2 分鐘不崩潰。
- Demo 模式方塊速度適中。
- 音效與震動不會干擾講解。
- 已準備手機熱點與備用 Demo 影片。

---

## 17. 最終展示流程

```text
1. 開啟電腦端 Motion Arcade。
2. 點選建立房間。
3. 電腦顯示 IP / QR Code。
4. 開啟手機端 Motion Controller。
5. 手機輸入 IP 或掃描 QR Code。
6. 電腦端顯示玩家已連線。
7. 手機按下校正。
8. 進入 Motion Saber。
9. 玩家依照方塊方向揮動手機。
10. 電腦端顯示劍痕、切割、分數與 Combo。
11. 手機收到命中或失誤震動。
12. 遊戲結束後顯示結算畫面。
13. 若時間允許，展示 Basketball 或 Ping Pong 原型。
```

---

## 18. 報告可強調的技術亮點

### 18.1 跨平台雙端架構

使用 Flutter 同時開發手機控制器與電腦遊戲端，展示 Flutter 在不同裝置上的一致開發體驗。

### 18.2 即時網路同步

使用 WebSocket 在區網內傳遞玩家動作事件，讓手機與電腦畫面能即時互動。

### 18.3 IMU 體感辨識

使用 accelerometer 與 gyroscope 偵測玩家揮動方向、力道與持續時間。

### 18.4 校正與穩定化

透過 neutral position、threshold、cooldown 與 normalize 降低誤判，提高展示穩定度。

### 18.5 可擴充遊戲框架

底層共用 motion event、scoring、feedback、calibration，使未來能擴充更多體感小遊戲。

### 18.6 2.5D 平面化互動設計

專案不依賴完整 3D 引擎，而是使用 Flutter `CustomPainter`、`AnimationController`、`Transform`、透明度、陰影與發光軌跡，將 2D 遊戲邏輯包裝成具有空間感的互動畫面。這能降低實作風險，同時保留體感遊戲需要的速度感、打擊感與展示效果。

---

## 19. 最終專案描述

**Motion Arcade** 是一款以智慧型手機作為體感控制器的跨平台互動遊戲集合。系統由手機端控制器與電腦端主遊戲畫面組成，手機透過加速度計與陀螺儀偵測玩家的揮拍、投籃與斬擊動作，並使用 WebSocket 將動作事件即時同步至電腦端。電腦端負責顯示遊戲畫面、處理命中判定、分數計算與視覺特效，並將結果回傳手機產生震動回饋。專案目標是以低成本設備實現類似 Wii / Switch 的體感互動體驗，並建立一套可擴充的體感遊戲框架。

---

## 20. 推薦實作順序

```text
1. 整理 Flutter 專案結構
2. 完成 Desktop Mode / Controller Mode
3. 完成 WebSocket 連線
4. 完成手機感測器讀取
5. 完成六方向揮動偵測
6. 完成校正與 cooldown
7. 完成 Motion Window 與 Trail Stream (Phase 4.5)
8. 完成 Motion Saber 方塊與劍痕
9. 完成命中判定、分數、Combo
10. 完成手機震動回饋
11. 完成展示流程與結算畫面
12. 視時間擴充 Basketball
13. 視時間擴充 Ping Pong
```

最建議的策略是：**先把 Motion Saber 做到完整、穩定、好展示，再擴充其他遊戲模式。** 這樣專案即使在時間有限的情況下，仍然會有一個完整且有記憶點的成果。
