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

## 重要流程：三命生存制遊戲循環

Motion Saber 不使用固定 60 秒倒數作為結束條件。核心循環採用三命生存制，讓展示時可以依玩家表現自然延長或結束：

```text
Start Motion Saber
→ 3 秒倒數
→ Playing
→ 命中：該玩家加分、加 combo、加 multiplier
→ Miss / wrong direction：全隊 shared lives -1；若可歸屬玩家，該玩家 combo 歸零
→ shared lives 歸零
→ Game Over
→ Result / Retry / Back to Room
```

規則：

- 全隊共用 `sharedLives = 3`，多人時也是同一組生命。
- 每位玩家獨立計分、combo、max combo、hit/miss 統計。
- target 超過 hit zone 沒砍到：扣 shared life，若能歸屬玩家則記入該玩家 miss；目前 timeout miss 先只扣全隊生命。
- 砍錯方向：扣 shared life，該 slash 的玩家記 miss 並 reset combo。
- 沒有有效 target 時亂揮：不扣命，避免體感輸入誤觸造成挫折。
- 時間不限制遊戲長度，只記錄 survived time 作為結果統計。
- `gameOver` 後停止 spawn 與判定，但保留 trail、粒子、miss fade 自然淡出。

多人預留：

- 目標與生命是共同關卡狀態。
- 分數是 player-local 狀態，UI 顯示 leaderboard。
- feedback 仍送回觸發事件的玩家；timeout miss 可廣播全體 warning。
- 未來若要加合作/競爭規則，不改 shared lives，只擴充 player score table。

## 重要流程：Hot Reload 安全欄位

Flutter hot reload 不會重新建構已存在的物件。若在開發中替 `State`、game state、target model、streamer 等 live instance 新增非 nullable instance field，舊 instance 不會執行新的 constructor，該欄位可能仍是 `null`，下一幀讀取時會出現：

```text
type 'Null' is not a subtype of type 'double' of 'function result'
```

已踩過的例子：

- `MotionTrailStreamer.rotationActiveThreshold`：新增成 `final double` 後，舊 streamer instance 在 hot reload 後讀欄位 crash。
- `SaberTarget.missProgress`：新增成 `double` 後，舊 target instance 在 `update()` 讀欄位 crash。
- `SaberTarget.row`、`SaberGameState._random`：同樣屬於 live instance 新欄位，應使用 fallback。

安全做法：

```dart
class SaberTarget {
  SaberTarget({double row = 0.0, double missProgress = 0.0})
      : _row = row,
        _missProgress = missProgress;

  final double? _row;
  double? _missProgress;

  double get row => _row ?? 0.0;
  double get missProgress => _missProgress ?? 0.0;
  set missProgress(double value) => _missProgress = value;
}
```

規則：

- 新增到 live instance 的欄位，優先用 nullable backing field + getter fallback。
- 如果只是常數設定，優先用 `static const` 或 method local default，避免舊 instance 要讀新欄位。
- `late final` 和新的 non-nullable `final` 對 hot reload 風險最高，除非確定會 full restart。
- 修改 constructor 參數、target/state 資料結構、ticker 更新欄位後，實機測試前做一次 full restart。
- 若 crash stack 指到「新欄位 getter」且訊息是 `Null is not a subtype`，先檢查是否為 hot reload 舊 instance，不要誤判成遊戲邏輯或感測器問題。

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
- Shared lives、run phase、survived time 與 leaderboard。
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
- [x] 新增 live instance 欄位時使用 hot reload 安全 fallback，避免舊 target/state 在下一幀讀到 null。
- [x] 建立三命生存制：倒數、playing、game over。
- [x] 多人共用 shared lives。
- [x] 多人各自計分與 combo，並顯示 leaderboard。

## 驗收標準

- [x] 玩家可依照方塊方向揮動手機。
- [x] 電腦端劍尖軌跡會跟隨手機姿態畫出平滑弧線。
- [x] 手機停止揮動時，劍尖位置指示器不會消失或跳回中央。
- [x] 揮劍時劍痕從淡色自動變為命中劍痕（亮色、粗線、glow）。
- [x] 方向正確可命中並加分。
- [x] 方向錯誤或時間錯誤會 Miss。
- [x] 可連續遊玩至少 2 分鐘。
- [x] shared lives 歸零後停止產生新 target 並顯示 Game Over。
- [x] 多人時任一玩家 Miss 都扣共用生命，但分數與 combo 各自計算。

## 測試方式

- 單元測試：執行 `flutter test test/saber_gameplay_test.dart` 驗證目標生成、運動深度更新以及 Miss 邏輯。
- 手動測試：從 Lobby 點擊 "Start Motion Saber" 進入遊戲頁面，揮動實機進行方塊砍切，觀察 Perfect / Good / Weak / Miss 判定及得分倍率累加，並在手機端體驗完美的雙擊及失敗的鈍重震動。
- 手動測試：新增或修改 `SaberTarget` / `SaberGameState` 欄位後，先 hot reload 檢查 fallback 不 crash，再 full restart 確認完整新節奏。
- 手動測試：故意錯砍或漏砍三次，確認 shared lives 歸零並進入 Game Over。
