# Basketball Pseudo-3D Render Rework Plan

Status: Implemented, first pass

## Implementation Notes

2026-06-10 first pass:

1. Added court-space primitives in `lib/games/basketball/basketball_court_space.dart`.
2. Added pseudo-3D projection in `lib/games/basketball/basketball_projection.dart`.
3. Reworked `lib/games/basketball/basketball_physics.dart` so shot movement, scoring, rim collision, and backboard collision use virtual `(x, y, z)` coordinates.
4. Reworked `lib/games/basketball/basketball_painter.dart` so ball scale, shadow, trail, and hoop occlusion all come from the projector.
5. Updated `lib/games/basketball/basketball_game_state.dart` so resolved balls keep falling through the same court-space physics until they leave the visible screen.
6. Added projection tests and updated basketball physics tests.

Verification:

```text
flutter analyze --no-pub
flutter test --no-pub
```

## 目標

把目前籃球遊戲從「2D 螢幕座標加少量縮放」改成「內部虛擬球場座標 + 2D 投影渲染」。

這次重構不是導入真正 3D 引擎，而是用復古街機常見的 Pseudo-3D 做法，讓球看起來真的從近處拋向遠處籃框，並讓大小、陰影、籃框遮擋、碰撞判定互相對得上。

## 目前問題

1. 球的位置主要還是螢幕 2D 物理，深度感是靠時間與速度推測，沒有真正的 `Z` 深度。
2. 籃球縮放目前依賴投出後時間，和球實際離籃框多遠沒有強綁定。
3. 上升時在籃框前、下降時在籃框後的效果目前是用速度方向推測，遇到碰撞或特殊軌跡會不穩。
4. 左右投擲是直接影響螢幕橫向速度，容易看起來飄太多，不像往籃框左右偏移。
5. 陰影沒有完整跟著地板深度走，玩家不容易判斷球的高度與落點。
6. 進球、籃框碰撞、背板碰撞使用 2D 畫面判定，容易和視覺上的籃框位置產生落差。

## 核心原則

模擬座標和畫面座標要分開。

物理與命中判定使用虛擬球場座標：

```text
x: 左右位置，0 是籃框中心線，負數偏左，正數偏右
y: 高度，0 是地板，數值越大代表球越高
z: 深度，0 是玩家近端，1 是籃框平面
```

畫面渲染時，再把 `(x, y, z)` 投影成 Flutter 畫布上的 `Offset`、球大小、陰影位置與圖層順序。

## 新架構

### 1. Court Space

新增一個球場空間模型，例如：

```dart
class CourtPoint {
  final double x;
  final double y;
  final double z;
}

class ProjectedBall {
  final Offset center;
  final Offset shadowCenter;
  final double ballScale;
  final double shadowScale;
  final double shadowOpacity;
  final double sortDepth;
}
```

建議新增檔案：

```text
lib/games/basketball/basketball_court_space.dart
lib/games/basketball/basketball_projection.dart
```

### 2. Projection

先不要做太複雜的真透視矩陣，改用可調參數的復古投影。這比較適合目前簡潔 UI，也比較容易微調手感。

```text
depthT = clamp(z, 0, 1)
floorY = lerp(frontFloorY, hoopFloorY, easeOut(depthT))
courtHalfWidth = lerp(frontHalfWidth, hoopHalfWidth, depthT)

screenX = centerX + x * courtHalfWidth
screenY = floorY - y * verticalScale * perspectiveScale
ballScale = lerp(nearBallScale, farBallScale, depthT)
```

初始建議值：

```text
nearBallScale: 1.18
farBallScale: 0.88
frontFloorY: 畫面高度 0.86
hoopFloorY: 畫面高度 0.33
frontHalfWidth: 畫面寬度 0.42
hoopHalfWidth: 畫面寬度 0.16
```

這樣可以保留近大遠小，但不會像之前那樣縮放太誇張。

### 3. Shot Arc

投球不要再直接用螢幕 `vx/vy` 當主邏輯，而是改成一條球場空間拋物線。

```text
t: 0 到 1，代表球從出手點飛到籃框平面的進度
z = t
x = lerp(releaseX, aimX, easeOut(t))
y = releaseHeight * (1 - t) + rimHeight * t + arcPeak * 4 * t * (1 - t)
```

感應器輸入對應：

```text
power -> arcPeak、travelTime、出手速度
angle -> arcPeak、是否偏平或偏高
offset -> aimX，但需要比現在更強的 damp，避免左右飄太多
```

建議第一版：

```text
aimX = clamp(offset * 0.42, -0.48, 0.48)
arcPeak = lerp(0.54, 0.86, power)
travelTime = lerp(0.92s, 0.72s, power)
```

球通過籃框後如果沒進，才進入掉落階段，並等球離開螢幕後生成下一顆。

### 4. Shadow Mechanics

陰影必須使用同一套投影，但高度固定在地板：

