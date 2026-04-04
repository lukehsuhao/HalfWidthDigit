# HalfWidthDigit 半形數字工具

macOS 注音輸入法使用者的小工具 — 在注音模式下，數字與運算符號自動輸出**半形**，不再需要手動切換輸入法。

## 問題

使用 macOS 內建注音輸入法時，透過 Numpad 輸入的數字和符號會變成全形：

```
全形：０１２３４５ ＋ － ＊ ／
半形：012345 + - * /
```

全形數字在實務上幾乎沒人使用，卻需要每次手動切換，非常不便。

## 解決方式

HalfWidthDigit 在背景常駐，自動攔截注音模式下的 Numpad 按鍵，轉為半形輸出。

**支援的按鍵：**
- 數字 `0` `1` `2` `3` `4` `5` `6` `7` `8` `9`
- 運算符號 `+` `-` `*` `/` `=` `.`

## 安裝

### 方法一：直接下載（推薦）

1. 前往 [Releases](https://github.com/lukehsuhao/HalfWidthDigit/releases) 頁面
2. 下載最新版 `HalfWidthDigit.dmg`
3. 打開 DMG，將 **HalfWidthDigit** 拖入 **Applications** 資料夾
4. 從應用程式中啟動

### 方法二：從原始碼編譯

```bash
git clone https://github.com/lukehsuhao/HalfWidthDigit.git
cd HalfWidthDigit
swift build -c release
# 執行檔在 .build/release/HalfWidthDigit
```

## 首次啟動設定

首次啟動時，系統會要求授權**輔助使用**權限。這是攔截鍵盤事件的必要權限：

1. 前往 **系統設定 → 隱私權與安全性 → 輔助使用**
2. 點擊 **+** 加入 HalfWidthDigit
3. 重新啟動 App

> 沒有授權輔助使用，App 無法運作。

## 使用方式

啟動後，Menu Bar 會出現 **½** 圖示：

- **✓ 已啟用** — 點擊切換開關
- **結束** — 關閉程式

切換到注音輸入法後，Numpad 的數字和符號會直接輸出半形，不會進入選字模式。

## 運作原理

1. 透過 `CGEventTap` 攔截鍵盤事件
2. 偵測到 Numpad 按鍵 + 注音輸入法啟用時，攔截原始事件
3. 暫時切換到 ABC 輸入法，重送同一個按鍵
4. 按鍵由 ABC 處理產生半形字元後，自動切回注音

## 系統需求

- macOS 12.0 (Monterey) 或以上
- 輔助使用權限

## 授權

MIT License

## 作者

[Hao Hsu](https://github.com/lukehsuhao)
