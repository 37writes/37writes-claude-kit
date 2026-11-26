import AppKit
import AwayCore
import ServiceManagement
import SwiftUI

struct TicketDraft: Identifiable, Equatable {
    var candidate: TicketCandidate
    var selected: Bool
    var limit: Int
    var id: String { candidate.id }
}

@MainActor
final class AwayModel: ObservableObject {
    @Published var status: AwayStatus?
    @Published var report: AwayReport?
    @Published var message: String?          // 마지막 오류 (away.py의 message 그대로)
    @Published var busy = false
    @Published var kit: String?
    @Published var now = Date()
    @Published var end: EndChoice = .minutes(120)
    @Published var custom = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var useCustom = false
    @Published var drafts: [TicketDraft] = []
    @Published var loginItem = false
    @Published var panelOpen = false

    private var timer: Timer?
    private var lastRefresh = Date.distantPast
    private var refreshing = false

    init() {
        kit = KitLocator.locate()
        loginItem = LoginItem.isEnabled
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        refresh()
    }

    var client: AwayClient? {
        guard let kit, let python = AwayClient.findPython() else { return nil }
        return AwayClient(kit: kit, python: python)
    }

    /// 화면의 남은 초: 마지막 상태의 끝 시각에서 지금을 뺀다 (away.py를 매초 부르지 않는다).
    var remaining: Int {
        guard let st = status, st.active, let end = st.until_epoch else { return 0 }
        return max(0, end - Int(now.timeIntervalSince1970))
    }
    var active: Bool { (status?.active ?? false) && remaining > 0 }

    var chosenEnd: EndChoice {
        guard useCustom else { return end }
        let c = Calendar.current.dateComponents([.hour, .minute], from: custom)
        return .clock(hour: c.hour ?? 8, minute: c.minute ?? 0)
    }

    /// 시작할 수 없는 이유 (없으면 nil). 최종 판정은 away.py가 한다.
    var blocker: String? {
        if kit == nil { return "kit 폴더를 찾지 못했습니다. 아래에서 폴더를 고르세요" }
        if AwayClient.findPython() == nil { return "python3를 찾지 못했습니다" }
        guard let st = status else { return message ?? "상태를 읽는 중" }
        if st.power.source == "battery" { return "배터리로 동작 중입니다. 전원을 연결하면 시작할 수 있습니다" }
        if st.power.lid == "closed" { return "뚜껑이 닫혀 있습니다" }
        if !chosenEnd.isAllowed(from: now) { return "끝 시각은 지금부터 12시간 안이어야 합니다" }
        return nil
    }

    private func tick() {
        now = Date()
        let interval: TimeInterval = panelOpen ? 5 : 30
        let expired = (status?.active ?? false) && remaining == 0
        if now.timeIntervalSince(lastRefresh) >= interval || (expired && now.timeIntervalSince(lastRefresh) >= 2) { refresh() }
    }

    func refresh() {
        guard let client, !refreshing else { return }
        refreshing = true
        lastRefresh = Date()
        Task.detached {
            let st = Result { try client.status() }
            let rp = Result { try client.report() }
            await MainActor.run {
                self.refreshing = false
                switch st {
                case .success(let value):
                    self.status = value
                    self.mergeDrafts(value.ticket_candidates)
                    if self.message?.hasPrefix("away.py") == true { self.message = nil }
                case .failure(let error):
                    self.status = nil
                    self.message = (error as? AwayFailure)?.message ?? error.localizedDescription
                }
                if case .success(let value) = rp { self.report = value }
            }
        }
    }

    private func mergeDrafts(_ candidates: [TicketCandidate]) {
        var next = drafts.filter { d in d.candidate.source == "manual" || candidates.contains { $0.id == d.id } }
        for c in candidates where !next.contains(where: { $0.id == c.id }) {
            next.append(TicketDraft(candidate: c, selected: false, limit: 1))
        }
        if next != drafts { drafts = next }
    }

    private func perform(_ work: @escaping (AwayClient) throws -> Void) {
        guard let client, !busy else { return }
        busy = true
        message = nil
        Task.detached {
            let result = Result { try work(client) }
            await MainActor.run {
                self.busy = false
                if case .failure(let error) = result {
                    self.message = (error as? AwayFailure)?.message ?? error.localizedDescription
                }
                self.refresh()
            }
        }
    }

    func start() {
        let end = chosenEnd
        let tickets = drafts.filter(\.selected).map { (candidate: $0.candidate, limit: $0.limit) }
        perform { _ = try $0.on(end: end, tickets: tickets) }
    }

    func stop() {
        perform { client in
            let r = try client.off()
            if !r.caffeinate_released {
                throw AwayFailure(error: "caffeinate", message: "모드는 껐지만 잠자기 방지(caffeinate) 해제를 확인하지 못했습니다")
            }
        }
    }

    func clearReport() {
        perform { _ = try $0.report(clear: true) }
    }

    func addTicket(repo: String, stack: String) {
        let c = TicketCandidate(repo: repo, stack: stack)
        if let i = drafts.firstIndex(where: { $0.id == c.id }) { drafts[i].selected = true }
        else { drafts.append(TicketDraft(candidate: c, selected: true, limit: 1)) }
    }

    func chooseKit() {
        guard let path = Self.pickFolder(title: "37writes-claude-kit 폴더를 고르세요") else { return }
        guard KitLocator.isKit(path) else {
            message = "그 폴더에 scripts/away.py가 없습니다"
            return
        }
        UserDefaults.standard.set(path, forKey: KitLocator.defaultsKey)
        kit = path
        message = nil
        refresh()
    }

    static func pickFolder(title: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = title
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    func setLoginItem(_ on: Bool) {
        do {
            try LoginItem.set(on)
        } catch {
            message = "로그인 시 실행을 바꾸지 못했습니다: \(error.localizedDescription)"
        }
        loginItem = LoginItem.isEnabled
    }
}

/// 로그인 시 실행: SMAppService, 안 되면(로컬 서명 등) LaunchAgent plist. 앱만 열리고 모드는 켜지 않는다.
enum LoginItem {
    static let label = "com.37writes.awaybar"
    static var plist: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || FileManager.default.fileExists(atPath: plist.path)
    }

    static func set(_ on: Bool) throws {
        if on {
            do {
                try SMAppService.mainApp.register()
            } catch {
                guard let exe = Bundle.main.executablePath, Bundle.main.bundlePath.hasSuffix(".app") else { throw error }
                let body: [String: Any] = ["Label": label, "ProgramArguments": [exe], "RunAtLoad": true, "ProcessType": "Interactive"]
                let data = try PropertyListSerialization.data(fromPropertyList: body, format: .xml, options: 0)
                try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: plist, options: .atomic)
            }
        } else {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            if FileManager.default.fileExists(atPath: plist.path) { try FileManager.default.removeItem(at: plist) }
        }
    }
}
