# Basketball Gameplay

## 狀態

Planned

## Pseudo-3D Render Rework

本階段的視覺重構計畫獨立記錄在 [Basketball Pseudo-3D Render Rework Plan](../basketball-pseudo-3d-render-plan.md)。後續調整籃球拋物線、近大遠小、陰影、籃框遮擋、rim/backboard collision 時，先以該文件作為主要流程。

## 目的

建立 Phase 7 的 Basketball 模式。玩法參考舊版 Messenger 籃球小遊戲：玩家連續投籃、進球累積分數，達到一定 streak 後籃框開始移動增加難度。Motion Arcade 版本改用手機體感投籃：玩家按住手機畫面準備投籃，做出投籃動作後放開，手機送出 `ShootEvent`，桌面端播放 2D 拋物線與籃框碰撞動畫。

這不是完整籃球規則，不做運球、防守、犯規或回合制。核心是短循環、好上手、越連進越緊張的街機投籃挑戰。

## 使用階段

Phase 7

## 玩法核心

```text
Lobby 選 Basketball
→ 3 秒倒數
→ Ready Shot，60 秒計時開始
→ 手機按住 + 做投籃動作 + 放開
→ ShootEvent 送到 host
→ 桌面播放球路與籃框碰撞
→ 進球：score +1，streak +1，更新難度
→ 沒進：streak 歸零，保留 best score / best streak
→ 下一球
→ 60 秒到：停止接新投籃，roomPhase = gameOver
→ 桌面顯示結算：winner、score、time、排行榜、FG、best streak
→ Restart：清空本輪 score / streak / ball state
→ Back to room：回 lobby
```

第一版使用 60 秒限時挑戰。玩家在時間內盡量投進更多球；時間到後進入 `gameOver`，手機端可看到結算狀態並可送出 Restart。

## 難度曲線

Messenger 風格的關鍵是前期簡單、10 球後開始移動籃框。

| Streak | 籃框 | 命中容錯 | 說明 |
| --- | --- | --- | --- |
| 0-4 | 固定 | 大 | 學習手感，投得進最重要 |
| 5-9 | 固定 | 中 | 稍微縮小 rim plane 命中區 |
| 10-14 | 左右慢速移動 | 中 | 對齊 Messenger 的移動籃框變難點 |
| 15-24 | 左右中速移動 | 小 | 移動幅度加大，出手 timing 更重要 |
| 25+ | 左右快速移動 | 小 | 高分挑戰；可加入籃框起點變化 |

建議參數：

```text
streak 0-4:   hoopSpeed = 0,   hoopAmplitude = 0,    hitTolerance = 1.00
streak 5-9:   hoopSpeed = 0,   hoopAmplitude = 0,    hitTolerance = 0.88
streak 10-14: hoopSpeed = 0.7, hoopAmplitude = 70,   hitTolerance = 0.82
streak 15-24: hoopSpeed = 1.0, hoopAmplitude = 100,  hitTolerance = 0.76
streak 25+:   hoopSpeed = 1.35, hoopAmplitude = 130, hitTolerance = 0.70
```

## 手機端輸入：觸控閘門

Basketball 使用「觸控閘門」避免誤觸。

```text
玩家按住螢幕（touch down）
→ 手機送 ShootHoldEvent(pressed: true)
→ MotionWindowBuffer 持續記錄 fused samples
→ 玩家做投籃動作
→ 玩家放開螢幕（touch up）= 出手時刻
→ 手機取 touch up 前 500-900ms motion window
→ ShootDetector 產生 ShootEvent 或 null
→ 送出 ShootEvent
→ 手機送 ShootHoldEvent(pressed: false)
```

無效投籃不送 `ShootEvent`，只在手機端顯示「動作太小 / 橫向太多 / 按太短」。

## ShootDetector

輸入：

- `List<FusedMotionSample>`：touch up 前 500-900ms window。
- `holdDurationMs`。
- calibrated gameplay-local acceleration 與 rotationRate。

輸出：

- `ShootEvent(power, angle, offset, stability, holdDurationMs)` 或 null。

### Features

`upwardEnergy`

- window 中 `userAcceleration.y > 0` 的累積能量。
- 代表投籃向上的主要力量。

`releasePeak`

