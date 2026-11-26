import XCTest
@testable import AwayCore

final class AwayCoreTests: XCTestCase {
    func date(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: h, minute: m))!
    }

    func testEndChoiceArguments() {
        XCTAssertEqual(EndChoice.minutes(30).arguments, ["--for", "30m"])
        XCTAssertEqual(EndChoice.minutes(60).arguments, ["--for", "1h"])
        XCTAssertEqual(EndChoice.minutes(90).arguments, ["--for", "1h30m"])
        XCTAssertEqual(EndChoice.minutes(180).arguments, ["--for", "3h"])
        XCTAssertEqual(EndChoice.clock(hour: 8, minute: 0).arguments, ["--until", "08:00"])
    }

    func testClockRollsToTomorrowAndLimit() {
        let night = date(23, 0)
        XCTAssertEqual(EndChoice.clock(hour: 8, minute: 0).seconds(from: night), 9 * 3600)
        XCTAssertTrue(EndChoice.clock(hour: 8, minute: 0).isAllowed(from: night))
        // 오후 2시에 "아침 8시"는 18시간 뒤라 away.py가 거절한다 (최대 12시간)
        XCTAssertFalse(EndChoice.clock(hour: 8, minute: 0).isAllowed(from: date(14, 0)))
        XCTAssertEqual(EndChoice.clock(hour: 14, minute: 0).seconds(from: date(14, 0)), 24 * 3600)
        XCTAssertTrue(EndChoice.minutes(720).isAllowed(from: night))
        XCTAssertFalse(EndChoice.minutes(721).isAllowed(from: night))
    }

    func testFormat() {
        XCTAssertEqual(Format.remaining(6 * 3600 + 58 * 60 + 12), "6:58")
        XCTAssertEqual(Format.remaining(59), "0:00")
        XCTAssertEqual(Format.remaining(-5), "0:00")
        XCTAssertEqual(Format.remainingWords(7200), "2시간")
        XCTAssertEqual(Format.remainingWords(5400), "1시간 30분")
        XCTAssertEqual(Format.remainingWords(30), "1분 미만")
        XCTAssertEqual(Format.clock("2026-11-26T08:00:00+09:00"), "08:00")
        XCTAssertEqual(Format.clock(nil), "")
        XCTAssertEqual(Format.repoName("/Users/x/dev/newOpen"), "newOpen")
        XCTAssertEqual(Format.ago("2026-11-26T08:00:00+09:00", now: ISO8601DateFormatter().date(from: "2026-11-26T08:05:30+09:00")!), "5분 전")
    }

    func testDecodeStatusContract() throws {
        // scripts/away.py status --json의 실제 모양
        let json = """
        {"ok": true, "active": true, "expired": false, "until": "2026-11-26T16:02:46+09:00", "until_epoch": 1795676566,
         "remaining_seconds": 7199, "started": "2026-11-26T14:02:46+09:00", "caffeinate": {"pid": 38632, "alive": true},
         "power": {"source": "ac", "lid": "open"}, "queue_count": 1, "checks": [{"name": "power", "ok": true, "detail": "ac"}],
         "holds_count": 2,
         "tickets": [{"id": "t1", "repo": "/r/app", "stack": "Demo", "limit": 1, "used": 0, "locked": false, "note": "", "tests": ["sh t.sh"]}],
         "ticket_candidates": [{"repo": "/r/app", "stack": "Demo", "source": "request", "note": "가입 시험"}],
         "sessions": [{"session": "s1", "repo": "/r/app", "cwd": "/r/app", "last_event": "stop",
                       "last_event_at": "2026-11-26T14:00:00+09:00", "last_activity_at": "2026-11-26T14:01:00+09:00"}]}
        """
        let st = try AwayClient.decode(AwayStatus.self, from: .init(code: 0, stdout: Data(json.utf8)))
        XCTAssertTrue(st.active)
        XCTAssertEqual(st.tickets.first?.stack, "Demo")
        XCTAssertEqual(st.ticket_candidates.first?.id, "/r/app::Demo")
        XCTAssertEqual(st.sessions.first?.last_event, "stop")
        XCTAssertNil(st.warnings)
    }

    func testDecodeOffStatusWithNulls() throws {
        let json = """
        {"ok": true, "active": false, "expired": false, "until": null, "until_epoch": null, "remaining_seconds": 0, "started": null,
         "caffeinate": {"pid": null, "alive": false}, "power": {"source": "battery", "lid": "unknown"}, "queue_count": 0, "checks": [],
         "holds_count": 0, "tickets": [], "ticket_candidates": [], "sessions": []}
        """
        let st = try AwayClient.decode(AwayStatus.self, from: .init(code: 0, stdout: Data(json.utf8)))
        XCTAssertFalse(st.active)
        XCTAssertNil(st.until_epoch)
        XCTAssertEqual(st.power.source, "battery")
    }

    func testDecodeFailureAndGarbage() {
        let failure = #"{"ok": false, "error": "on_battery", "message": "배터리 상태에서는 켜지 않습니다"}"#
        XCTAssertThrowsError(try AwayClient.decode(AwayStatus.self, from: .init(code: 3, stdout: Data(failure.utf8)))) {
            XCTAssertEqual(($0 as? AwayFailure)?.error, "on_battery")
        }
        // py.sh처럼 Python이 없어도 0으로 끝나고 출력이 비는 경우를 성공으로 보지 않는다
        XCTAssertThrowsError(try AwayClient.decode(AwayStatus.self, from: .init(code: 0, stdout: Data()))) {
            XCTAssertEqual(($0 as? AwayFailure)?.error, "bad_output")
        }
        XCTAssertThrowsError(try AwayClient.decode(AwayStatus.self, from: .init(code: 0, stdout: Data("Traceback".utf8))))
        // ok:false면 오류 설명이 빠져 있어도, 끝 코드가 0이어도 실패 (S5 검증 D3)
        let bare = #"{"ok": false, "was_active": true, "caffeinate_released": true}"#
        XCTAssertThrowsError(try AwayClient.decode(AwayClient.OffResult.self, from: .init(code: 0, stdout: Data(bare.utf8)))) {
            XCTAssertEqual(($0 as? AwayFailure)?.error, "failed")
        }
        let odd = #"{"ok": false, "message": 7, "was_active": true, "caffeinate_released": true}"#
        XCTAssertThrowsError(try AwayClient.decode(AwayClient.OffResult.self, from: .init(code: 0, stdout: Data(odd.utf8))))
        // ok 모양이어도 끝 코드가 0이 아니면 실패
        XCTAssertThrowsError(try AwayClient.decode(AwayReport.self, from: .init(code: 1, stdout: Data(#"{"ok": true, "count": 0, "items": [], "holds": [], "runs": []}"#.utf8))))
    }

    func testDecodeOldKitWithoutNewKeys() throws {
        // 0.22(1단계) kit의 출력: 새 키가 없어도 읽는다
        let json = """
        {"ok": true, "active": false, "expired": false, "until": null, "until_epoch": null, "remaining_seconds": 0, "started": null,
         "caffeinate": {"pid": null, "alive": false}, "power": {"source": "ac", "lid": "open"}, "queue_count": 0, "checks": []}
        """
        let st = try AwayClient.decode(AwayStatus.self, from: .init(code: 0, stdout: Data(json.utf8)))
        XCTAssertEqual(st.sessions, [])
        XCTAssertEqual(st.tickets, [])
        let r = try AwayClient.decode(AwayReport.self, from: .init(code: 0, stdout: Data(#"{"ok": true, "count": 0, "items": []}"#.utf8)))
        XCTAssertEqual(r.holds, [])
    }

    func testDecodeReport() throws {
        let json = """
        {"ok": true, "count": 1,
         "items": [{"key": "k", "first": "2026-11-26T01:08:00+09:00", "last": "2026-11-26T01:09:00+09:00", "count": 2, "repo": "/r/app", "reasons": ["CDK"], "command": "npx cdk deploy X"}],
         "holds": [{"ts": "2026-11-26T02:00:00+09:00", "kind": "stop", "repo": "/r/app", "session": "s1", "text": "어느 쪽으로 할까요?"}],
         "runs": [{"ts": "2026-11-26T03:00:00+09:00", "repo": "/r/app", "stack": "Demo", "result": "deployed", "code": 0,
                   "steps": [{"name": "cdk diff", "ok": true, "detail": "추가 1, 수정 1"}], "diff": {"added": 1, "changed": 1}, "log": "/tmp/x.log"}]}
        """
        let r = try AwayClient.decode(AwayReport.self, from: .init(code: 0, stdout: Data(json.utf8)))
        XCTAssertEqual(r.items.first?.count, 2)
        XCTAssertEqual(r.holds.first?.kind, "stop")
        XCTAssertEqual(r.runs.first?.steps.first?.name, "cdk diff")
    }

    func testOnArguments() {
        let t = TicketCandidate(repo: "/r/my app", stack: "Demo")
        XCTAssertEqual(AwayClient.onArguments(end: .minutes(120), tickets: [(t, 2)]),
                       ["on", "--for", "2h", "--ticket", "/r/my app::Demo::2", "--json"])
        XCTAssertEqual(AwayClient.onArguments(end: .clock(hour: 8, minute: 0), tickets: []), ["on", "--until", "08:00", "--json"])
    }

    func testKitLocatorOrderAndInstalledJSON() throws {
        let v2 = #"{"version": 2, "plugins": {"kit@37writes": [{"scope": "user", "installPath": "/p/cache/kit/0.23.0"}], "other@x": [{"installPath": "/no"}]}}"#
        XCTAssertEqual(KitLocator.installedPaths(json: Data(v2.utf8)), ["/p/cache/kit/0.23.0"])
        XCTAssertEqual(KitLocator.installedPaths(json: Data(#"{"kit@37writes": {"installPath": "/flat"}}"#.utf8)), ["/flat"])
        XCTAssertEqual(KitLocator.installedPaths(json: Data("not json".utf8)), [])
        XCTAssertEqual(KitLocator.candidates(home: "/h", saved: "/saved", env: ["AWAYBAR_KIT": "/env"], installedJSON: Data(v2.utf8)),
                       ["/env", "/saved", "/p/cache/kit/0.23.0", "/h/Documents/dev/37writes-claude-kit"])

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("kit/scripts"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertNil(KitLocator.locate(home: tmp.path, saved: tmp.appendingPathComponent("kit").path, env: [:]))
        FileManager.default.createFile(atPath: tmp.appendingPathComponent("kit/scripts/away.py").path, contents: Data())
        XCTAssertEqual(KitLocator.locate(home: tmp.path, saved: tmp.appendingPathComponent("kit").path, env: [:]), tmp.appendingPathComponent("kit").path)
    }

    /// 실제 away.py를 가짜 전원 명령·격리 HOME으로 돌려 켜기 → 상태 → 끄기를 확인한다.
    func testRealAwayScriptRoundTrip() throws {
        let kit = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        guard KitLocator.isKit(kit), let python = AwayClient.findPython() else { throw XCTSkip("kit 또는 python3 없음") }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bin = tmp.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let fakes = [
            "pmset": "#!/bin/sh\ncase \"$2\" in batt) echo \"Now drawing from 'AC Power'\" ;; esac\nexit 0\n",
            "ioreg": "#!/bin/sh\necho '  |   \"AppleClamshellState\" = No'\n",
            "caffeinate": "#!/bin/sh\ntrap 'kill $c 2>/dev/null; exit 0' TERM\nsleep 600 & c=$!\nwait\n",
        ]
        for (name, body) in fakes {
            let url = bin.appendingPathComponent(name)
            try body.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        setenv("HOME", tmp.path, 1)
        setenv("AWAYBAR_PATH", bin.path, 1)
        defer { unsetenv("AWAYBAR_PATH") }
        let client = AwayClient(kit: kit, python: python)
        XCTAssertFalse(try client.status().active)
        let on = try client.on(end: .minutes(60), tickets: [])
        XCTAssertTrue(on.active)
        XCTAssertTrue((3500...3600).contains(on.remaining_seconds))
        XCTAssertTrue(try client.status().caffeinate.alive)
        XCTAssertThrowsError(try client.on(end: .minutes(60), tickets: [(TicketCandidate(repo: "/nope", stack: "Demo"), 1)])) {
            XCTAssertEqual(($0 as? AwayFailure)?.error, "bad_ticket")
        }
        let off = try client.off()
        XCTAssertTrue(off.was_active && off.caffeinate_released)
        XCTAssertFalse(try client.status().active)
        XCTAssertEqual(try client.report().count, 0)
    }
}
