# Motion Arcade Skills 管理

本資料夾用來集中管理 Motion Arcade 的能力模組。每個 skill 代表一個可獨立追蹤、實作與驗收的功能能力，例如 WebSocket 連線、手機感測器讀取、揮動偵測、2.5D 視覺效果與 Motion Saber 玩法。

## 管理目的

- 統一記錄每個能力模組的目的、輸入、輸出與依賴。
- 讓開發階段可以對應到明確的實作項目。
- 讓驗收不只看頁面是否完成，也能確認底層能力是否可用。
- 方便後續擴充 Basketball、Ping Pong、多人模式與更多體感玩法。

## 狀態定義

| 狀態 | 意義 |
| --- | --- |
| Planned | 已規劃，尚未開始 |
| In Progress | 開發中 |
| Ready for Test | 功能完成，等待測試 |
| Accepted | 已通過驗收 |
| Deferred | 延後處理 |

## Skills 清單

| Skill | 狀態 | 對應階段 | 優先級 | 文件 |
| --- | --- | --- | --- | --- |
| Platform Setup | In Progress | Phase 0 | 必做 | [platform-setup.md](platform-setup.md) |
| WebSocket Connection | In Progress | Phase 1 | 必做 | [websocket-connection.md](websocket-connection.md) |
| Motion Protocol | Ready for Test | Phase 2 | 必做 | [motion-protocol.md](motion-protocol.md) |
| Motion Sensor | Accepted | Phase 3 | 必做 | [motion-sensor.md](motion-sensor.md) |
| Fused Motion | In Progress | Phase 4 | 必做 | [fused-motion.md](fused-motion.md) |
| Motion Detection | In Progress | Phase 4 | 必做 | [motion-detection.md](motion-detection.md) |
| Calibration | In Progress | Phase 4 | 必做 | [calibration.md](calibration.md) |
| Motion Window Trail | Ready for Test | Phase 4.5 | 必做 | [motion-window-trail.md](motion-window-trail.md) |
| 2.5D Visual | Accepted | Phase 5 | 必做 | [visual-2-5d.md](visual-2-5d.md) |
| Saber Gameplay | Accepted | Phase 6 | 必做 | [saber-gameplay.md](saber-gameplay.md) |
| Scoring System | Accepted | Phase 6 | 必做 | [scoring-system.md](scoring-system.md) |
| Feedback System | Accepted | Phase 4/6 | 必做 | [feedback-system.md](feedback-system.md) |
| Performance Diagnostics | Planned | Phase 8 | 必做 | [performance-diagnostics.md](performance-diagnostics.md) |
| Basketball Gameplay | Planned | Phase 7 | 必做 | [basketball-gameplay.md](basketball-gameplay.md) |
| Ping Pong Gameplay | Deferred | Phase 9 | 延後 | [ping-pong-gameplay.md](ping-pong-gameplay.md) |

## 新增 Skill 流程

1. 複製 [SKILL_TEMPLATE.md](SKILL_TEMPLATE.md)。
2. 以 kebab-case 命名，例如 `combo-system.md`。
3. 補上目的、使用階段、輸入、輸出、依賴與驗收標準。
4. 在本 README 的 Skills 清單新增一列。
5. 實作完成後更新狀態與測試方式。
