# Basketball Gameplay

## 狀態

Planned

## 目的

加入投籃模式，讓玩家透過手機投籃動作產生 shoot event，電腦端顯示籃球拋物線與進球判定。

投籃偵測採用「觸控閘門」設計：玩家按住螢幕準備投籃，做出投籃動作後放開螢幕。放開的瞬間作為出手時間錨點，系統取放開前 500-900ms 的 MotionWindow 分析投籃品質，產生 ShootEvent。這個設計讓投籃觸發有明確的時間邊界，不需要靠純 IMU 資料猜測出手時機，大幅降低誤觸率。

## 觸控閘門投籃流程

```text
玩家按住螢幕（touch down）
        ↓
手機送出 shootHold event
MotionWindowBuffer 持續記錄 fused samples
        ↓
玩家做投籃動作（抬手、向上加速、出手）
        ↓
玩家放開螢幕（touch up）= 出手時刻
        ↓
手機取 touch up 前 500-900ms 的 motion window
        ↓
ShootDetector 從 window 擷取 features
        ↓
通過最低門檻 → 產生 ShootEvent
未通過 → 丟棄，不送事件
        ↓
ShootEvent 送到電腦端
電腦端播放拋物線動畫
```

## 為什麼用觸控閘門

| 方案 | 誤觸風險 | 實作難度 | 玩家操作 |
|---|---|---|---|
| 純 IMU state machine | 高，任何向上甩都可能觸發 | 高，需調 state machine | 自然，但不穩定 |
| **觸控閘門** | **低，只有放開螢幕才觸發** | **低，邏輯簡單** | **按住 → 投 → 放開** |
| 固定按鈕觸發 | 零，完全手動 | 最低 | 不自然，沒有體感 |

觸控閘門兼顧體感直覺與偵測可靠度：玩家仍然要做真實的投籃動作，系統才會判定為有效投籃。只是用觸控來標記「我正在投籃」這個意圖，避免走路或揮手被誤判。

## 使用階段

Phase 7

## 輸入

- Touch down / touch up 事件。
- `MotionWindow`：touch up 前 500-900ms 的 fused motion samples。
- Calibrated gameplay-local acceleration 與 rotationRate。

## 輸出

- `ShootEvent(power, angle, offset, stability)`。
- 籃球拋物線動畫。
- 進球或未進判定。
- 分數與 Combo。
- Feedback event。

## 主要檔案

- `lib/controller/shoot_detector.dart`
- `lib/controller/shoot_touch_handler.dart`
- `lib/games/basketball/basketball_game_page.dart`
- `lib/games/basketball/basketball_game_state.dart`
- `lib/games/basketball/shot_motion_features.dart`
- `lib/games/basketball/basketball_painter.dart`
- `test/shoot_detector_test.dart`

## 依賴 Skills

- Fused Motion
- Calibration
- Motion Window Trail
- Motion Protocol
- WebSocket Connection
- 2.5D Visual
- Scoring System
- Feedback System

## ShootDetector 分析邏輯

玩家放開螢幕後，ShootDetector 從 MotionWindowBuffer 取出 touch up 前 500-900ms 的 samples，計算以下 features：

### upwardEnergy

window 中所有 gameplay-local `userAcceleration.y > 0` 的累積能量。投籃的主方向是向上，upwardEnergy 太低代表不是有效投籃。

### releasePeak

找 window 中 Y 軸加速度從正變負的過零點，作為真正的釋放時刻。不使用 magnitude 最大點，因為甩腕 follow-through 可能產生比出手更大的 peak。

### horizontalNoise

X 軸（左右）能量佔總能量的比例。投籃時 X 軸應安靜，如果 noiseRatio > 0.4 代表這是橫甩而非投籃，即使玩家有按住螢幕也判定為無效。

### stability

releasePeak 前後 100ms 內 acceleration 方向的一致性。越穩定代表出手品質越好，對應 ShootEvent 的 stability 欄位。

### 最低門檻（無效投籃過濾）

即使玩家有觸控閘門，以下情況仍判定為無效：

```text
upwardEnergy < minUpwardThreshold → 沒有向上力量
horizontalNoise > 0.4 → 橫向雜訊太多
peakMagnitude < minPeakThreshold → 動作太輕
holdDuration < 200ms → 按太短，可能是誤觸
```

## ShootEvent 參數映射

```text
power    = normalize(upwardEnergy)        → 影響球路距離
angle    = atan2(peakY, peakZ)            → 影響拋物線弧度
offset   = lateralDrift / totalEnergy     → 影響左右偏移
stability = directionConsistency          → 影響命中機率
```

## 實作項目

- [ ] 建立 `ShootTouchHandler`，管理 touch down / touch up 狀態。
- [ ] touch down 時記錄開始時間，通知 MotionWindowBuffer 保持記錄。
- [ ] touch up 時從 MotionWindowBuffer 取出 window samples。
- [ ] 建立 `ShootDetector`，輸入 window samples，輸出 ShootEvent 或 null。
- [ ] 實作 upwardEnergy 計算。
- [ ] 實作 releasePeak 過零點偵測。
- [ ] 實作 horizontalNoise 計算。
- [ ] 實作最低門檻過濾。
- [ ] 建立 `ShotMotionFeatures` model。
- [ ] 建立 `ShootEvent` 參數映射。
- [ ] 手機端 UI 加入投籃按住區域。
- [ ] 按住時顯示蓄力提示動畫。
- [ ] 放開後送出 ShootEvent。
- [ ] 建立 2D 拋物線動畫。
- [ ] 建立籃框命中區。
- [ ] 判斷進球、短球、過高、偏左、偏右。
- [ ] 加入限時投籃模式。

## 驗收標準

- [ ] 玩家按住螢幕做投籃動作並放開後，電腦端會顯示球飛向籃框。
- [ ] 不同 power 與 angle 會產生不同球路。
- [ ] 沒有按住螢幕時，任何動作都不會觸發投籃。
- [ ] 按住螢幕但沒做投籃動作（例如靜止不動或橫甩），放開後不會產生 ShootEvent。
- [ ] 球通過籃框命中區時判定進球。
- [ ] holdDuration < 200ms 的誤觸不會觸發。

## 測試方式

- 手動測試：固定距離罰球模式，按住 → 投 → 放開。
- 單元測試：用模擬 window samples + touch up timestamp 測試 valid / invalid shot。
- 手動測試：投籃 20 次，記錄觸發率（應 > 90%）。
- 手動測試：不按螢幕做揮動 20 次，確認零誤觸。
- 手動測試：按住螢幕但不動直接放開 10 次，確認不觸發。

## 手機端 UI 設計

```text
┌─────────────────────────┐
│   連線狀態：已連線       │
│   目前遊戲：Basketball   │
├─────────────────────────┤
│                         │
│    ┌─────────────────┐  │
│    │                 │  │
│    │   按住準備投籃   │  │
│    │   放開 = 出手    │  │
│    │                 │  │
│    │  ████████░░░    │  │
│    │  蓄力中...       │  │
│    └─────────────────┘  │
│                         │
│  上次投籃：進球！🏀      │
│  力道：0.82  角度：45°   │
├─────────────────────────┤
│   [校正] [設定] [返回]   │
└─────────────────────────┘
```

按住區域可以佔螢幕下半部的大面積，方便玩家單手操作。按住時顯示蓄力進度條（基於 hold 時間），讓玩家知道系統已進入投籃準備狀態。

## 後續擴充

- 三分球模式。
- 移動籃框。
- 連續投籃挑戰。
- 雙手投籃偵測（需要兩台手機）。
- 進階出手角度分析。
