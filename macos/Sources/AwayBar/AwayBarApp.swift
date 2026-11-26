import AppKit
import AwayCore
import SwiftUI

@main
struct AwayBarApp: App {
    @StateObject private var model = AwayModel()

    init() {
        // 확인용: `AwayBar --snapshot <png>`는 패널을 창 없이 그려 저장하고 끝낸다 (상단바 패널은 자동 캡처가 어렵다).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            let j = args.firstIndex(of: "--do")
            Snapshot.run(to: args[i + 1], action: j.flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil })
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(model: model)
        } label: {
            Image(systemName: model.active ? "moon.zzz.fill" : "moon.zzz")
            if model.active { Text(Format.remaining(model.remaining)).monospacedDigit() }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
enum Snapshot {
    /// action: start(첫 티켓 후보를 골라 시작 단추와 같은 경로) | stop(끄기 단추와 같은 경로) | nil
    static func run(to path: String, action: String? = nil) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = AwayModel()
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
