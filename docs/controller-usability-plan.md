# Controller Usability Plan

## 狀態

Ready for Test

## 目的

目前 Phone Controller 主頁同時承擔連線、體感操作、感測器偵錯、封包診斷、震動測試等工作，實機操作時資訊太雜。下一步先做一個實用性整理：把手機主頁變成玩家真正會使用的控制台，把 debug 資訊集中到獨立頁面，並讓手機能參與房間操作，例如選遊戲、開始、restart，以及看到自己的分數與遊戲狀態。

這一階段建議放在 **Phase 6.5 Controller UX / Room Control**，介於 Motion Saber 完成與 Phase 7 Basketball 之前。它不新增新遊戲，而是把現有 Saber MVP 變成更像完整產品的操作流程。

## 實作結果

- 已新增 `GameCommandEvent`，手機可送出 select/start/restart/back command。
- 已新增 `RoomStateEvent`，host 會把 selected game、room phase、scoreboard、shared lives、survived time 同步給手機。
- Phone Controller 主頁已改為玩家控制台，debug panels 已移到 `ControllerDebugPage`。
- 手機可選遊戲；目前 Motion Saber 可開始，Basketball / Ping Pong 保留為 planned 選項。
- 手機可在 Saber 遊戲中 restart 或 back to room。
- 手機可看到自己的 score、combo、hit/miss、shared lives 與排行榜摘要。
- 桌面端 RoomPage 仍保留本機 Start 按鈕，同時接受手機端 command。
- 已通過 `flutter analyze --no-pub` 與 `flutter test --no-pub`。

## 目標

1. 手機主頁只保留玩家操作需要的資訊與按鈕。
2. Debug 資訊移到專門的 Debug 頁面，平常不干擾遊玩。
3. 手機可以選擇房間目前要玩的遊戲。
4. 手機可以開始遊戲、restart 遊戲、回到房間等待狀態。
5. 手機可以看到自己的分數、combo、隊伍生命、遊戲階段與排行榜摘要。
6. 桌面端仍然是權威狀態來源，手機只送 request / command，不直接決定最終 game state。

## 非目標

- 不在這階段實作 Basketball 玩法本體。
- 不在這階段做複雜權限系統、房主轉移或投票機制。
- 不把所有桌面 UI 都搬到手機；手機只提供常用操作與個人狀態。
- 不要求離線重連完整恢復所有歷史資料，但要能在重新 Join 後收到最新 room state。

## 目前問題

Phone Controller 主頁目前包含：

- 連線輸入與 QR scan。
- connection / motion / direction / power / trail packets/s 狀態格。
- `FusedMotionDebugPanel`。
- `SensorDebugPanel`。
- Start/Stop motion。
- Sensitivity。
- `RecentMotionEventsPanel`。
- Calibration status。
- Send test event。
- Calibrate grip。
- Haptic Simulator。

實際玩家需要的是：連線、開始偵測、校正、知道現在房間狀態、選遊戲、開始或重開、看到自己分數。其餘 raw sensor、fused motion、recent events、packet rate、haptic simulator 屬於 debug，應移到 Debug 頁。

## 手機端頁面規劃

### 1. Controller Home

主頁改為「玩家控制台」，只保留遊玩必要內容。

建議區塊：

- Connection card
  - room address input / scan QR。
  - Connect / Disconnect。
  - connected player name / id。
- Room card
  - current selected game。
  - run phase：Lobby / Countdown / Playing / Game Over。
  - connected players count。
- Game control card
  - game selector：Motion Saber、Basketball placeholder、Ping Pong disabled。
  - Start game。
  - Restart。
  - Back to room / Stop game。
- Player score card
  - own score。
  - combo / max combo。
  - hit / miss。
  - team shared lives。
  - survived time。
- Motion readiness card
  - Start/Stop motion。
  - Calibrate grip。
  - sensitivity compact selector。
- Debug entry
  - 一個小的 `Debug` icon button 或 `Open debug panel` 按鈕。

主頁不顯示：

- raw accelerometer / gyroscope。
- fused quaternion / gravity / rotation raw values。
- recent detected events list。
- haptic waveform simulator。
- per-second trail diagnostics。

### 2. Controller Debug Page

新增 `ControllerDebugPage`，從主頁右上角或 Debug card 進入。

