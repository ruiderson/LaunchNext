import SwiftUI
import AppKit
import SwiftData
import Combine

extension Notification.Name {
    static let launchpadWindowShown = Notification.Name("LaunchpadWindowShown")
    static let launchpadWindowHidden = Notification.Name("LaunchpadWindowHidden")
}

class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@main
struct LaunchpadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings {} }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSGestureRecognizerDelegate {
    static var shared: AppDelegate?
    
    private var window: NSWindow?
    private let minimumContentSize = NSSize(width: 800, height: 600)
    private var lastShowAt: Date?
    private var cancellables = Set<AnyCancellable>()
    
    let appStore = AppStore()
    var modelContainer: ModelContainer?
    private var isTerminating = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        
        setupWindow()
        appStore.performInitialScanIfNeeded()
        appStore.startAutoRescan()
        
        if appStore.isFullscreenMode { updateWindowMode(isFullscreen: true) }
    }
    
    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let rect = calculateContentRect(for: screen)
        
        window = BorderlessWindow(contentRect: rect, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        window?.delegate = self
        window?.isMovable = false
        window?.level = .floating
        window?.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.hasShadow = true
        window?.contentAspectRatio = NSSize(width: 4, height: 3)
        window?.contentMinSize = minimumContentSize
        window?.minSize = window?.frameRect(forContentRect: NSRect(origin: .zero, size: minimumContentSize)).size ?? minimumContentSize
        
        // SwiftData 支持（固定到 Application Support 目录，避免替换应用后数据丢失）
        do {
            let fm = FileManager.default
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let storeDir = appSupport.appendingPathComponent("LaunchNext", isDirectory: true)
            if !fm.fileExists(atPath: storeDir.path) {
                try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
            }
            let storeURL = storeDir.appendingPathComponent("Data.store")

            let configuration = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(for: TopItemData.self, PageEntryData.self, configurations: configuration)
            modelContainer = container
            appStore.configure(modelContext: container.mainContext)
            window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore).modelContainer(container))
        } catch {
            // 回退到默认容器，保证功能可用
            if let container = try? ModelContainer(for: TopItemData.self, PageEntryData.self) {
                modelContainer = container
                appStore.configure(modelContext: container.mainContext)
                window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore).modelContainer(container))
            } else {
                window?.contentView = NSHostingView(rootView: LaunchpadView(appStore: appStore))
            }
        }
        
        applyCornerRadius()
        window?.orderFrontRegardless()
        window?.makeKey()
        lastShowAt = Date()
        NotificationCenter.default.post(name: .launchpadWindowShown, object: nil)
        
        // 背景点击关闭逻辑改为 SwiftUI 内部实现，避免与输入控件冲突
    }
    
    func showWindow() {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        let rect = appStore.isFullscreenMode ? screen.frame : calculateContentRect(for: screen)
        window.setFrame(rect, display: true)
        applyCornerRadius()
        window.alphaValue = 0
        window.makeKey()
        lastShowAt = Date()
        NotificationCenter.default.post(name: .launchpadWindowShown, object: nil)
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = [.transient, .canJoinAllApplications, .fullScreenAuxiliary, .ignoresCycle]
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            window.animator().alphaValue = 1
            window.contentView?.animator().alphaValue = 1
        }
    }
    
    func hideWindow() {
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            window.animator().alphaValue = 0
            window.contentView?.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.alphaValue = 1
            window.contentView?.alphaValue = 1
        })
        appStore.isSetting = false
        appStore.currentPage = 0
        appStore.searchText = ""
        appStore.openFolder = nil
        appStore.saveAllOrder()
        NotificationCenter.default.post(name: .launchpadWindowHidden, object: nil)
    }

    // MARK: - Quit with fade
    func quitWithFade() {
        guard !isTerminating else { NSApp.terminate(nil); return }
        isTerminating = true
        if let window = window {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                window.animator().alphaValue = 0
                window.contentView?.animator().alphaValue = 0
            }, completionHandler: {
                NSApp.terminate(nil)
            })
        } else {
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateNow }
        quitWithFade()
        return .terminateLater
    }
    
    func updateWindowMode(isFullscreen: Bool) {
        guard let window = window else { return }
        let screen = getCurrentActiveScreen() ?? NSScreen.main!
        window.setFrame(isFullscreen ? screen.frame : calculateContentRect(for: screen), display: true)
        window.hasShadow = !isFullscreen
        window.contentAspectRatio = isFullscreen ? NSSize(width: 0, height: 0) : NSSize(width: 4, height: 3)
        applyCornerRadius()
    }
    
    private func applyCornerRadius() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = appStore.isFullscreenMode ? 0 : 30
        contentView.layer?.masksToBounds = true
    }
    
    private func calculateContentRect(for screen: NSScreen) -> NSRect {
        let frame = screen.visibleFrame
        
        let height = frame.height * 0.72
        let width = max(height * 1.8, minimumContentSize.width, minimumContentSize.height * 4/3)
        
        return NSRect(x: frame.midX - width/2, y: frame.midY - height/2, width: width, height: height)
    }
    
    private func getCurrentActiveScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }
    
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minSize = minimumContentSize
        let contentSize = sender.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
        let clamped = NSSize(width: max(contentSize.width, minSize.width), height: max(contentSize.height, minSize.height))
        return sender.frameRect(forContentRect: NSRect(origin: .zero, size: clamped)).size
    }
    
    func windowDidResignKey(_ notification: Notification) { autoHideIfNeeded() }
    func windowDidResignMain(_ notification: Notification) { autoHideIfNeeded() }
    private func autoHideIfNeeded() {
        guard !appStore.isSetting else { return }
        hideWindow()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if window?.isVisible == true {
            hideWindow()
        } else {
            showWindow()
        }
        return false
    }
    
    private func isInteractiveView(_ view: NSView?) -> Bool {
        var v = view
        while let cur = v {
            if cur is NSControl || cur is NSTextView || cur is NSScrollView || cur is NSVisualEffectView { return true }
            v = cur.superview
        }
        return false
    }

    @objc private func handleBackgroundClick(_ sender: NSClickGestureRecognizer) {
        guard appStore.openFolder == nil && !appStore.isFolderNameEditing else { return }
        guard let view = sender.view else { return }
        let p = sender.location(in: view)
        if let hit = view.hitTest(p), isInteractiveView(hit) { return }
        hideWindow()
    }

    // MARK: - NSGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        guard let contentView = window?.contentView else { return true }
        let point = contentView.convert(event.locationInWindow, from: nil)
        if let hit = contentView.hitTest(point), isInteractiveView(hit) {
            return false
        }
        return true
    }
}
