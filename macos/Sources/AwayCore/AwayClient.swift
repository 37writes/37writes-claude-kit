import Foundation

/// kit 폴더(scripts/away.py가 있는 곳)를 찾는다: 환경 변수 → 저장된 경로 → 플러그인 설치 기록 → 기본 위치.
public enum KitLocator {
    public static let defaultsKey = "kitPath"
    public static let pluginKey = "kit@37writes"

    public static func isKit(_ path: String, fm: FileManager = .default) -> Bool {
        fm.fileExists(atPath: (path as NSString).appendingPathComponent("scripts/away.py"))
    }

    /// ~/.claude/plugins/installed_plugins.json에서 kit@37writes의 installPath들 (형식이 달라도 죽지 않게 느슨하게 읽는다).
    public static func installedPaths(json: Data) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return [] }
        let plugins = (root["plugins"] as? [String: Any]) ?? root
        var found: [String] = []
        func collect(_ value: Any) {
            if let dict = value as? [String: Any], let path = dict["installPath"] as? String { found.append(path) }
            if let list = value as? [Any] { list.forEach(collect) }
        }
        if let entry = plugins[pluginKey] { collect(entry) }
        return found
    }

    public static func candidates(home: String, saved: String?, env: [String: String], installedJSON: Data?, bundled: String? = nil) -> [String] {
        var list: [String] = []
        if let p = env["AWAYBAR_KIT"], !p.isEmpty { list.append(p) }
        if let p = saved, !p.isEmpty { list.append(p) }
        if let data = installedJSON { list += installedPaths(json: data) }
        list.append((home as NSString).appendingPathComponent("Documents/dev/37writes-claude-kit"))
        // 마지막: 설치할 때 앱 안에 넣어 둔 사본 (macOS가 ~/Documents 읽기를 막아도 앱이 동작하게)
        if let p = bundled, !p.isEmpty { list.append(p) }
        return list
    }

    public static func locate(home: String = NSHomeDirectory(), saved: String? = UserDefaults.standard.string(forKey: defaultsKey),
                              env: [String: String] = ProcessInfo.processInfo.environment, fm: FileManager = .default,
                              bundled: String? = Bundle.main.resourcePath.map { ($0 as NSString).appendingPathComponent("kit") }) -> String? {
        let installed = fm.contents(atPath: (home as NSString).appendingPathComponent(".claude/plugins/installed_plugins.json"))
        return candidates(home: home, saved: saved, env: env, installedJSON: installed, bundled: bundled).first { isKit($0, fm: fm) }
    }
}

/// away.py를 셸 없이 실행해 JSON을 읽는다. 판정·가림·잠금은 모두 away.py에 있다.
public struct AwayClient {
    public var kit: String
    public var python: String

    public static let pythonPaths = ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]

    public static func findPython(fm: FileManager = .default) -> String? {
        pythonPaths.first { fm.isExecutableFile(atPath: $0) }
    }

    public init(kit: String, python: String) {
        self.kit = kit; self.python = python
    }

    public struct Output {
        public var code: Int32
        public var stdout: Data
    }

    public func run(_ arguments: [String]) throws -> Output {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        p.arguments = [(kit as NSString).appendingPathComponent("scripts/away.py")] + arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (env["AWAYBAR_PATH"].map { $0 + ":" } ?? "") + "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        p.environment = env
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return Output(code: p.terminationStatus, stdout: data)
    }

    /// 유효한 JSON이고 ok가 참일 때만 값을 돌려준다. 아니면 away.py의 오류(또는 형식 오류)를 던진다.
    public static func decode<T: Decodable>(_ type: T.Type, from output: Output) throws -> T {
        // ok를 먼저 본다: ok가 false면 다른 필드가 없거나 자료형이 달라도 실패다
        if let object = (try? JSONSerialization.jsonObject(with: output.stdout)) as? [String: Any], (object["ok"] as? Bool) == false {
            throw AwayFailure(error: object["error"] as? String ?? "failed",
                              message: object["message"] as? String ?? "away.py가 실패를 알렸습니다 (끝 코드 \(output.code))")
        }
        guard output.code == 0, let value = try? JSONDecoder().decode(T.self, from: output.stdout) else {
            throw AwayFailure(error: "bad_output", message: "away.py 응답을 읽지 못했습니다 (끝 코드 \(output.code)). kit 폴더와 Python을 확인하세요")
        }
        return value
    }

    public func status() throws -> AwayStatus {
        try Self.decode(AwayStatus.self, from: run(["status", "--json"]))
    }

    public func report(clear: Bool = false) throws -> AwayReport {
        try Self.decode(AwayReport.self, from: run(["report", "--json"] + (clear ? ["--clear"] : [])))
    }

    public static func onArguments(end: EndChoice, tickets: [(candidate: TicketCandidate, limit: Int)]) -> [String] {
        ["on"] + end.arguments + tickets.flatMap { ["--ticket", "\($0.candidate.repo)::\($0.candidate.stack)::\($0.limit)"] } + ["--json"]
    }

    public func on(end: EndChoice, tickets: [(candidate: TicketCandidate, limit: Int)]) throws -> AwayStatus {
        try Self.decode(AwayStatus.self, from: run(Self.onArguments(end: end, tickets: tickets)))
    }

    public struct OffResult: Codable {
        public var ok: Bool
        public var was_active: Bool
        public var caffeinate_released: Bool
    }

    public func off() throws -> OffResult {
        try Self.decode(OffResult.self, from: run(["off", "--json"]))
    }
}
