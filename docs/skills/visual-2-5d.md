# 2.5D Visual

## 狀態

Accepted

## 目的

使用 Flutter 2D Canvas 與動畫系統營造 3D 互動感，避免第一版投入完整 3D 圖學成本。

## 使用階段

Phase 5

## 輸入

- 遊戲物件位置。
- Depth 值。
- 動畫進度。
- 命中或失敗事件。
- `MotionTrailEvent`（包含 tipX、tipY、strength）。

## 輸出

- 遠小近大的物件動畫。
- 劍尖軌跡（由姿態投影的 tipX/tipY 映射到螢幕座標）。
- 命中劍痕（回溯 trail + glow + fade out）。
- 劍尖位置指示器（不揮動時半透明顯示）。
- 粒子效果。
- Screen shake。
- HUD 視覺回饋。

## 重要流程：Trail 渲染平滑原則

渲染端可以補「封包內與封包間的小間隔」，但不能補「上游長時間沒有新資料」。如果 trail 每 100-200ms 才收到新點，Catmull-Rom 或 glow 只能讓線段比較漂亮，不能讓手感變即時。因此遇到跳格時要先確認 packet cadence，再調 renderer。

固定流程：

```text
Host 收到 MotionTrailEvent
→ normalize 到 host 時間軸
→ TrailPointBuffer 加入 samples
→ 定期 prune 過期 points，限制 maxPoints
→ TrailRenderer 每幀依 frame clock 重畫
→ 必要時對相鄰 points 做少量 Catmull-Rom interpolation
→ 依 strength 畫線寬與 glow
```

渲染規則：

- `TrailPointBuffer` 必須限制 retention 與 maxPoints，避免點數無限成長。
- `TrailRenderer` 可在相鄰點間隔超過約 24ms 時插入少量補點，但每段補點要有限制。
- Room preview / Saber arena 若已按時間順序 append points，可關閉排序或限制每位玩家繪製點數。
- glow、blur、粒子與 screen shake 都會增加 raster 成本；若 packets/s 正常但畫面掉幀，先降這些視覺成本。
- 劍尖位置指示器用最後一個 trail point 畫，strength 低時也要能顯示穩定位置。
- 不要用渲染插值掩蓋 streamer cadence 問題；慢速小幅旋轉卡住時，優先檢查 `MotionTrailStreamer` active 判斷。

## 主要檔案

- [depth_transform.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/visual/depth_transform.dart)
- [screen_shake_controller.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/visual/screen_shake_controller.dart)
- [particle_system.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/visual/particle_system.dart)
- [trail_renderer.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/visual/trail_renderer.dart)
- [game_shell_page.dart](file:///Users/anthonyxwx/code/motionarcade/lib/desktop/game_shell_page.dart)

## 依賴 Skills

- Motion Protocol
- Motion Window Trail

## 實作項目

- [x] 建立 depth 到 scale/opacity 的轉換。
- [x] 建立 `CustomPainter` 繪圖工具。
- [x] 建立 trail renderer，將 tipX/tipY 映射到螢幕座標：`screenX = centerX + tipX * halfWidth`、`screenY = centerY - tipY * halfHeight`。
- [x] trail 線條粗細由 strength 控制，發光強度由 strength 控制。
- [x] 建立命中劍痕：收到 SlashEvent 時回溯最近 200-300ms trail，加亮、加粗、加 glow、fade out。
- [x] 建立劍尖位置指示器：在 strength 低於門檻時顯示半透明圓點或十字線。
- [x] 建立 screen shake。
- [x] 建立基本粒子系統。
- [x] 支援 20-30Hz motionTrail packets 的平滑插值，避免封包間隔造成斷裂。
- [x] 渲染端限制 trail point 數量與插值密度，避免 renderer 自己造成卡頓。
- [x] 明確區分 renderer smoothing 與 streamer cadence；上游資料不足時先修封包節奏。

## 驗收標準

- [x] 物件能由遠到近移動並逐漸放大。
- [x] 劍尖軌跡能平滑繪製，不會在手機停止時跳回中央。
- [x] 命中劍痕有發光、加粗與淡出效果。
- [x] 不揮動時劍尖指示器可見且位置穩定。
- [x] 連續 motion trail 可平滑繪製，不會因封包間隔出現明顯斷裂。
- [x] 命中時可觸發粒子與畫面震動。
- [x] HUD 與遊戲物件不互相遮擋。
- [x] packets/s 正常時，renderer 不應因 trail point 過多或 glow 過重造成掉幀。

## 測試方式

- 單元與元件測試：
  - 執行 `flutter test test/visual_2_5d_test.dart` 測試 Catmull-Rom 插值與 GameShell 繪製。
- 手動測試：
  - 連線手機，靜止時確認劍尖指示器（半透明圓圈十字）出現。
  - 連線手機揮擊，確認劍痕沿實際揮動曲線加粗發光繪製並在 800ms 內淡出，同時觸發畫面震動（Screen Shake）與粒子爆裂效果（Particle Burst）。
