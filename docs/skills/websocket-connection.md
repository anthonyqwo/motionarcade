# WebSocket Connection

## 狀態

In Progress

## 目的

讓手機端 Controller 與電腦端 Desktop Game 在同一個區網內建立低延遲連線，作為所有體感事件傳輸的基礎。

## 使用階段

Phase 1

## 輸入

- 電腦端 IP。
- WebSocket Port。
- QR Code 連線資訊。
- 手機端玩家名稱。
- 手機端連線操作。

## 輸出

- WebSocket 連線狀態。
- `join` event。
- `button` test event。
- 電腦端玩家連線列表。

## 主要檔案

- `lib/network/websocket_server_service.dart`
- `lib/network/websocket_client_service.dart`
- `lib/desktop/room_page.dart`
- `lib/controller/connection_page.dart`
- `lib/controller/qr_scan_page.dart`

## 依賴 Skills

- Motion Protocol

## 實作項目

- [x] 電腦端建立 WebSocket server。
- [x] 電腦端顯示 IP 與 Port。
- [x] 電腦端產生 QR Code。
- [x] 手機端輸入 IP 與 Port。
- [x] 手機端支援掃描 QR Code。
- [x] 手機端建立 WebSocket client。
- [x] 手機端送出 `join` event。
- [x] 電腦端顯示玩家已連線。
- [x] 支援斷線狀態顯示。

## 驗收標準

- [x] 手機可成功連線至電腦端。
- [x] QR Code 與手動輸入兩種連線方式都可用。
- [x] 電腦端可顯示連線玩家。
- [x] 手機按下測試按鈕後，電腦端可即時顯示事件。
- [x] 手機斷線後，電腦端可更新狀態。

## 測試方式

- 單元測試：事件格式與連線狀態轉換。
- 手動測試：手機與電腦在同一 Wi-Fi 下互連。

## 後續擴充

- 自動搜尋區網房間。
- 多玩家連線。
