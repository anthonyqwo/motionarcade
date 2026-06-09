# Motion Protocol

## 狀態

Ready for Test

## 目的

定義手機端與電腦端溝通的資料格式，讓所有遊戲模式都能共用一致的 motion event 與 feedback event。

## 使用階段

Phase 2

## 輸入

- 手機端動作事件。
- 電腦端遊戲判定結果。

## 輸出

- JSON event。
- Dart event model。
- Event encode/decode 結果。

## 主要檔案

- `lib/shared/models/motion_event.dart`
- `lib/shared/models/feedback_event.dart`
- `lib/network/motion_event_codec.dart`
- `lib/network/motion_event_dispatcher.dart`
- `test/motion_event_codec_test.dart`

## 依賴 Skills

- 無

## 實作項目

- [x] 定義 `JoinEvent`。
- [x] 定義 `CalibrateEvent`。
- [x] 定義 `SwingEvent`。
- [x] 定義 `SlashEvent`。
- [x] 定義 `ShootEvent`。
- [x] 定義 `FeedbackEvent`。
- [x] 實作 JSON encode/decode。
- [x] 處理未知 event type。

## 驗收標準

- [x] 所有事件可序列化成 JSON。
- [x] 所有事件可從 JSON 還原。
- [x] 未知事件不會造成 App crash。
- [x] 核心事件有測試覆蓋。

## 測試方式

- 單元測試：各 event encode/decode。
- 手動測試：WebSocket 收到 JSON 後可正確分派。

## 後續擴充

- Event versioning。
- Event schema 驗證。
- Replay log。
