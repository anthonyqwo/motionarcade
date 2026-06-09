# Platform Setup Checklist

## 目的

這份文件用來確認 Motion Arcade 在實機與桌面展示環境中的必要平台設定，避免感測器、震動、區網連線或桌面 WebSocket server 在展示時失效。

## Android

- [ ] 手機端可連線到區網 WebSocket server。
- [x] 已確認必要的 Internet/network 設定。
- [x] 已加入 camera permission 供 QR 掃描使用。
- [ ] 實機可讀取 accelerometer。
- [ ] 實機可讀取 gyroscope。
- [ ] 震動或 haptic feedback 可正常觸發。
- [ ] 震動不可用時 App 不會 crash。

## iOS

- [x] `Info.plist` 已加入 camera usage 說明。
- [x] `Info.plist` 已加入 motion usage 說明。
- [x] 如使用區網掃描或連線，已加入 local network usage 說明。
- [ ] 實機可讀取 motion sensor。
- [ ] 實機可觸發 haptic feedback。
- [ ] 權限被拒絕時畫面有清楚提示。

## macOS / Desktop

- [ ] 桌面端可啟動 WebSocket server。
- [ ] 手機與電腦位於同一個網段。
- [ ] 防火牆不會阻擋指定 port。
- [ ] 電腦端畫面可顯示 IP、Port 與 QR Code。
- [ ] 手機熱點環境下也能完成連線。

## 展示前確認

- [ ] 至少一台實機完成完整流程測試。
- [ ] QR Code 連線成功。
- [ ] 手動 IP 連線成功。
- [ ] 感測器讀取正常。
- [ ] 震動回饋正常或 fallback 正常。
- [ ] 已準備備用 Demo 影片。
