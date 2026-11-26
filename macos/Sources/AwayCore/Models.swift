import Foundation

// away.py --json 출력과 같은 모양이다. 계약은 scripts/test_away.sh·test_away_deploy.sh가 고정한다.

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

    /// 0.22 kit(1단계)의 status에는 뒤의 네 키가 없다. 본체를 아직 갱신하지 않았어도 켜기·끄기는 되게 빈 값으로 읽는다.
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