放入：

- `FusedMotionDebugPanel`。
- `SensorDebugPanel`。
- `RecentMotionEventsPanel`。
- `HapticSimulatorPanel`。
- Trail transport diagnostics：
  - UDP / WebSocket。
  - packets/s。
  - samples/s。
  - current status。
- Last event / last feedback。
- Manual test controls：
  - Send test event。
  - Trigger haptic presets。

Debug 頁仍使用同一個 controller state，不重新建立 sensor service、websocket client 或 motion streamer。

## 桌面端房間規劃

RoomPage 目前桌面端才能按 `Start Motion Saber`。下一步桌面端應保留控制能力，但同時接受手機命令。

桌面端新增狀態：

- `selectedGame`
  - `motionSaber`
  - `basketball`
  - `pingPong`
- `roomPhase`
  - `lobby`
  - `countdown`
  - `playing`
  - `gameOver`
- `activeGame`
- `lastGameResult`

桌面端仍是 authoritative host：

- 手機送「我想選 Saber」。
- Host 更新 `selectedGame`。
- Host broadcast 最新 `RoomStateEvent`。
- 手機 UI 根據 host 回傳狀態更新，不自行假設成功。

## MotionEvent 協定規劃

建議新增 shared room/game control events。

### Controller to host

`GameCommandEvent`

用途：手機要求 host 執行房間或遊戲操作。

欄位：

- `playerId`
- `command`
  - `selectGame`
  - `startGame`
  - `restartGame`
  - `backToRoom`
- `gameId`
  - `motionSaber`
  - `basketball`
  - `pingPong`
- `requestId`
- `timestamp`

規則：

- `selectGame` 只在 lobby / gameOver 時有效。
- `startGame` 只在 lobby 且至少一位 player connected 時有效。
- `restartGame` 只在 playing / gameOver 時有效。
- `backToRoom` 可在 playing / gameOver 時讓 host 回到 lobby。
- Host 收到無效 command 時不 crash，可回傳目前 state 或 error message。

### Host to controller

`RoomStateEvent`

用途：host 廣播房間與遊戲狀態，讓所有手機同步 UI。

欄位：

- `selectedGame`
- `availableGames`
- `roomPhase`
- `players`
- `canStart`
- `canRestart`
- `canBackToRoom`
- `scoreboard`
- `teamState`
  - `sharedLives`
  - `maxSharedLives`
  - `survivedSeconds`
- `message`

`PlayerScoreSnapshot`

可作為 `RoomStateEvent.scoreboard` 中的 structured item。

欄位：

- `playerId`
- `name`
- `score`
- `combo`
- `maxCombo`
- `hits`
- `misses`
- `rank`

## Saber 整合規劃

SaberGameState 已有：

- run phase。
- shared lives。
- survived seconds。
- per-player stats。
- restartRun。

下一步要做的事情：

- 在 Saber 狀態變更時產生 `RoomStateEvent`。
- hit / miss / countdown / gameOver / restart 後 broadcast 最新 scoreboard。
- controller 收到 state 後更新自己的 score card。
- `restartGame` command 呼叫 Saber 的 `restartRun()`。
- `backToRoom` command pop game page 或讓 host active game 回到 lobby。

注意事項：

- 不要讓手機直接改 `SaberGameState`，只能送 command。
- 遊戲頁和 room page 要共用同一個 state broadcast 流程，避免 lobby 和 playing 使用兩套規則。
- Game Over overlay 的 Retry button 仍可保留在桌面端，同時手機也可以按 Restart。

## 多人規則

MVP：

- 每位玩家手機都能看到排行榜。
- 每位玩家都能看到自己的 score / combo。
- 每位玩家都能送 game command。
- Host 對 command 做基本 phase guard。

之後可加：

- 第一位加入者是 room leader。
- 只有 leader 可以 start/restart/select。
- 其他玩家可以 ready / vote。

這階段先不做 leader 權限，避免卡住體驗整理。

## UI 詳細改動

### Controller Home 版面順序

```text
Phone Controller
→ Connection card
→ Room status card
→ Game control card
→ Player score card
→ Motion readiness card
→ Debug entry
```

### Debug Page 版面順序

