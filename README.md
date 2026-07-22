# 學生記帳 App

一款使用 Flutter 開發的本機優先個人記帳 App。資料預設只儲存在裝置內，適合租屋學生記錄日常收支、訂閱費用與每月消費狀況。

## 目前功能

- 交易新增、修改、刪除與日期記錄
- 收入／支出類別及兩層父子類別管理
- 實體店面、網購等購物類型
- 首頁本月摘要、今日紀錄、最近交易與快速記帳
- 交易搜尋及類型、類別、購物類型、日期篩選
- 月曆每日收支與交易明細
- 每月收入、支出、類別和購物類型分析
- Spotify、AI、手機網路等週期訂閱管理
- 到期訂閱自動建立支出交易
- CSV 匯出、完整 JSON 備份／還原及資料清除

## 開發環境

- Flutter 3.44.7 或相容的 stable 版本
- Dart 3.12 或以上
- Android Studio 與 Android 模擬器／實體裝置
- Windows 開發時需開啟「設定 → 隱私權與安全性 → 開發人員專用 → 開發人員模式」，讓 Flutter 建立原生套件連結

## 執行方式

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

建議選擇 Android 模擬器或實體 Android 裝置。本專案目前使用 Drift 的原生 SQLite，因此 Chrome／Edge 網頁版不是支援目標。iOS 版本需要在 macOS 與 Xcode 環境建置及測試。

如果剛加入或更新原生套件，請停止目前的 `flutter run` 後重新執行，不能只使用 hot reload。

## 專案結構

```text
lib/
  app/                 路由、App 外殼與導覽
  core/                SQLite 資料庫、主題及共用工具
  features/
    home/              首頁摘要
    transactions/      交易 CRUD、搜尋與篩選
    categories/        類別管理
    calendar/          月曆
    analysis/          每月分析
    subscriptions/     訂閱管理與自動記帳
    settings/          匯出、備份、還原與設定
  shared/              共用畫面元件
test/                  單元、資料庫、Widget 與 QA 測試
```

App 使用 Riverpod 管理狀態、GoRouter 管理頁面路由、Drift／SQLite 保存本機資料。

## 主要資料表

- `categories`：收支類別與父子關聯
- `channels`：實體店面、網購等購物類型
- `transactions`：交易金額、日期、類別、來源與軟刪除狀態
- `subscriptions`：訂閱金額、週期、扣款日期與自動記帳設定

## 資料匯出與備份

- CSV 僅包含未刪除的交易，使用 UTF-8 BOM，方便 Excel 正確顯示中文。
- JSON 備份包含類別、購物類型、所有交易與訂閱關聯，可用於完整還原。
- 還原前會驗證檔案版本、ID、父子類別、收支類型及訂閱日期；驗證失敗時不會覆蓋現有資料。
- 「清除全部資料」會移除交易、訂閱與自訂類別，然後恢復預設類別和購物類型。

建議在清除資料或更換裝置前先建立完整備份，並將檔案存放在可信任的位置。

## 品質檢查

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

測試涵蓋資料庫建立與升級、交易 CRUD、類別管理、月曆、分析、訂閱到期處理、搜尋篩選、備份還原，以及 320 × 640 小螢幕與放大文字的主要頁面顯示。

## 隱私與發布狀態

目前沒有登入、雲端同步、廣告或分析追蹤；所有記帳資料保存在本機。專案仍處於開發與 QA 階段，尚未發布至 Google Play 或 App Store。
