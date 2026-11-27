import Foundation

// away.py --json 출력과 같은 모양이다. 계약은 scripts/test_away.sh·test_away_deploy.sh가 고정한다.

/// 켜는 모드. away: 확인 창·질문을 보류한다. awake: 잠자기만 막고 나머지는 꺼져 있을 때와 같다.
public enum AwayMode: String, Equatable {
    case away, awake
}

/// kit 업데이트 전에 시작한 Claude 탭 (재시작 권장). Bash를 부른 탭만 보인다.
public struct StaleSession: Codable, Equatable, Identifiable {
    public var session: String
    public var repo: String
    public var cwd: String
    public var seen_at: String
    public var basis: String   // pid: 프로세스가 떠 있음을 확인 · time: 마지막 관측 시각으로 추정
    public var id: String { session + "|" + cwd + "|" + seen_at }
}

public struct AwayStatus: Codable, Equatable {
    public struct Caffeinate: Codable, Equatable {
        public var pid: Int?
        public var alive: Bool
    }
    public struct Power: Codable, Equatable {
        public var source: String
        public var lid: String
    }
    public var ok: Bool
    public var active: Bool
    public var expired: Bool
    public var until: String?
    public var until_epoch: Int?
    public var remaining_seconds: Int
    public var caffeinate: Caffeinate
    public var power: Power
    public var queue_count: Int
    public var holds_count: Int
    public var tickets: [Ticket]
    public var ticket_candidates: [TicketCandidate]
    public var sessions: [SessionInfo]
    public var warnings: [String]?
    public var mode: String?
    public var stale_sessions: [StaleSession]

    /// 켜져 있는 모드. 0.23 이전 kit는 mode를 주지 않는다: 켜져 있으면 자리 비움이다.
    public var activeMode: AwayMode? {
        guard active else { return nil }
        return AwayMode(rawValue: mode ?? "") ?? .away
    }

    /// 0.22 kit(1단계)의 status에는 뒤의 네 키가, 0.23에는 mode·stale_sessions가 없다. 본체를 아직 갱신하지 않았어도 켜기·끄기는 되게 빈 값으로 읽는다.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        active = try c.decode(Bool.self, forKey: .active)
        expired = try c.decode(Bool.self, forKey: .expired)
        until = try c.decodeIfPresent(String.self, forKey: .until)
        until_epoch = try c.decodeIfPresent(Int.self, forKey: .until_epoch)
        remaining_seconds = try c.decode(Int.self, forKey: .remaining_seconds)
        caffeinate = try c.decode(Caffeinate.self, forKey: .caffeinate)
        power = try c.decode(Power.self, forKey: .power)
        queue_count = try c.decode(Int.self, forKey: .queue_count)
        holds_count = try c.decodeIfPresent(Int.self, forKey: .holds_count) ?? 0
        tickets = try c.decodeIfPresent([Ticket].self, forKey: .tickets) ?? []
        ticket_candidates = try c.decodeIfPresent([TicketCandidate].self, forKey: .ticket_candidates) ?? []
        sessions = try c.decodeIfPresent([SessionInfo].self, forKey: .sessions) ?? []
        warnings = try c.decodeIfPresent([String].self, forKey: .warnings)
        mode = try c.decodeIfPresent(String.self, forKey: .mode)
        stale_sessions = try c.decodeIfPresent([StaleSession].self, forKey: .stale_sessions) ?? []
    }
}

/// 켜기 전에 앱이 미리 보여 주는 전원·뚜껑 판정. 최종 판정은 away.py가 한다.
public enum StartCheck {
    /// 시작할 수 없는 이유 (없으면 nil). 배터리는 자리 비움만 막는다 (잠자기만 막기는 사용자가 자리에 있다).
    public static func blocker(mode: AwayMode, power: AwayStatus.Power) -> String? {
        if power.source == "battery" && mode == .away {
            return "배터리로 동작 중입니다. 전원을 연결하면 시작할 수 있습니다 (잠자기만 막기는 배터리에서도 됩니다)"
        }
        if power.lid == "closed" { return "맥북이 덮여 있어요. 덮은 상태에서는 잠자기를 막을 수 없어 시작하지 않습니다" }
        return nil
    }

    /// 시작은 되지만 알려 둘 것 (없으면 nil).
    public static func warning(mode: AwayMode, power: AwayStatus.Power) -> String? {
        guard mode == .awake, power.source == "battery" else { return nil }
        return "배터리 상태예요. 키 입력이 없을 때의 잠자기만 막고, 덮거나 배터리가 떨어지면 잠들어요"
    }
}

public struct Ticket: Codable, Equatable, Identifiable {
    public var id: String
    public var repo: String
    public var stack: String
    public var limit: Int
    public var used: Int
    public var locked: Bool
    public var note: String
    public var tests: [String]
}

public struct TicketCandidate: Codable, Equatable, Hashable, Identifiable {
    public var repo: String
    public var stack: String
    public var source: String
    public var note: String
    public var id: String { repo + "::" + stack }
    public init(repo: String, stack: String, source: String = "manual", note: String = "") {
        self.repo = repo; self.stack = stack; self.source = source; self.note = note
    }
}

public struct SessionInfo: Codable, Equatable, Identifiable {
    public var session: String
    public var repo: String
    public var cwd: String
    public var last_event: String
    public var last_event_at: String
    public var last_activity_at: String
    public var id: String { session }
}

public struct AwayReport: Codable, Equatable {
    public struct Item: Codable, Equatable, Identifiable {
        public var key: String
        public var first: String
        public var last: String
        public var count: Int
        public var repo: String
        public var reasons: [String]
        public var command: String
        public var id: String { key }
    }
    public struct Hold: Codable, Equatable, Identifiable {
        public var ts: String
        public var kind: String
        public var repo: String
        public var session: String
        public var text: String
        public var id: String { session + kind + ts + text }
    }
    public struct Run: Codable, Equatable, Identifiable {
        public struct Step: Codable, Equatable {
            public var name: String
            public var ok: Bool
            public var detail: String
        }
        public var ts: String
        public var repo: String
        public var stack: String
        public var result: String
        public var code: Int?
        public var steps: [Step]
        public var log: String?
        public var id: String { ts + stack + result }
    }
    public var ok: Bool
    public var count: Int
    public var items: [Item]
    public var holds: [Hold]
    public var runs: [Run]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        count = try c.decode(Int.self, forKey: .count)
        items = try c.decode([Item].self, forKey: .items)
        holds = try c.decodeIfPresent([Hold].self, forKey: .holds) ?? []
        runs = try c.decodeIfPresent([Run].self, forKey: .runs) ?? []
    }
}

public struct AwayFailure: Codable, Error, Equatable {
    public var ok: Bool
    public var error: String
    public var message: String
    public init(error: String, message: String) {
        self.ok = false; self.error = error; self.message = message
    }
}