```text
Controller Debug
→ Connection diagnostics
→ Trail transport diagnostics
→ Fused Motion Debug
→ Sensor Debug
→ Recent Motion Events
→ Haptic Simulator
→ Manual test event
```

### Desktop Room Page

新增：

- selected game segmented control 或 list。
- 顯示「Phone can also control room」狀態。
- 接收到手機 command 後，在 event log 顯示 `command:startGame from p1`。

## 檔案規劃

新增：

- `lib/controller/controller_debug_page.dart`
- `lib/controller/controller_room_state_card.dart`
- `lib/controller/controller_game_controls.dart`
- `lib/shared/models/game_command.dart` 或直接擴充 `motion_event.dart`
- `test/room_game_command_test.dart`

修改：

- `lib/controller/controller_home_page.dart`
  - 移除主頁 debug panels。
  - 引入 debug page navigation。
  - 接收並保存 room state。
  - 顯示分數與 game controls。
- `lib/controller/qr_scan_page.dart`
  - 維持現有連線流程。
- `lib/shared/models/motion_event.dart`
  - 新增 `GameCommandEvent`、`RoomStateEvent`。
- `lib/network/motion_event_codec.dart`
  - 新增 encode/decode。
- `lib/network/motion_event_dispatcher.dart`
  - 新增 onGameCommand / onRoomState。
- `lib/desktop/room_page.dart`
  - 管理 selectedGame。
  - 處理手機 command。
  - broadcast room state。
- `lib/games/saber/saber_game_page.dart`
  - 將 player stats / run phase 對外回報給 room state broadcast。
  - 接受 restart command。
- `test/widget_test.dart`
  - 更新 controller 主頁預期。

## 實作順序

### Step 1：建立 Debug Page

- 新增 `ControllerDebugPage`。
- 把 `FusedMotionDebugPanel`、`SensorDebugPanel`、`RecentMotionEventsPanel`、`HapticSimulatorPanel` 搬進去。
- 主頁只留 Debug 入口。
- 測試 controller 主頁不再顯示 raw debug panels，debug page 可進入。

### Step 2：新增 Room/Game state 協定

- 新增 `GameCommandEvent`。
- 新增 `RoomStateEvent`。
- 補 motion codec 測試。
- 補 dispatcher 測試。

### Step 3：Host 接手機命令

- RoomPage 支援 selected game。
- 手機 `selectGame` command 更新 host selected game。
- 手機 `startGame` command 開始目前 selected game。
- Host broadcast `RoomStateEvent`。

### Step 4：Controller 顯示房間與遊戲狀態

- Controller 監聽 `RoomStateEvent`。
- 主頁顯示 current game、phase、players count、canStart/canRestart。
- Game controls 根據 can flags enable / disable。

### Step 5：Saber 分數同步與 Restart

- SaberGameState 變更後產生 scoreboard snapshot。
- Host broadcast `RoomStateEvent`。
- Controller 顯示 own score、combo、shared lives、leaderboard top。
- 手機 restart command 呼叫 Saber restart。

## 驗收標準

- Controller 主頁不再出現 Fused Motion raw panel、Sensor raw panel、Recent Events、Haptic Simulator。
- Controller 主頁可以進入 Debug 頁，Debug 頁能看到上述資訊。
- 手機連線後可看到目前 selected game。
- 手機可選 Motion Saber。
- 手機可按 Start Game，桌面端進入 Saber。
- Saber 遊玩時手機可看到自己的 score / combo / shared lives。
- Saber Game Over 後手機可按 Restart，桌面端重新倒數開始。
- 多手機連線時，每台手機都看到相同 shared lives，但各自看到自己的 score。
- 所有新增 event codec 測試通過。
- `flutter test --no-pub` 通過。

## 風險與注意事項

- Host 是權威狀態來源，手機 UI 不要 optimistic update 過頭。
- Game command 與 motion trail 都走 WebSocket command path；trail UDP 不承擔控制命令。
- Restart / Back to room 會牽涉 Navigator 狀態，建議 host page 持有 command handler，不要讓 controller 直接操作 route。
- Hot reload 新增 state 欄位時，沿用 nullable backing field 或 getter fallback 原則。
- 多人 command 權限先維持簡單，避免 leader/vote 系統拖慢這次 UX 修正。
