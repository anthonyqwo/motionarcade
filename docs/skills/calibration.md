# Calibration

## 狀態

In Progress

## 目的

記錄玩家自然握持手機時的 neutral pose，建立後續 motion sample 的 controller-local 參考座標，降低不同握持姿態、手機型號與手機滾動造成的動作誤判。

## 使用階段

Phase 4

## 輸入

- 目前 fused attitude / quaternion。
- 目前 gravity / userAcceleration snapshot。
- 使用者按下校正按鈕。

## 輸出

- Initial attitude quaternion。
- Controller-local transform。
- 校正後的相對 motion sample。
- `CalibrateEvent`。

## 主要檔案

- `lib/controller/calibration_service.dart`
- `lib/controller/controller_home_page.dart`
- `lib/shared/models/motion_event.dart`

## 依賴 Skills

- Motion Sensor
- Fused Motion (共同開發，同一 Phase)
- Motion Protocol

## 實作項目

- [x] 建立校正按鈕。
- [x] 校正時記錄 initial attitude quaternion。
- [x] 將後續 `userAcceleration` 轉成 controller-local frame。
- [x] 傳送 `calibrate` event。
- [x] 顯示校正成功狀態。

## 驗收標準

- [x] 玩家按下校正後，系統會記錄 neutral position。
- [ ] 不同握持角度校正後仍可辨識六方向。
- [ ] 手機 roll 90 度後重新校正，方向判定仍符合玩家直覺。
- [ ] 校正狀態可在手機端畫面確認。

## 測試方式

- 手動測試：直立、橫拿、斜拿三種姿態校正後揮動。

## 後續擴充

- 多段校正。
- 自動校正提醒。
- 每位玩家保存校正設定。

## 實作備註

- 目前 raw sensor baseline 只能作為臨時 debug，不足以處理手機姿態滾動與重力投影。
- 正式校正資料應包含 initial attitude quaternion，後續用 quaternion transform 把 motion sample 轉回玩家校正時的控制器座標。
- **菜刀握法（側面拿）坐標軸對調與方向反轉陷阱**：
  * **錯誤設計**：將螢幕法向量 `(0, 0, 1)` 直接投影做為 `forwardAxis`。在側面拿時，螢幕朝向左右，這會導致前後軸與左右軸發生 90 度對調（必須手動 remap），且當手機旋轉 180 度（螢幕朝左 vs 朝右）時，重力方向反轉會導致上下/左右方向完全相反。
  * **正確設計**：以手機頂端 Y 軸 `(0, 1, 0)`（實體朝前指向）為基準，投影到垂直於 `upAxis` 的平面作為 `forwardAxis`，再以 `forwardAxis.cross(upAxis)` 計算 `rightAxis`。如此可建立與物理方向完全一致的標準右手坐標系（`x` 為右，`y` 為上，`z` 為前），自動適應手機任意側拿方向。