- 找 Y 軸加速度由正轉負附近的出手點。
- 不直接用 magnitude 最大值，避免 follow-through 甩腕誤判。

`horizontalNoise`

- X 軸能量 / 總能量。
- 投籃主動作應該以向上為主，左右橫甩太多視為無效。

`lateralDrift`

- 出手窗口內 X 軸位移/能量傾向。
- 映射到 `ShootEvent.offset`，影響球左右偏移。

`stability`

- release peak 前後約 100ms 的方向一致性。
- 越穩代表出手品質越好，可增加命中容錯，但不直接隨機保送進球。

### 無效投籃門檻

```text
holdDurationMs < 200         → 誤觸
windowSamples 太少           → 資料不足
upwardEnergy < minThreshold  → 沒有向上投籃動作
horizontalNoise > 0.40       → 橫甩，不是投籃
peakMagnitude < minPeak      → 動作太輕
```

### ShootEvent 映射

```text
power     = normalize(upwardEnergy)
angle     = clamp(atan2(peakY, abs(peakZ)), 32°..62°)
offset    = clamp(lateralDrift / totalEnergy, -1..1)
stability = directionConsistency
```

`power` 不應完全線性。建議使用 ease-out，讓普通投籃容易到達籃框，但過強仍會過頭。

```text
mappedPower = 1 - pow(1 - rawPower, 1.6)
```

## 桌面端 2D 物理

第一版不使用完整 physics engine。使用 deterministic 解析式拋物線與簡單碰撞，便於調手感。

### 座標

- 螢幕座標 x 向右、y 向下。
- 球往上飛時 `velocity.y < 0`。
- 重力 `gravity.y > 0`。

### Ball model

```text
BasketballBall
- position: Offset
- previousPosition: Offset
- velocity: Offset
- radius: double
- ageSeconds: double
- collisionCount: int
- resolved: bool
```

### Hoop model

```text
BasketballHoop
- rimCenter: Offset
- rimWidth: double
- rimRadius: double
- leftRimCenter: Offset
- rightRimCenter: Offset
- backboardRect: Rect
- hitTolerance: double
- movementOffset: double
```

### 每幀更新順序

```text
1. previousPosition = position
2. velocity += gravity * dt
3. position += velocity * dt
4. 檢查是否由上往下穿過 rim plane
5. 若穿過且在命中區內 → score
6. 若未 score → resolve rim collision
7. resolve backboard collision
8. 檢查 out of bounds / timeout / collision limit → miss
```

進球判定要在 collision 前做，避免乾淨空心球被 rim 小圓碰撞誤擋。

## 籃框碰撞細節

Basketball 桌面端需要有擦框、彈框、碰背板的細節。碰撞不用做真實剛體，只要手感可信。

### Rim collision：圓對圓

把籃框左右邊緣當成兩個小圓：

```text
leftRimCenter  = rimCenter + Offset(-rimWidth / 2, 0)
rightRimCenter = rimCenter + Offset( rimWidth / 2, 0)
rimRadius = 7
ballRadius = 14
```

碰撞解法：

```text
delta = ball.position - rimCenter
distance = delta.length
minDistance = ball.radius + rimRadius

if distance < minDistance:
  normal = delta / distance
  ball.position = rimCenter + normal * minDistance
  velocityAlongNormal = dot(ball.velocity, normal)
  if velocityAlongNormal < 0:
    ball.velocity -= (1 + restitution) * velocityAlongNormal * normal
    ball.velocity *= damping
    collisionCount += 1
```

建議參數：

```text
rimRestitution = 0.62
rimDamping = 0.92
rimRadius = 7
```

### Backboard collision：圓對矩形

背板可先當垂直矩形，處理最常見的「球從前方碰板」。

```text
if backboard.inflate(ball.radius).contains(ball.position):
  ball.position.x = backboard.left - ball.radius
  ball.velocity.x = -ball.velocity.x * 0.55
  ball.velocity.y =  ball.velocity.y * 0.82
  collisionCount += 1
```

若球已經在背板後方或速度方向不合理，避免重複碰撞卡住。

### 擦框仍可能進球

球碰到 rim 後不要立刻 miss。只要後續仍然：