```text
shadowPoint = CourtPoint(ball.x, 0, ball.z)
```

陰影大小和透明度用球高度控制：

```text
heightT = clamp(ball.y / maxArcHeight, 0, 1)
shadowScale = lerp(1.0, 0.55, heightT)
shadowOpacity = lerp(0.22, 0.08, heightT)
```

玩家看到「球」和「地板陰影」分離，就會自然感覺球正在空中飛。

### 5. Hoop Layering

籃框拆成多層畫，不再只用一個 `_drawHoop`。

建議渲染順序：

```text
1. 背景
2. 地板與透視線
3. 籃板後層、後網
4. 球的陰影
5. 球
6. 籃框前緣、前網、紅色 rim
7. 分數與 UI
```

球是否被前框遮住，不再只看 `velocity.dy`，而是看球的 `z` 和 `y`：

```text
ballInHoopZone = abs(ball.z - hoopZ) < rimDepth
ballNearRimHeight = abs(ball.y - rimHeight) < rimHeightBand
```

如果球在籃框區域內或已經通過籃框平面，前框層就畫在球上方。球還在飛向籃框前方時，球畫在前框上方，避免上升時被籃框不自然擋住。

### 6. Scoring And Collision

進球判定改用籃框平面，而不是螢幕座標。

```text
crossedHoopPlane = previous.z < hoopZ && current.z >= hoopZ
descending = current.y < previous.y
insideRimX = abs(current.x) <= rimHalfWidth
insideRimY = abs(current.y - rimHeight) <= rimHeightTolerance
```

符合以上條件就進球。

籃框碰撞：

```text
nearHoopPlane = abs(current.z - hoopZ) <= rimDepth
nearRimHeight = abs(current.y - rimHeight) <= rimCollisionHeight
hitLeftOrRightRim = abs(abs(current.x) - rimHalfWidth) <= ballRadiusCourt
```

碰撞後調整 `x/z/y` 的速度或切換到反彈狀態，讓球往合理方向彈開。

背板碰撞：

```text
current.z > hoopZ
abs(current.x) <= backboardHalfWidth
current.y 在 backboardHeightRange 內
```

撞背板時反轉 `vz`，稍微降低 `vy`，並保留一點 `x` 方向，避免球突然直直掉下。

## 開發階段

### Phase 1: 投影模型

新增 `BasketballProjector`，把虛擬 `(x, y, z)` 投影成畫面座標。

驗收：

1. `z` 越大，球越靠近籃框位置。
2. `z` 越大，球只小幅縮小。
3. `y` 只影響球離地高度，不影響陰影的地板位置。

### Phase 2: 拋物線投球

把投球狀態改成 court-space shot arc。

驗收：

1. 球從畫面近端出手，沿拋物線飛向籃框。
2. 力道影響高度與飛行時間。
3. 左右偏移只影響籃框平面落點，不會造成螢幕左右亂飄。

### Phase 3: 陰影與大小

將球、陰影、大小全部交給 projector 計算。

驗收：

1. 球飛高時陰影變小、變淡。
2. 球靠近籃框時大小變化自然，不會突然跳。
3. 球掉落出畫面前不產生下一顆。

### Phase 4: 籃框分層

把籃框拆成後層和前層。

驗收：

1. 球飛向籃框前方時不會被籃框擋住。
2. 球下降進入籃框區域時，前框可以遮住球的一部分。
3. 球不會看起來從籃框底下穿過。

### Phase 5: 進球與碰撞

把進球、rim、backboard 判定改用 court-space。

驗收：

1. 進球判定和視覺位置一致。
2. 打到左右框會有合理彈跳。
3. 打到背板會往前或往下彈，不會卡在隱形牆。
4. 上升階段不會撞到籃框底部。

### Phase 6: 調參與測試

新增或更新測試：

```text
test/basketball_projection_test.dart
test/basketball_physics_test.dart
test/shoot_detector_test.dart
```

測試重點：

1. `Projector` 的深度越遠，球越接近籃框且縮放變小。
2. 陰影永遠在地板投影上。
3. 中央正常力道可以進球。
4. 左右偏移會改變命中點，但不會過度偏移。
5. rim collision 不會在上升穿越前錯誤觸發。

## 不在第一版做的事

1. 不導入真正 3D 引擎。
2. 不先做完整 Mode 7 地板貼圖。
3. 不先做籃球 sprite sheet 旋轉動畫，保留 emoji 或現有 bitmap 表現。
4. 不先做複雜網子物理，前後網只做視覺分層。

## 完成定義

1. 投球看起來有明確的近到遠拋物線。
2. 近大遠小是細微且自然的，不會讓球突然變形。
3. 陰影能清楚暗示高度與落點。
4. 籃框遮擋和球的位置一致，不再像從籃框底下穿過。
5. 左右投擲可控，偏移幅度小但能被玩家感覺到。
6. `flutter analyze --no-pub` 通過。
7. `flutter test --no-pub` 通過。
