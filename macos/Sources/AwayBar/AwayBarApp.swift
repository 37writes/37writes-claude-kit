import AppKit
import AwayCore
import Combine
import SwiftUI

@main
enum AwayBarApp {
    @MainActor
    static func main() {
        // 확인용: `AwayBar --snapshot <png> [--mode awake] [--do start|stop]`은 패널을 창 없이 그려 저장하고 끝낸다 (상단바 패널은 자동 캡처가 어렵다).
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        if let path = value("--snapshot") {
            Snapshot.run(to: path, action: value("--do"), mode: value("--mode").flatMap(AwayMode.init(rawValue:)) ?? .away)
        }
        let app = NSApplication.shared
        let bar = BarController()
        app.delegate = bar
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// 상단바 항목과 패널 창. SwiftUI `MenuBarExtra(.window)`는 시스템이 네모난 창 바탕을 깔아 둥근 판 뒤로 비쳐서,
/// 테두리·바탕·그림자가 없는 투명한 창을 직접 띄운다 (바탕은 PanelBackground가 둥글게 그린다).
@MainActor
final class BarController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private let model = AwayModel()
    private var item: NSStatusItem!
    private var panel: Panel?
    private var watch: AnyCancellable?
    private var closedAt = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        watch = model.objectWillChange.receive(on: RunLoop.main).sink { [weak self] in self?.updateLabel() }
        updateLabel()
        // 확인용: `AwayBar --open-check`는 패널을 스스로 열어 창 상태를 한 줄로 적고 끝낸다
        if CommandLine.arguments.contains("--open-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.show() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                let p = self.panel
                print("visible=\(p?.isVisible ?? false) key=\(p?.isKeyWindow ?? false) frame=\(p?.frame ?? .zero) opaque=\(p?.isOpaque ?? true) shadow=\(p?.hasShadow ?? true) button=\(self.item.button?.window?.frame ?? .zero)")
                exit(p?.isVisible == true ? 0 : 1)
            }
        }
    }

    private func updateLabel() {
        guard let button = item.button else { return }
        let awake = model.activeMode == .awake
        let image = NSImage(systemSymbolName: awake ? "sun.max.fill" : (model.active ? "cup.and.heat.waves.fill" : "cup.and.saucer"),
                            accessibilityDescription: awake ? "잠자기 방지" : "자리 비움")
        image?.isTemplate = true
        button.image = image
        button.title = model.active ? Format.remaining(model.remaining) : ""
    }

    @objc private func toggle() {
        if let panel, panel.isVisible { hide(); return }
        // 열린 패널에서 상단바 단추를 누르면 먼저 포커스를 잃어 닫힌다 → 곧바로 다시 열지 않는다
        if Date().timeIntervalSince(closedAt) < 0.25 { return }
        show()
    }

    private func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        model.panelOpened()
        panel.contentView?.layoutSubtreeIfNeeded()
        place(panel, size: panel.contentView?.fittingSize ?? panel.frame.size)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        panel?.orderOut(nil)
        model.panelOpen = false
        closedAt = Date()
    }

    private func makePanel() -> Panel {
        let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 10), styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let root = PanelView(model: model).fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self, weak panel] size in
                if let panel { self?.place(panel, size: size) }
            }
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }

    /// 상단바 단추 바로 아래에, 위쪽 가장자리를 고정하고 화면 밖으로 나가지 않게 놓는다.
    private func place(_ panel: NSPanel, size: CGSize) {
        guard size.width > 0, size.height > 0, let button = item.button, let anchor = button.window else { return }
        let rect = anchor.convertToScreen(button.convert(button.bounds, to: nil))
        var x = rect.midX - size.width / 2
        if let visible = (anchor.screen ?? NSScreen.main)?.visibleFrame {
            x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        }
        panel.setFrame(NSRect(x: x, y: rect.minY - 6 - size.height, width: size.width, height: size.height), display: true)
    }

    func windowDidResignKey(_ notification: Notification) { hide() }
}

@MainActor
enum Snapshot {
    /// action: start(첫 티켓 후보를 골라 시작 단추와 같은 경로) | stop(끄기 단추와 같은 경로) | nil. mode: 켜기 전 화면에서 고른 모드
    static func run(to path: String, action: String? = nil, mode: AwayMode = .away) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = AwayModel()
        model.mode = mode
        let host = NSHostingView(rootView: PanelView(model: model).fixedSize().background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 10), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if action == "start" {
                if !model.drafts.isEmpty { model.drafts[0].selected = true }
                model.start()
            } else if action == "stop" {
                model.stop()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            host.frame = NSRect(origin: .zero, size: size)
            window.setContentSize(size)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { exit(1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            let ok = (try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))) != nil
            exit(ok ? 0 : 1)
        }
        app.run()
    }
}
