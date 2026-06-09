# Platform Setup

## 狀態

In Progress

## 目的

提早整理 Android、iOS、macOS 與桌面端需要的權限與系統設定，避免實機測試或展示時才發現感測器、震動、區網連線或桌面 server 被阻擋。

## 使用階段

Phase 0

## 輸入

- 目標平台。
- App 權限需求。
- 展示網路環境。

## 輸出

- 平台權限檢查清單。
- 實機測試設定。
- 展示前環境確認項目。

## 主要檔案

- `docs/platform-setup.md`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `macos/Runner/*.entitlements`

## 依賴 Skills

- 無

## 實作項目

- [x] 確認 Android 網路連線設定。
- [x] 確認 Android camera permission。
- [x] 確認 iOS camera usage description。
- [x] 確認 iOS motion usage description。
- [x] 確認 iOS local network 使用說明。
- [ ] 確認 macOS desktop server 連線設定。
- [ ] 確認震動不支援時的 fallback。
- [ ] 建立展示前防火牆與同網段檢查。

## 驗收標準

- [ ] 至少一台實機可以讀取感測器。
- [ ] 手機可以連線至桌面端 WebSocket server。
- [ ] 震動不可用時 App 不會 crash。
- [ ] 展示前檢查清單可用來確認環境。

## 測試方式

- 手動測試：Android 或 iOS 實機連線桌面端。
- 手動測試：切換 Wi-Fi 與手機熱點環境。

## 後續擴充

- 自動偵測缺少的權限或平台能力。
- 啟動時顯示環境診斷結果。
