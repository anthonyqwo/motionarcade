# Saber Gameplay

## 狀態

Accepted

## 目的

實作 Motion Saber 的核心玩法，讓玩家使用手機揮動方向斬擊電腦端方塊。Saber 需要同時使用連續軌跡和離散 slash event：連續軌跡用來畫劍痕與強化手感，離散事件用來做命中、分數與 combo。

## 使用階段

Phase 6

## 劍痕視覺來源

劍尖位置由 `motionTrail` event 的 `tipX`、`tipY`（姿態投影）提供，不使用加速度映射。姿態投影的劍尖在手機停止時不會歸零，在減速時不會反向，可以產生穩定、平滑的連續弧線。

揮動強度由 `strength`（acceleration magnitude）提供，用於控制劍痕粗細與發光。

## Trail 與 Slash 互動流程

```text
1. 遊戲進行中
   電腦端持續接收 motionTrail → 即時畫出劍尖軌跡（淡色、細線）

2. 玩家不揮動時
   劍尖位置指示器仍顯示（姿態不歸零）
   → 玩家可提前瞄準方塊位置

3. 玩家揮劍
   trail 自然跟著姿態畫出弧線
   同時 MotionDetector 偵測到 slash → 送 SlashEvent

4. 電腦端收到 SlashEvent
   → 回溯最近 200-300ms 的 trail samples 作為「命中劍痕」
   → 命中劍痕變亮、加粗、加 glow
   → 比對 slash.direction 與 target.direction
   → 匹配 → 方塊切開動畫 + 分數 + combo
   → 不匹配 → 劍痕顯示但不命中

5. 沒有 SlashEvent 但有 motionTrail
   → 只畫軌跡，不做判定
```

## 輸入

- `SlashEvent`。
- `MotionTrailEvent`（包含 tipX、tipY、strength）。
- 目標方塊方向。
- 目前遊戲時間。

## 輸出

- 劍尖軌跡（連續弧線）。
- 命中劍痕（加亮版軌跡）。
- 劍尖位置指示器（Aiming Reticle）。
- 命中判定。
- 方塊分開切開動畫。
- 分數與 Combo 更新。
- Feedback event。

## 主要檔案

- [saber_game_page.dart](file:///Users/anthonyxwx/code/motionarcade/lib/games/saber/saber_game_page.dart)
- [saber_game_state.dart](file:///Users/anthonyxwx/code/motionarcade/lib/games/saber/saber_game_state.dart)
- [saber_target.dart](file:///Users/anthonyxwx/code/motionarcade/lib/games/saber/saber_target.dart)
- [saber_painter.dart](file:///Users/anthonyxwx/code/motionarcade/lib/games/saber/saber_painter.dart)

## 依賴 Skills

- WebSocket Connection
- Motion Protocol
- Motion Detection
- Motion Window Trail
- 2.5D Visual
- Scoring System
- Feedback System

## 實作項目

- [x] 建立 Saber game state。
- [x] 建立目標方塊生成器與軌道。
- [x] 方塊顯示方向箭頭。
- [x] 接收 slash event。
- [x] 接收 motion trail event。
- [x] 用 tipX/tipY 畫出連續劍尖軌跡弧線。
- [x] 建立劍尖位置指示器（不揮動時半透明顯示）。
- [x] 收到 slash event 時，回溯最近 200-300ms trail 作為命中劍痕。
- [x] 命中劍痕加亮、加粗、加 glow、fade out。
- [x] 依 slash event 產生命中判定。
- [x] 判斷 Perfect/Good/Weak/Miss。
- [x] 方塊切開動畫（沿切角旋轉分裂）。
- [x] 更新分數與 Combo。

## 驗收標準

- [x] 玩家可依照方塊方向揮動手機。
- [x] 電腦端劍尖軌跡會跟隨手機姿態畫出平滑弧線。
- [x] 手機停止揮動時，劍尖位置指示器不會消失或跳回中央。
- [x] 揮劍時劍痕從淡色自動變為命中劍痕（亮色、粗線、glow）。
- [x] 方向正確可命中並加分。
- [x] 方向錯誤或時間錯誤會 Miss。
- [x] 可連續遊玩至少 2 分鐘。

## 測試方式

- 單元測試：執行 `flutter test test/saber_gameplay_test.dart` 驗證目標生成、運動深度更新以及 Miss 邏輯。
- 手動測試：從 Lobby 點擊 "Start Motion Saber" 進入遊戲頁面，揮動實機進行方塊砍切，觀察 Perfect / Good / Weak / Miss 判定及得分倍率累加，並在手機端體驗完美的雙擊及失敗的鈍重震動。
