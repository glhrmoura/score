import Foundation

struct Team: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let short: String
    let logo: URL?
}

enum Phase: Hashable, Sendable {
    case scheduled
    case firstHalf
    case halfTime
    case secondHalf
    case extraTime
    case penalties
    case live
    case finished
    case postponed
    case cancelled
    case abandoned

    var isLive: Bool {
        switch self {
        case .firstHalf, .halfTime, .secondHalf, .extraTime, .penalties, .live: true
        default: false
        }
    }

    var hasScore: Bool {
        isLive || self == .finished
    }

    static func from(status: String?, detail: String?) -> Phase {
        if status != "2" {
            switch detail {
            case "4": return .postponed
            case "5": return .cancelled
            case "36", "37": return .abandoned
            default: break
            }
        }
        if status == "2" {
            switch detail {
            case "12": return .firstHalf
            case "38": return .halfTime
            case "13": return .secondHalf
            case "6", "41", "42", "40": return .extraTime
            case "7": return .penalties
            default: return .live
            }
        }
        return status == "3" ? .finished : .scheduled
    }
}

enum Outcome: Sendable {
    case win
    case draw
    case loss
}

struct Match: Identifiable, Hashable, Sendable {
    let id: String
    let kickoff: Date
    var stage: String?
    let section: String
    let sectionTitle: String?
    let home: Team
    let away: Team
    let homeScore: Int?
    let awayScore: Int?
    let phase: Phase
    let phaseStart: Date?
    var addedTime: Int? = nil

    var round: Int? {
        StageName.roundNumber(stage)
    }

    var stageKey: String {
        stage ?? sectionTitle ?? "Jogos"
    }

    func minute(at now: Date) -> String? {
        guard let phaseStart else { return nil }
        let elapsed = max(0, Int(now.timeIntervalSince(phaseStart) / 60)) + 1
        switch phase {
        case .firstHalf:
            return elapsed > 45 ? "45+\(elapsed - 45)'" : "\(elapsed)'"
        case .secondHalf:
            let minute = 45 + elapsed
            return minute > 90 ? "90+\(minute - 90)'" : "\(minute)'"
        default:
            return nil
        }
    }

