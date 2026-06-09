# Scoring System

## 狀態

Accepted

## 目的

提供所有遊戲共用的分數、Combo 與判定結果計算邏輯。

## 使用階段

Phase 6

## 輸入

- 命中結果 (FeedbackResult)。
- Combo 狀態。
- 遊戲模式。

## 輸出

- 分數 (Score)。
- 連擊數 (Combo)。
- 倍率 (Multiplier)。
- 判定文字。

## 主要檔案

- [scoring_system.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/scoring/scoring_system.dart)
- [motion_event.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/models/motion_event.dart)
- [scoring_system_test.dart](file:///Users/anthonyxwx/code/motionarcade/test/scoring_system_test.dart)

## 依賴 Skills

- 無

## 實作項目

- [x] 定義 Perfect/Good/Weak/Miss 基礎得分。
- [x] 定義基礎分數：Perfect (+100), Good (+60), Weak (+30), Miss (+0)。
- [x] 實作 Combo 累積與 Max Combo 記錄。
- [x] 實作 Miss 時 Combo 歸零。
- [x] 實作 Multiplier 倍率公式 (5+ combo: x1.5, 10+ combo: x2.0, 15+ combo: x2.5, 20+ combo: x3.0)。

## 驗收標準

- [x] Perfect 得分高於 Good。
- [x] Miss 不加分且 Combo 歸零。
- [x] Combo 可提升倍率。
- [x] Scoring 可被 Saber、Basketball 等多遊戲共用。

## 測試方式

- 單元測試：執行 `flutter test test/scoring_system_test.dart` 驗證得分累積、倍率升降和 Miss 歸零狀態。
