# Ping Pong Gameplay

## 狀態

Deferred

## 目的

在核心體感系統穩定後，加入桌球模式，讓玩家使用手機揮拍，在電腦端 2.5D 桌球畫面中回擊球。

## 使用階段

Phase 9

## 輸入

- `SwingEvent`。
- 揮拍方向。
- Power。
- 擊球時間窗。

## 輸出

- 桌球飛行動畫。
- 擊球成功或失誤判定。
- 球路方向。
- 分數與 feedback event。

## 主要檔案

- `lib/games/ping_pong/ping_pong_game_page.dart`
- `lib/games/ping_pong/ping_pong_game_state.dart`
- `lib/games/ping_pong/ping_pong_painter.dart`
- `lib/games/ping_pong/hit_window.dart`

## 依賴 Skills

- Motion Protocol
- Motion Detection
- 2.5D Visual
- Scoring System
- Feedback System

## 實作項目

- [ ] 建立 2.5D 梯形桌面。
- [ ] 建立球靠近與遠離動畫。
- [ ] 建立擊球時間窗。
- [ ] 根據揮拍方向改變球路。
- [ ] 建立簡易 AI 對手。

## 驗收標準

- [ ] 球進入擊球區時，玩家揮手機可成功回擊。
- [ ] 太早、太晚或方向錯誤會判定 Miss。
- [ ] 成功回擊後球會飛回對面。

## 測試方式

- 手動測試：固定球路與固定時間窗。

## 後續擴充

- 多球路。
- 旋球效果。
- 難度提升與 AI 節奏變化。

