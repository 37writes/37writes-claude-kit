import Foundation

/// 패널에서 고르는 끝 시각. away.py on의 인자로 바뀐다.
public enum EndChoice: Equatable, Hashable {
    case minutes(Int)          // 지금부터 N분
    case clock(hour: Int, minute: Int)  // 다음에 오는 그 시각

    public static let maxSeconds = 12 * 3600

    public var arguments: [String] {
        switch self {
        case .minutes(let m):
            return ["--for", m % 60 == 0 ? "\(m / 60)h" : (m > 60 ? "\(m / 60)h\(m % 60)m" : "\(m)m")]
        case .clock(let h, let m):
            return ["--until", String(format: "%02d:%02d", h, m)]
        }
    }

    /// 지금부터 끝 시각까지의 초 (시각은 지났으면 내일).
    public func seconds(from now: Date, calendar: Calendar = .current) -> Int {
        switch self {
        case .minutes(let m):
            return m * 60
        case .clock(let h, let m):
            var parts = calendar.dateComponents([.year, .month, .day], from: now)
            parts.hour = h; parts.minute = m; parts.second = 0
            guard var end = calendar.date(from: parts) else { return 0 }
            if end <= now { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
            return Int(end.timeIntervalSince(now))
        }
    }

    /// away.py가 받는 범위(1초~12시간)인가.
    public func isAllowed(from now: Date, calendar: Calendar = .current) -> Bool {
        let s = seconds(from: now, calendar: calendar)
        return s > 0 && s <= EndChoice.maxSeconds
    }
}

public enum Format {
    /// 남은 시간: 상단바용 "6:58", 1분 미만은 "0:00"대.
    public static func remaining(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 3600, s % 3600 / 60)
    }

    public static func remainingWords(_ seconds: Int) -> String {
        let s = max(0, seconds), h = s / 3600, m = s % 3600 / 60
        if h == 0 { return m == 0 ? "1분 미만" : "\(m)분" }
        return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
    }

    /// ISO 시각("2026-11-26T08:00:00+09:00")의 HH:MM.
    public static func clock(_ iso: String?) -> String {
        guard let iso, let t = iso.firstIndex(of: "T") else { return "" }
        return String(iso[iso.index(after: t)...].prefix(5))
    }

    public static func ago(_ iso: String, now: Date) -> String {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: iso) else { return clock(iso) }
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "방금" }
        if s < 3600 { return "\(s / 60)분 전" }
        return "\(s / 3600)시간 \(s % 3600 / 60)분 전"
    }

    public static func repoName(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? path : name
    }

    public static func event(_ name: String) -> String {
        switch name {
        case "stop": return "턴 종료"
        case "resumed": return "이어 가게 함"
        case "question": return "질문 보류"
        case "prompt": return "입력 받음"
        case "start": return "세션 시작"
        default: return name
        }
    }

    public static func runResult(_ name: String) -> String {
        switch name {
        case "deployed": return "배포됨"
        case "no_changes": return "변경 없음"
        case "blocked": return "검사에서 막힘"
        case "failed": return "배포 실패"
        case "refused": return "티켓 없음"
        default: return name
        }
    }
}