    func clock(at now: Date) -> String? {
        guard let phaseStart else { return nil }
        let offset: Int
        switch phase {
        case .firstHalf: offset = 0
        case .secondHalf: offset = 45 * 60
        default: return nil
        }
        let seconds = offset + max(0, Int(now.timeIntervalSince(phaseStart)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func updated(phase: Phase, homeScore: Int?, awayScore: Int?, phaseStart: Date?, addedTime: Int? = nil) -> Match {
        Match(
            id: id, kickoff: kickoff, stage: stage, section: section, sectionTitle: sectionTitle,
            home: home, away: away,
            homeScore: homeScore ?? self.homeScore, awayScore: awayScore ?? self.awayScore,
            phase: phase, phaseStart: phaseStart ?? self.phaseStart,
            addedTime: phase.isLive ? addedTime : nil
        )
    }

    func taking(_ fresh: Match) -> Match {
        updated(phase: fresh.phase, homeScore: fresh.homeScore, awayScore: fresh.awayScore, phaseStart: fresh.phaseStart, addedTime: fresh.addedTime)
    }

    var winner: Team? {
        guard phase.hasScore, let homeScore, let awayScore, homeScore != awayScore else { return nil }
        return homeScore > awayScore ? home : away
    }
}

extension Match {
    init?(fields: [String: String], section: String, sectionTitle: String?) {
        guard
            let id = fields["AA"],
            let stamp = fields["AD"].flatMap(TimeInterval.init),
            let homeName = fields["AE"],
            let awayName = fields["AF"]
        else { return nil }

        self.id = id
        self.section = section
        self.sectionTitle = sectionTitle
        kickoff = Date(timeIntervalSince1970: stamp)
        stage = fields["ER"].flatMap { $0.isEmpty ? nil : $0 }
        home = Team(
            id: fields["PX"] ?? fields["JA"] ?? homeName,
            name: Self.clean(homeName),
            short: fields["WM"] ?? String(homeName.prefix(3)).uppercased(),
            logo: Self.logo(fields["OA"])
        )
        away = Team(
            id: fields["PY"] ?? fields["JB"] ?? awayName,
            name: Self.clean(awayName),
            short: fields["WN"] ?? String(awayName.prefix(3)).uppercased(),
            logo: Self.logo(fields["OB"])
        )
        phase = Phase.from(status: fields["AB"], detail: fields["AC"])
        homeScore = fields["AG"].flatMap { Int($0) }
        awayScore = fields["AH"].flatMap { Int($0) }
        phaseStart = fields["AO"].flatMap(TimeInterval.init).map { Date(timeIntervalSince1970: $0) }
    }

    private static func logo(_ file: String?) -> URL? {
        guard let file, !file.isEmpty else { return nil }
        return URL(string: "https://static.flashscore.com/res/image/data/\(file)")
    }

    private static func clean(_ name: String) -> String {
        name.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&#039;", with: "'")
    }
}

struct Stage: Identifiable, Hashable, Sendable {
    let key: String
    let title: String
    let short: String
    let round: Int?
    let anchor: Date

    var id: String { key }
}

enum StageName {
    static func roundNumber(_ raw: String?) -> Int? {
        guard let raw, raw.hasPrefix("Round ") else { return nil }
        return Int(raw.dropFirst(6))
    }

    static func describe(_ raw: String) -> (title: String, short: String) {
        if let number = roundNumber(raw) { return ("Rodada \(number)", "\(number)") }
        let lower = raw.lowercased()
        let table: [(String, String, String)] = [
            ("1/64", "64 avos de final", "64 avos"),
            ("1/32", "32 avos de final", "32 avos"),
            ("1/16", "16 avos de final", "16 avos"),
            ("1/8", "Oitavas de final", "Oitavas"),
            ("quarter", "Quartas de final", "Quartas"),
            ("semi", "Semifinal", "Semi"),
            ("3rd place", "Disputa de 3º lugar", "3º lugar"),
            ("third place", "Disputa de 3º lugar", "3º lugar"),
            ("knockout", "Playoffs", "Playoffs"),
            ("play off", "Playoffs", "Playoffs"),
            ("play-off", "Playoffs", "Playoffs"),
            ("preliminary", "Fase preliminar", "Prelim."),
            ("qualification", "Qualificação", "Qualif."),
            ("league phase", "Fase de liga", "Liga"),
            ("league a", "Liga A", "Liga A"),
            ("league b", "Liga B", "Liga B"),
            ("league c", "Liga C", "Liga C"),
            ("league d", "Liga D", "Liga D"),
            ("final", "Final", "Final"),
        ]
        for (needle, title, short) in table where lower.contains(needle) {
            return (title, short)
        }
        if lower.hasPrefix("group ") {
            let letter = raw.dropFirst(6)
            return ("Grupo \(letter)", "Grupo \(letter)")
        }
        let short = raw.count > 12 ? String(raw.prefix(11)) + "…" : raw
        return (raw, short)
    }
}

struct StandingRow: Identifiable, Sendable {
    let team: Team
    var played = 0
    var won = 0
    var drawn = 0
    var lost = 0
    var goalsFor = 0
    var goalsAgainst = 0
    var form: [Outcome] = []

    var id: String { team.id }
    var points: Int { won * 3 + drawn }
    var goalDifference: Int { goalsFor - goalsAgainst }
}

struct StandingTable: Identifiable, Sendable {
    let id: String
    let title: String?
    let rows: [StandingRow]
}

enum Standings {
    static func tables(from matches: [Match]) -> [StandingTable] {
        let bySection = Dictionary(grouping: matches.filter { $0.round != nil }, by: \.section)
        return bySection
            .map { section, items in
                StandingTable(id: section, title: items.first?.sectionTitle, rows: table(from: items))
            }
            .filter { $0.rows.count >= 3 }
            .sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    static func table(from matches: [Match]) -> [StandingRow] {
        var rows: [String: StandingRow] = [:]
        for match in matches {
            for team in [match.home, match.away] where rows[team.id] == nil {
                rows[team.id] = StandingRow(team: team)
            }
        }

        let finished = matches
            .filter { $0.phase == .finished && $0.homeScore != nil && $0.awayScore != nil }
            .sorted { $0.kickoff < $1.kickoff }

        for match in finished {
            guard let homeGoals = match.homeScore, let awayGoals = match.awayScore else { continue }
            apply(&rows[match.home.id]!, scored: homeGoals, conceded: awayGoals)
            apply(&rows[match.away.id]!, scored: awayGoals, conceded: homeGoals)
        }

        return rows.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference { return lhs.goalDifference > rhs.goalDifference }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.team.name.localizedCompare(rhs.team.name) == .orderedAscending
        }
    }

    private static func apply(_ row: inout StandingRow, scored: Int, conceded: Int) {
        row.played += 1
        row.goalsFor += scored
        row.goalsAgainst += conceded
        let outcome: Outcome
        if scored > conceded {
            row.won += 1
            outcome = .win
        } else if scored < conceded {
            row.lost += 1
            outcome = .loss
        } else {
            row.drawn += 1
            outcome = .draw
        }
        row.form = Array((row.form + [outcome]).suffix(5))
    }
}
