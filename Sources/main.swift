import Cocoa
import Carbon

// MARK: - Global State

var gEnabled = true
var gEventTap: CFMachPort?
let kSyntheticMarker: Int64 = 0x48574431

// MARK: - Numpad Keycodes (digits + operators)

let numpadKeyCodes: Set<UInt16> = [
    82, 83, 84, 85, 86, 87, 88, 89, 91, 92, // 0-9
    65, 67, 69, 75, 78, 81                      // .  *  +  /  -  =
]

// MARK: - Input Source Helpers

func isZhuyinActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return false
    }
    guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
        return false
    }
    let sourceID = Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    return sourceID.contains("Zhuyin") || sourceID.contains("Bopomofo")
}

/// Cache the ASCII source so we don't search every keypress
var gASCIISource: TISInputSource?

func findASCIIInputSource() -> TISInputSource? {
    if let cached = gASCIISource { return cached }
    for sourceID in [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.US",
        "com.apple.keylayout.British",
        "com.apple.keylayout.Australian"
    ] {
        let filter = [kTISPropertyInputSourceID: sourceID] as CFDictionary
        if let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
           let source = list.first {
            gASCIISource = source
            return source
        }
    }
    // Fallback: any non-IM keyboard layout
    let filter = [
        kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
        kTISPropertyInputSourceType: kTISTypeKeyboardLayout
    ] as CFDictionary
    if let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
       let source = list.first {
        gASCIISource = source
        return source
    }
    return nil
}

// MARK: - Character Injection

func injectAsHalfWidth(keyCode: CGKeyCode, flags: CGEventFlags) {
    let originalSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
    guard let asciiSource = findASCIIInputSource() else {
        NSLog("[HalfWidthDigit] ERROR: No ASCII input source found")
        return
    }

    // 1. Switch to ASCII
    TISSelectInputSource(asciiSource)
    Thread.sleep(forTimeInterval: 0.02)

    // 2. Post the same key — ABC will produce half-width
    if let src = CGEventSource(stateID: .privateState) {
        src.userData = kSyntheticMarker
        if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }

    Thread.sleep(forTimeInterval: 0.02)

    // 3. Switch back to original input source
    if let src = originalSource {
        TISSelectInputSource(src)
    }
}

// MARK: - CGEventTap Callback

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Re-enable tap if system disabled it
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = gEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    guard gEnabled, type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    // Skip our own synthetic events
    if event.getIntegerValueField(.eventSourceUserData) == kSyntheticMarker {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

    // --- Detect: numpad key + Zhuyin active → intercept ---
    if numpadKeyCodes.contains(keyCode) && isZhuyinActive() {
        let flags = event.flags
        NSLog("[HalfWidthDigit] Intercepting numpad key %d, injecting as half-width", keyCode)

        DispatchQueue.global(qos: .userInteractive).async {
            injectAsHalfWidth(keyCode: CGKeyCode(keyCode), flags: flags)
        }
        return nil // suppress original
    }

    // --- Fallback: detect full-width ASCII in unicode string ---
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    event.keyboardGetUnicodeString(
        maxStringLength: 4,
        actualStringLength: &length,
        unicodeString: &chars
    )

    if length > 0 && isZhuyinActive() {
        let hasFullWidth = (0..<length).contains { chars[$0] >= 0xFF01 && chars[$0] <= 0xFF5E }
        if hasFullWidth {
            let flags = event.flags
            NSLog("[HalfWidthDigit] Intercepting full-width char U+%04X, key %d", chars[0], keyCode)

            DispatchQueue.global(qos: .userInteractive).async {
                injectAsHalfWidth(keyCode: CGKeyCode(keyCode), flags: flags)
            }
            return nil
        }
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var toggleMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupEventTap()
        NSLog("[HalfWidthDigit] Started. ASCII source: %@",
              findASCIIInputSource().map { String(describing: $0) } ?? "NOT FOUND")
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "½"
        statusItem.button?.toolTip = "半形數字工具"

        let menu = NSMenu()

        toggleMenuItem = NSMenuItem(
            title: "✓ 已啟用",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: "e"
        )
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "關於 HalfWidthDigit",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "結束",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            showAccessibilityAlert()
            return
        }

        gEventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[HalfWidthDigit] Event tap installed.")
    }

    func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「輔助使用」權限"
        alert.informativeText = """
        請前往：
        系統設定 → 隱私權與安全性 → 輔助使用

        將 HalfWidthDigit 加入允許清單後重新啟動。
        """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "開啟系統設定")
        alert.addButton(withTitle: "結束")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        NSApplication.shared.terminate(nil)
    }

    @objc func toggleEnabled(_ sender: NSMenuItem) {
        gEnabled.toggle()
        toggleMenuItem.title = gEnabled ? "✓ 已啟用" : "　已停用"
        statusItem.button?.appearsDisabled = !gEnabled
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "HalfWidthDigit"
        alert.informativeText = """
        注音輸入法全形自動轉半形工具

        在注音模式下，Numpad 數字與符號（+ - * / = .）
        會自動轉為半形，無需手動切換。
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func quitApp() {
        if let tap = gEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
