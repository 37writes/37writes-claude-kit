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
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let message = model.message { notice(message) }
                    if model.active { activeSection } else { setupSection }
                    sessions
                    morning
                }
                .padding(14)
            }
            .frame(maxHeight: 520)
            Divider()
            footer
        }
        .frame(width: 372)
        .onAppear { model.panelOpen = true; model.refresh() }
        .onDisappear { model.panelOpen = false }
    }

    // MARK: 머리

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("자리 비움").font(.headline)
            Spacer()
            if model.active, let st = model.status {
                Text("\(Format.clock(st.until))까지 · \(Format.remainingWords(model.remaining)) 남음")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text("꺼짐").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func notice(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 켜기 전

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("언제까지")
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
            Text(endSummary).font(.callout).foregroundStyle(.secondary).monospacedDigit()
            powerRow
            tickets
            if let why = model.blocker {
                Label(why, systemImage: "bolt.slash").font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: model.start) {
                Text(model.busy ? "시작하는 중" : "자리 비움 시작").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(model.blocker != nil || model.busy)
        }
    }

    private var endSummary: String {
        let seconds = model.chosenEnd.seconds(from: model.now)
        let end = model.now.addingTimeInterval(TimeInterval(seconds))
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: end))까지 (\(Format.remainingWords(seconds)))"
    }

    private var powerRow: some View {
        let p = model.status?.power
        let source = p?.source == "ac" ? "전원 연결됨" : p?.source == "battery" ? "배터리" : "전원 확인 안 됨"
        let lid = p?.lid == "open" ? "뚜껑 열림" : p?.lid == "closed" ? "뚜껑 닫힘" : "뚜껑 확인 안 됨"
        return Label("\(source) · \(lid) · 시작하면 그 시각까지 잠들지 않습니다", systemImage: p?.source == "ac" ? "powerplug" : "battery.50")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var tickets: some View {
        VStack(alignment: .leading, spacing: 6) {
            title("배포 티켓 (선택)")
            if model.drafts.isEmpty {
                Text("없음. 티켓이 없으면 배포는 모두 거절되어 아침 목록에 남습니다.").font(.caption).foregroundStyle(.secondary)
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
                Button(newRepo.isEmpty ? "레포 폴더" : Format.repoName(newRepo)) {
                    if let path = AwayModel.pickFolder(title: "배포할 CDK 레포 폴더") { newRepo = path }
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
                Text("고른 스택은 테스트와 cdk diff 검사를 통과하면 사람이 보지 않은 코드가 배포됩니다. 삭제·교체·IAM·보안 그룹 변경은 배포하지 않습니다.")
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: 켜진 동안

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.remaining(model.remaining)).font(.system(size: 34, weight: .semibold)).monospacedDigit()
                Text("남음").foregroundStyle(.secondary)
                Spacer()
                if model.status?.caffeinate.alive == false {
                    Label("잠자기 방지 꺼짐", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            }
            Text("확인이 필요한 명령은 거절되어 목록에 남고, 질문은 보류됩니다.").font(.caption).foregroundStyle(.secondary)
            if let list = model.status?.tickets, !list.isEmpty {
                title("배포 티켓")
                ForEach(list) { t in
                    row(t.stack, Format.repoName(t.repo), t.locked ? "잠김" : "\(t.used)/\(t.limit)회 사용", warn: t.locked)
                }
            }
            Button(action: model.stop) { Text(model.busy ? "끄는 중" : "지금 끄기").frame(maxWidth: .infinity) }
                .controlSize(.large).disabled(model.busy)
        }
    }

    // MARK: 탭, 아침 목록

    private var sessions: some View {
        let list = model.status?.sessions ?? []
        return VStack(alignment: .leading, spacing: 6) {
            title("탭별 마지막 활동")
            if list.isEmpty { Text("기록 없음").font(.caption).foregroundStyle(.secondary) }
            ForEach(list.prefix(8)) { s in
                row(Format.repoName(s.repo.isEmpty ? s.cwd : s.repo), Format.event(s.last_event),
                    Format.ago(s.last_activity_at.isEmpty ? s.last_event_at : s.last_activity_at, now: model.now))
            }
        }
    }

    @ViewBuilder private var morning: some View {
        let r = model.report
        let empty = (r?.runs.isEmpty ?? true) && (r?.items.isEmpty ?? true) && (r?.holds.isEmpty ?? true)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                title("돌아와서 볼 것")
                Spacer()
                if !empty {
                    Button("비우기") { confirmClear = true }.controlSize(.small)
                        .confirmationDialog("실행된 배포·거절된 명령·보류된 질문 기록을 지울까요?", isPresented: $confirmClear) {
                            Button("지우기", role: .destructive, action: model.clearReport)
                        }
                }
            }
            if let failed = model.reportError {
                Text("목록을 읽지 못했습니다" + (r == nil ? "" : " (아래는 이전에 읽은 내용)") + ": " + failed)
                    .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else if empty {
                Text(r == nil ? "읽는 중" : "없음").font(.caption).foregroundStyle(.secondary)
            }
            if let runs = r?.runs, !runs.isEmpty {
                subtitle("실행된 배포 \(runs.count)")
                ForEach(runs) { run in
                    row(run.stack, Format.repoName(run.repo) + " · " + Format.clock(run.ts),
                        Format.runResult(run.result), warn: run.result != "deployed" && run.result != "no_changes")
                }
            }
            if let items = r?.items, !items.isEmpty {
                subtitle("거절된 명령 \(items.count)")
                ForEach(items) { item in
                    detail(item.command, Format.repoName(item.repo) + " · " + Format.clock(item.first) + (item.count > 1 ? " · \(item.count)회" : "") + " · " + item.reasons.joined(separator: ", "))
                }
            }
            if let holds = r?.holds, !holds.isEmpty {
                subtitle("보류된 질문 \(holds.count)")
                ForEach(holds) { hold in
                    detail(hold.text, Format.repoName(hold.repo) + " · " + Format.clock(hold.ts) + (hold.kind == "question" ? " · 질문 창" : " · 글로 물음"))
                }
            }
        }
    }

    // MARK: 바닥

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle("로그인 시 실행", isOn: Binding(get: { model.loginItem }, set: model.setLoginItem))
                .toggleStyle(.checkbox)
            Spacer()
            Button(model.kit == nil ? "kit 폴더 고르기" : "kit 폴더", action: model.chooseKit)
                .help(model.kit ?? "scripts/away.py가 있는 37writes-claude-kit 폴더")
            Button("종료") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small).font(.caption)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: 부품

    private func title(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    private func subtitle(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
    }

    private func chip(_ name: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(name).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered).tint(selected ? .accentColor : nil)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5))
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