```text
previousY < rimPlaneY
currentY >= rimPlaneY
velocityY > 0
abs(ball.x - rimCenter.x) <= effectiveRimWidth / 2
```

就判定進球。這樣會有「擦框後掉進去」的手感。

### Miss 條件

```text
ball.position.y > screen.height + ball.radius * 2
ball.position.x < -ball.radius * 3
ball.position.x > screen.width + ball.radius * 3
ball.ageSeconds > 3.5
collisionCount > 5
```

Miss 類型可記錄：

- `short`
- `long`
- `left`
- `right`
- `rimOut`
- `backboardOut`

## 出手到球路映射

初始位置固定在畫面下方中央附近，像 Messenger 小遊戲的球起點。

```text
startX = screen.width / 2
startY = screen.height - 72
```

初速度：

```text
vx = offset * lateralScale
vy = -lerp(720, 1040, power)
arc = lerp(0.86, 1.16, normalizedAngle)
velocity = Offset(vx, vy * arc)
gravity = Offset(0, 1500)
```

建議參數：

```text
ballRadius = 14
gravityY = 1450..1600
lateralScale = 260
minVy = -720
maxVy = -1040
perfectAngle = 45°
```

`stability` 用於微調初速度噪聲與命中容錯：

```text
effectiveTolerance = baseTolerance * lerp(0.85, 1.08, stability)
velocityNoise = lerp(18, 3, stability)
```

## 得分規則

Messenger 風格第一版：

- 進球：`score += 1`
- 連進：`streak += 1`
- Miss：`streak = 0`
- `bestStreak` 保留本輪最高連進。
- 多人各玩家獨立 score / streak / bestStreak。
- 沒有 shared lives。

後續可加：

- 連進 5 顆後每球 +2。
- 連進 10 顆後每球 +3。
- 限時模式總分。

第一版建議只用每球 +1，讓難度和排名容易理解。

## Feedback

進球：

- 手機：`FeedbackEvent(result: perfect/good, haptic: perfect/good)`
- 桌面：球穿網、分數跳動、短粒子/閃光。

Miss：

- 手機：`FeedbackEvent(result: miss, haptic: miss)`
- 桌面：球掉落或彈出，顯示 short / left / right / rim out。

無效投籃：

- 不送 ShootEvent。
- 手機本地顯示原因，可用 light haptic，不干擾 host。

## 手機端 UI

Basketball selected 時，Controller Home 額外顯示投籃 pad。

```text
┌─────────────────────────┐
│ Room: Basketball         │
│ Score 12   Streak 4      │
├─────────────────────────┤
│                         │
│   HOLD TO AIM           │
│                         │
│   RELEASE TO SHOOT      │
│                         │
│   charge bar            │
│                         │
├─────────────────────────┤
│ Last: Rim out            │
│ Power .78  Angle 44°     │
└─────────────────────────┘
```

互動：

- touch down：進入 aiming 狀態，送 `ShootHoldEvent(pressed: true)`。
- hold 中：顯示 charge progress，建議 0.2s 到 1.2s 填滿。
- touch up：從 MotionWindowBuffer 取 samples，執行 ShootDetector。
- valid：送 `ShootEvent`。
- invalid：顯示原因，不送事件。

## 桌面端 UI

視覺風格：

- 乾淨 2D 球場背景。
- 籃框在上半部，球在下方。
- 球路有輕微 trail。
- 籃框移動時保持清楚可讀，不要太花。
- 分數與 streak 置頂，排行榜靠側邊或底部。

畫面元素：

- Backboard。
- Rim / net。
- Ball。
- Shot trail。
- Score / streak / best。
- Difficulty indicator。
- Player leaderboard。

## Room / Controller 整合

沿用 Phase 6.5：

- 手機選 `GameId.basketball`。
- RoomPage 接 `GameCommandEvent.selectGame` 更新 selected game。
- `startGame` 進 BasketballGamePage。
- BasketballGamePage broadcast `RoomStateEvent`：
  - `selectedGame = basketball`
  - `roomPhase = countdown / playing / gameOver`
  - `playerScores`
  - `message`
- `restartGame` 呼叫 BasketballGameState restart。
- `backToRoom` 回 RoomPage。

## 主要檔案

新增：

