# Feedback System

## 狀態

Completed

## 目的

將電腦端遊戲判定結果回傳手機，讓手機用震動或提示提供即時回饋。

## 使用階段

Phase 4 / Phase 6

## 輸入

- Hit result (perfect / good / miss)。
- Combo result。
- Player ID。

## 輸出

- `FeedbackEvent`。
- 手機端震動 (iOS Core Haptics / Android VibratorManager)。
- 手機端 Floating Overlay Banner (PERFECT! / GOOD / MISS 提示)。

## 主要檔案

- [feedback_service.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/feedback/feedback_service.dart) - 桌端判定發送輔助
- [feedback_event.dart](file:///Users/anthonyxwx/code/motionarcade/lib/shared/models/feedback_event.dart) - 反饋事件模型
- [haptic_feedback_service.dart](file:///Users/anthonyxwx/code/motionarcade/lib/controller/haptic_feedback_service.dart) - 手機端震動服務封裝
- [AppDelegate.swift](file:///Users/anthonyxwx/code/motionarcade/ios/Runner/AppDelegate.swift) - iOS Core Haptics 原生 MethodChannel 實作
- [MainActivity.kt](file:///Users/anthonyxwx/code/motionarcade/android/app/src/main/kotlin/com/example/motionarcade/MainActivity.kt) - Android 原生震動 Pattern 實作

## 依賴 Skills

- WebSocket Connection
- Motion Protocol
- Scoring System

## 實作項目

- [x] 定義 feedback event (`FeedbackEvent`)。
- [x] 電腦端根據判定產生 feedback。
- [x] 手機端接收 feedback。
- [x] 手機端偵測成功時觸發本地震動。
- [x] 手機端提供測試震動按鈕與 Haptic Simulator 控制面板。
- [x] 手機端收到 feedback event 後觸發震動。
- [x] 顯示 Perfect/Good/Miss 提示與 Floating Overlay Banner。

## 驗收標準

- [x] Perfect 會觸發短而強、具漸強質感的雙重震動 (Crisp rising double-tap click)。
- [x] Good 會觸發單次強烈清晰的點擊。
- [x] Miss 會觸發連續低頻雙重沉悶點擊 (Dull heartbeat-like thud)。
- [x] Combo 可觸發連續短震動。
- [x] 手機端斷線時不會造成電腦端 crash (具備斷線重連與心跳偵測)。

## 震動系統使用與參數說明

### 1. 原生 MethodChannel 參數
MethodChannel 名稱：`motionarcade/haptics`
- **`play` 方法**：播放單次震動。
  - `intensity` (`double`): 強度，範圍 `0.0` - `1.0`
  - `sharpness` (`double`): 銳利度，範圍 `0.0` - `1.0` (iOS Core Haptics 對應頻率，在 Android 上決定是否使用振幅控制)
  - `duration` (`double`): 持續時間 (秒)
- **`playPattern` 方法**：播放自訂時序震動序列。
  - `pattern` (`List<Map<String, dynamic>>`): 每個步驟包含 `type` ("transient" 或 "continuous"), `time` (相對開始秒數), `intensity`, `sharpness`, `duration`。

### 2. 遊戲回饋震動預設 (HapticPattern)
使用 `HapticFeedbackService.trigger(pattern)` 可以直接呼叫遊戲內預設震動：
- **`perfect`** (極佳回饋)：
  - 採用雙重漸強 click。第 1 聲為 40% 強度/85% 銳利度，於 `0.0s` 觸發；第 2 聲為 100% 強度/95% 銳利度，於 `0.05s` 觸發。形成極具打擊感的 "tic-TIC" 快感。
- **`good`** (一般成功)：
  - 單次清晰敲擊：強度 70% / 銳利度 80%。
- **`miss`** (失敗/失誤)：
  - 雙重低頻沉悶震動。第 1 聲為 80% 強度/10% 銳利度，於 `0.0s` 觸發；第 2 聲為 40% 強度/15% 銳利度，於 `0.08s` 觸發。藉由極低銳利度呈現不悅的低沉阻尼感。
- **`combo`** (連擊)：
  - 連續三次輕快敲擊，每次間隔 `100ms`。

### 3. 容錯與 Fallback 機制
當程式運行於模擬器、網頁端、桌面單元測試、或是 native 程式碼尚未編譯更新的 Hot-reload 環境時，MethodChannel 會拋出 `MissingPluginException` 或 `PlatformException`。
本系統實作了**自動降級/回退機制**：
- 當呼叫 `play` 或 `playCustom` 時，將捕捉異常並自動轉換為 Flutter 內建的 `HapticFeedback`：
  - `intensity > 0.7` $\rightarrow$ `HapticFeedback.heavyImpact()`
  - `intensity > 0.4` $\rightarrow$ `HapticFeedback.mediumImpact()`
  - 其它 $\rightarrow$ `HapticFeedback.lightImpact()`
- 當呼叫 `playPattern` 時，會由 Dart 層以 `Future.delayed` 模擬時間間隔延遲，並在時間到達時觸發對應強度的 `HapticFeedback`。

## 測試方式

- **單元測試**：
  - 執行 `flutter test test/haptic_feedback_service_test.dart` 測試 fallback 邏輯和 Presets 映射是否正確。
- **手動測試 (Simulator 控制面板)**：
  - 進入 Controller App 首頁，點擊 Presets 中的 "Perfect"、"Good"、"Miss"、"Combo" 按鈕，可以預覽並感受不同的震動波形。
  - 使用面板上的 Intensity/Sharpness/Duration 滑桿，點擊 "Play Haptic" 調試自訂數值。
