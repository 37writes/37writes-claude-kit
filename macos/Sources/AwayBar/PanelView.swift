import AwayCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var model: AwayModel
    @State private var newStack = ""
    @State private var newRepo = ""
    @State private var confirmClear = false

    private let presets: [(String, EndChoice)] = [
        ("30분", .minutes(30)), ("1시간", .minutes(60)), ("2시간", .minutes(120)), ("3시간", .minutes(180)),
        ("아침 8시", .clock(hour: 8, minute: 0)),
    ]

    var body: some View {
        // ScrollView를 쓰지 않는다: 상단바 창은 내용 크기에 맞추는데 ScrollView는 높이 0으로 접힌다. 목록은 건수를 잘라 보인다.
        VStack(alignment: .leading, spacing: 16) {
            header
            if let message = model.message { notice(message) }
            if model.active { activeSection } else { setupSection }
            sessions
            morning
            footer
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { model.panelOpen = true; model.refresh() }
        .onDisappear { model.panelOpen = false }
    }

    // MARK: 머리

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: model.active ? "moon.zzz.fill" : "moon.zzz")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(model.active ? Color.accentColor : .secondary)
            Text("자리 비움").font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(model.active ? "켜짐" : "꺼짐")
                .font(.caption.weight(.medium))
                .foregroundStyle(model.active ? Color.accentColor : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((model.active ? Color.accentColor : Color.primary).opacity(0.12), in: Capsule())
        }
    }

    private func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: 켜기 전

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(endClock).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("까지 · " + Format.remainingWords(model.chosenEnd.seconds(from: model.now)))
                    .font(.callout).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(presets, id: \.0) { name, choice in
                    chip(name, selected: !model.useCustom && model.end == choice) {
                        model.useCustom = false; model.end = choice
                    }
                }
                chip("직접", selected: model.useCustom) { model.useCustom = true }
            }
            if model.useCustom {
                DatePicker("끝 시각", selection: $model.custom, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field).font(.callout)
            }
            tickets
            VStack(spacing: 8) {
                Button(action: model.start) {
                    Text(model.busy ? "시작하는 중" : "자리 비움 시작")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .foregroundStyle(.white)
                        .background(Color.accentColor.opacity(model.blocker != nil || model.busy ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(model.blocker != nil || model.busy)
                if let why = model.blocker {
                    Label(why, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    powerRow.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var endClock: String {
        let end = model.now.addingTimeInterval(TimeInterval(model.chosenEnd.seconds(from: model.now)))
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: end)
    }

    private var powerRow: some View {
        let p = model.status?.power
        let source = p?.source == "ac" ? "전원 연결됨" : p?.source == "battery" ? "배터리" : "전원 확인 안 됨"
        let lid = p?.lid == "open" ? "뚜껑 열림" : p?.lid == "closed" ? "뚜껑 닫힘" : "뚜껑 확인 안 됨"
        return Label("\(source) · \(lid) · 그 시각까지 잠들지 않습니다", systemImage: p?.source == "ac" ? "powerplug" : "battery.50")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var tickets: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title("배포 티켓")
                Spacer()
                Text(model.drafts.contains(where: \.selected) ? "고른 스택만 배포" : "없으면 배포는 모두 보류").font(.caption2).foregroundStyle(.tertiary)
            }
            ForEach($model.drafts) { $draft in
                HStack(spacing: 8) {
                    Toggle(isOn: $draft.selected) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(draft.candidate.stack).font(.callout)
                            Text(Format.repoName(draft.candidate.repo) + (draft.candidate.note.isEmpty ? "" : " · " + draft.candidate.note))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                    if draft.selected {
                        Stepper("\(draft.limit)회", value: $draft.limit, in: 1...3).font(.caption).fixedSize()
                    }
                }
            }
            HStack(spacing: 6) {
                Button {
                    if let path = AwayModel.pickFolder(title: "배포할 CDK 레포 폴더") { newRepo = path }
                } label: {
                    Label(newRepo.isEmpty ? "레포" : Format.repoName(newRepo), systemImage: "folder").lineLimit(1)
                }
                TextField("스택 이름", text: $newStack).textFieldStyle(.roundedBorder)
                Button("추가") {
                    model.addTicket(repo: newRepo, stack: newStack.trimmingCharacters(in: .whitespaces))
                    newStack = ""
                }
                .disabled(newRepo.isEmpty || newStack.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.small)
            if model.drafts.contains(where: \.selected) {
                Text("테스트와 cdk diff 검사를 통과하면 사람이 보지 않은 코드가 배포됩니다. 삭제·교체·IAM·보안 그룹 변경은 배포하지 않습니다.")
                    .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    // MARK: 켜진 동안

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.remaining(model.remaining)).font(.system(size: 40, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("남음 · \(Format.clock(model.status?.until))까지").font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
            if model.status?.caffeinate.alive == false {
                notice("잠자기 방지가 꺼져 있습니다. 맥이 잠들 수 있습니다")
            }
            if let list = model.status?.tickets, !list.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    title("배포 티켓")
                    ForEach(list) { t in
                        row(t.stack, Format.repoName(t.repo), t.locked ? "잠김" : "\(t.used)/\(t.limit)회 사용", warn: t.locked)
                    }
                }
                .card()
            }
            VStack(spacing: 8) {
                Button(action: model.stop) {
                    Text(model.busy ? "끄는 중" : "지금 끄기")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain).disabled(model.busy)
                Text("확인이 필요한 명령은 거절되어 목록에 남고, 질문은 보류됩니다.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: 탭, 아침 목록

    @ViewBuilder private var sessions: some View {
        let list = model.status?.sessions ?? []
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                title("탭별 마지막 활동")
                ForEach(list.prefix(6)) { s in
                    row(Format.repoName(s.repo.isEmpty ? s.cwd : s.repo), Format.event(s.last_event),
                        Format.ago(s.last_activity_at.isEmpty ? s.last_event_at : s.last_activity_at, now: model.now))
                }
                if list.count > 6 { more(list.count - 6) }
            }
            .card()
        }
    }

    @ViewBuilder private var morning: some View {
        let r = model.report
        let empty = (r?.runs.isEmpty ?? true) && (r?.items.isEmpty ?? true) && (r?.holds.isEmpty ?? true)
        // 볼 것이 없으면 영역을 그리지 않는다 (읽기 실패는 보인다)
        if !empty || model.reportError != nil {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    title("돌아와서 볼 것")
                    Spacer()
                    if !empty {
                        Button("비우기") { confirmClear = true }.buttonStyle(.link).font(.caption)
                            .confirmationDialog("실행된 배포·거절된 명령·보류된 질문 기록을 지울까요?", isPresented: $confirmClear) {
                                Button("지우기", role: .destructive, action: model.clearReport)
                            }
                    }
                }
                if let failed = model.reportError {
                    Text("목록을 읽지 못했습니다" + (r == nil ? "" : " (아래는 이전에 읽은 내용)") + ": " + failed)
                        .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let runs = r?.runs, !runs.isEmpty {
                    subtitle("실행된 배포 \(runs.count)")
                    ForEach(runs.suffix(4)) { run in
                        row(run.stack, Format.repoName(run.repo) + " · " + Format.clock(run.ts),
                            Format.runResult(run.result), warn: run.result != "deployed" && run.result != "no_changes")
                    }
                    if runs.count > 4 { more(runs.count - 4) }
                }
                if let items = r?.items, !items.isEmpty {
                    subtitle("거절된 명령 \(items.count)")
                    ForEach(items.prefix(4)) { item in
                        detail(item.command, Format.repoName(item.repo) + " · " + Format.clock(item.first) + (item.count > 1 ? " · \(item.count)회" : "") + " · " + item.reasons.joined(separator: ", "))
                    }
                    if items.count > 4 { more(items.count - 4) }
                }
                if let holds = r?.holds, !holds.isEmpty {
                    subtitle("보류된 질문 \(holds.count)")
                    ForEach(holds.prefix(4)) { hold in
                        detail(hold.text, Format.repoName(hold.repo) + " · " + Format.clock(hold.ts) + (hold.kind == "question" ? " · 질문 창" : " · 글로 물음"))
                    }
                    if holds.count > 4 { more(holds.count - 4) }
                }
            }
            .card()
        }
    }

    // MARK: 바닥

    private var footer: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(get: { model.loginItem }, set: model.setLoginItem)) {
                Text("로그인 시 실행").font(.caption).foregroundStyle(.secondary)
            }
            .toggleStyle(.switch).controlSize(.mini)
            Spacer()
            Menu {
                Button(model.kit == nil ? "kit 폴더 고르기" : "kit 폴더 바꾸기", action: model.chooseKit)
                if let kit = model.kit { Text(kit) }
                Divider()
                Button("AwayBar 종료") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
    }

    // MARK: 부품

    private func title(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
    }

    private func more(_ n: Int) -> some View {
        Text("외 \(n)건 (전체: away.py report)").font(.caption2).foregroundStyle(.tertiary)
    }

    private func chip(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name).font(.system(size: 12, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity).padding(.vertical, 6)
                .foregroundStyle(selected ? Color.white : Color.primary)
                .background(selected ? Color.accentColor : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func row(_ name: String, _ note: String, _ value: String, warn: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(name).font(.callout).lineLimit(1)
            Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(value).font(.caption).foregroundStyle(warn ? .orange : .secondary).monospacedDigit().lineLimit(1)
        }
    }

    private func detail(_ text: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(text).font(.system(.caption, design: .monospaced)).lineLimit(3).textSelection(.enabled)
            Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// 묶음 하나: 옅은 바탕의 둥근 카드
    func card() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