- `lib/controller/shoot_detector.dart`
- `lib/controller/shoot_touch_handler.dart`
- `lib/games/basketball/basketball_game_page.dart`
- `lib/games/basketball/basketball_game_state.dart`
- `lib/games/basketball/basketball_painter.dart`
- `lib/games/basketball/basketball_physics.dart`
- `lib/games/basketball/shot_motion_features.dart`
- `test/shoot_detector_test.dart`
- `test/basketball_physics_test.dart`
- `test/basketball_gameplay_test.dart`

修改：

- `lib/controller/controller_home_page.dart`
- `lib/desktop/room_page.dart`
- `lib/shared/models/motion_event.dart`（若需新增 shot result state）
- `lib/network/motion_event_codec.dart`

## 實作順序

### Step 1：2D Physics Model

- 建立 `BasketballBall`。
- 建立 `BasketballHoop`。
- 建立 `BasketballPhysics.step(dt)`。
- 實作 rim plane scoring。
- 實作 left/right rim circle collision。
- 實作 backboard collision。
- 實作 miss/out-of-bounds。
- 單元測試：
  - 乾淨穿過 rim plane 得分。
  - 偏左/偏右不進。
  - 撞 rim 後 velocity 反彈。
  - 撞背板後 x velocity 反向。
  - 擦框後仍可進。

### Step 2：Basketball Game State

- 建立 score / streak / bestStreak。
- 建立 player stats map。
- 接收 `ShootEvent` 產生 ball。
- 每幀更新 ball physics。
- score/miss 後等待下一球。
- 依 streak 更新 difficulty。

### Step 3：Basketball Painter

- 畫背景、背板、rim、net、ball、trail、HUD。
- 確認籃框移動與球路都清楚。
- Miss / score 動畫簡潔，避免遮住球。

### Step 4：ShootDetector

- 使用 MotionWindowBuffer snapshot。
- 實作 features 與 invalid filtering。
- 映射 `ShootEvent`。
- 單元測試 valid / invalid。

### Step 5：Controller 投籃 UI

- Basketball selected 時顯示 hold/release shot pad。
- touch down/up 串 `ShootHoldEvent` 與 `ShootDetector`。
- 顯示 last shot result。
- 維持 Debug 頁可看 motion window / recent events。

### Step 6：Room 整合

- RoomPage start basketball。
- BasketballGamePage broadcast RoomStateEvent。
- 手機可 restart/back。
- 多人 leaderboard。

## 驗收標準

- [ ] 手機選 Basketball 後可從手機或桌面開始遊戲。
- [ ] 手機按住、投籃、放開後，桌面產生球路。
- [ ] 不按住時任何揮動不會出手。
- [ ] 按住但不動直接放開不會出手。
- [ ] 有效投籃會依 power / angle / offset 產生不同球路。
- [ ] 球乾淨穿過 rim plane 會得分。
- [ ] 球撞 rim 會反彈，不會直接消失。
- [ ] 球撞 backboard 會反彈。
- [ ] 擦框後仍可能進球。
- [ ] 連進 10 球後籃框開始左右移動。
- [ ] Miss 後 streak 歸零但 bestStreak 保留。
- [ ] 手機可看到 score / streak / last result。
- [ ] 多人時各玩家獨立 score / streak，桌面顯示排行榜。
- [ ] `flutter analyze --no-pub` 通過。
- [ ] `flutter test --no-pub` 通過。

## 測試方式

單元測試：

- `flutter test test/basketball_physics_test.dart`
- `flutter test test/shoot_detector_test.dart`
- `flutter test test/basketball_gameplay_test.dart`

手動測試：

- 投籃 20 次，確認有效動作觸發率 > 90%。
- 不按手機畫面揮動 20 次，確認 0 誤觸。
- 按住但靜止放開 10 次，確認不送 ShootEvent。
- 故意偏左 / 偏右 / 太短 / 太強，確認 miss 類型合理。
- 故意擦框，確認球會彈而不是瞬間消失。
- 連進 10 球後確認籃框開始移動。

## 後續擴充

- 自訂限時長度。
- 三分線 / 遠距離模式。
- 風向或移動出手點。
- 連進加倍得分。
- 球網變形動畫。
- 不同玩家球色。
- Leader-only start/restart 或多人 ready/vote。
