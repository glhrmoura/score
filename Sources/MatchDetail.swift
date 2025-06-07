import Foundation

enum Side: Sendable {
    case home
    case away
}

enum IncidentKind: Sendable {
    case goal
    case ownGoal
    case yellowCard
    case redCard
    case substitution
    case penaltyMissed
    case shootoutScored
    case shootoutMissed
}

struct Incident: Identifiable, Sendable {
    let id: String
    let side: Side
    let minute: String
    let kind: IncidentKind
    let player: String
    let detail: String?
    let homeScore: Int?
    let awayScore: Int?
}

struct MatchPeriod: Identifiable, Sendable {
    let id: Int
    let title: String
    let homeScore: Int?
    let awayScore: Int?
    let incidents: [Incident]
}

struct MatchStat: Identifiable, Sendable {
    let id: Int
    let name: String
    let home: String
    let away: String

    var homeShare: Double? {
        guard let left = Self.number(home), let right = Self.number(away) else { return nil }
        let total = left + right
        return total > 0 ? left / total : 0.5
    }

    private static func number(_ text: String) -> Double? {
        let digits = text.prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(digits)
    }
}

struct StatGroup: Identifiable, Sendable {
    let id: Int
    let title: String
    let stats: [MatchStat]
}

struct MatchFact: Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
    var symbol: String = "info.circle"
}

enum TVFeed {
    static func channels(_ text: String) -> [String] {
        var group: String?
        var names: [String] = []
        for fields in Feed.rows(text) {
            if let value = fields["EBG"] { group = value }
            if group == "1", let name = fields["BN"]?.trimmingCharacters(in: .whitespaces), !name.isEmpty, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }
}

struct MatchDetail: Sendable {
    var periods: [MatchPeriod] = []
    var groups: [StatGroup] = []
    var facts: [MatchFact] = []

    var isEmpty: Bool {
        periods.allSatisfy { $0.incidents.isEmpty } && groups.isEmpty
    }
}

enum DetailFeed {
    typealias Row = [(key: String, value: String)]

    static func rows(_ text: String) -> [Row] {
        text.split(separator: "~").map { row in
            row.split(separator: "¬").compactMap { pair in
                let parts = pair.split(separator: "÷", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]))
            }
        }
    }

    static func summary(_ text: String) -> (periods: [MatchPeriod], facts: [MatchFact]) {
        var periods: [MatchPeriod] = []
        var facts: [MatchFact] = []
        var title: String?
        var scores: (Int?, Int?) = (nil, nil)
        var incidents: [Incident] = []

        func close() {
            guard let title else { return }
            periods.append(MatchPeriod(id: periods.count, title: periodName(title), homeScore: scores.0, awayScore: scores.1, incidents: incidents))
        }

        for row in rows(text) {
            guard let first = row.first else { continue }
            switch first.key {
            case "AC":
                close()
                title = first.value
                scores = (int(row, "IG"), int(row, "IH"))
                incidents = []
            case "III":
                if let incident = incident(row) { incidents.append(incident) }
            case "MIT":
                facts = self.facts(row)
            default:
                continue
            }
        }
        close()
        return (periods.filter { !$0.incidents.isEmpty || $0.homeScore != nil }, facts)
    }

    static func stats(_ text: String) -> [StatGroup] {
        var groups: [StatGroup] = []
        var title = ""
        var stats: [MatchStat] = []
        var seenPeriod = false

        func close() {
            if !stats.isEmpty {
                groups.append(StatGroup(id: groups.count, title: StatName.group(title), stats: stats))
            }
            stats = []
        }

        for row in rows(text) {
            guard let first = row.first else { continue }
            switch first.key {
            case "SE":
                if seenPeriod { close(); return groups }
                seenPeriod = true
            case "SF":
                close()
                title = first.value
            case "SD":
                guard let name = value(row, "SG"), let home = value(row, "SH"), let away = value(row, "SI") else { continue }
                stats.append(MatchStat(id: stats.count, name: StatName.translate(name), home: home, away: away))
            default:
                continue
            }
        }
        close()
        return groups
    }

    private static func incident(_ row: Row) -> Incident? {
        guard let id = value(row, "III"), let sideCode = value(row, "IA") else { return nil }
        var parts: [(code: String, name: String, reason: String?)] = []
        for (index, pair) in row.enumerated() where pair.key == "IE" {
            let rest = row[(index + 1)...].prefix { $0.key != "IE" }
            let name = rest.first { $0.key == "IF" }?.value ?? ""
            let reason = rest.first { $0.key == "IL" }?.value
            parts.append((pair.value, name, reason))
        }

        let primaryCodes: [String: IncidentKind] = [
            "3": .goal, "4": .ownGoal, "1": .yellowCard, "2": .redCard,
            "6": .substitution, "10": .shootoutScored, "11": .penaltyMissed,
        ]
        guard let primary = parts.first(where: { primaryCodes[$0.code] != nil }),
              var kind = primaryCodes[primary.code]
        else { return nil }

        let isShootout = !(value(row, "IB") ?? "").hasSuffix("'")
        if kind == .penaltyMissed, isShootout { kind = .shootoutMissed }

        let detail: String?
        switch kind {
        case .goal:
            detail = parts.first { $0.code == "8" }.map { "Assist.: \($0.name)" }
        case .substitution:
            detail = parts.first { $0.code == "7" }?.name
        case .yellowCard, .redCard:
            detail = primary.reason.map(Reason.translate)
        default:
            detail = nil
        }

        return Incident(
            id: id,
            side: sideCode == "2" ? .away : .home,
            minute: isShootout ? "" : value(row, "IB") ?? "",
            kind: kind,
            player: primary.name,
            detail: detail,
            homeScore: int(row, "INX"),
            awayScore: int(row, "IOX")
        )
    }

    private static func facts(_ row: Row) -> [MatchFact] {
        var raw: [String: String] = [:]
        var key: String?
        for pair in row {
            if pair.key == "MIT" { key = pair.value }
            if pair.key == "MIV", let current = key { raw[current] = pair.value }
        }
        var facts: [MatchFact] = []
        if let referee = raw["REF"] {
            facts.append(MatchFact(id: "REF", label: "Árbitro", value: referee, symbol: "person.fill"))
        }
        if let venue = raw["VEN"] {
            facts.append(MatchFact(id: "VEN", label: "Estádio", value: venue, symbol: "sportscourt"))
        }
        if let town = raw["TWN"] {
            facts.append(MatchFact(id: "TWN", label: "Cidade", value: town, symbol: "mappin.and.ellipse"))
        }
        if let attendance = raw["ATT"] {
            facts.append(MatchFact(id: "ATT", label: "Público", value: attendance, symbol: "person.3.fill"))
        }
        if let capacity = raw["CAP"] {
            facts.append(MatchFact(id: "CAP", label: "Capacidade", value: capacity, symbol: "chair.lounge"))
        }
        return facts
    }

    private static func periodName(_ raw: String) -> String {
        switch raw {
        case "1st Half", "1º tempo": "1º tempo"
        case "2nd Half": "2º tempo"
        case "Extra Time": "Prorrogação"
        case "Penalties": "Pênaltis"
        case "": "Outros"
        default: raw
        }
    }

    private static func value(_ row: Row, _ key: String) -> String? {
        row.first { $0.key == key }?.value
    }

    private static func int(_ row: Row, _ key: String) -> Int? {
        value(row, key).flatMap { Int($0) }
    }
}

enum Reason {
    static func translate(_ raw: String) -> String {
        let table: [String: String] = [
            "Foul": "Falta",
            "Unsportsmanlike conduct": "Conduta antidesportiva",
            "Argument": "Reclamação",
            "Time wasting": "Cera",
            "Handball": "Mão na bola",
            "Injury": "Lesão",
            "Holding": "Puxão",
            "Diving": "Simulação",
            "Rough Play": "Jogo brusco",
            "Professional foul": "Falta tática",
        ]
        return table[raw] ?? raw
    }
}

enum StatName {
    static func group(_ raw: String) -> String {
        let table: [String: String] = [
            "Top stats": "Principais",
            "Shots": "Finalizações",
            "Attack": "Ataque",
            "Passes": "Passes",
            "Defense": "Defesa",
            "Goalkeeping": "Goleiros",
            "": "Estatísticas",
        ]
        return table[raw] ?? raw
    }

    static func translate(_ raw: String) -> String {
        let table: [String: String] = [
            "Expected goals (xG)": "Gols esperados (xG)",
            "Ball possession": "Posse de bola",
            "Total shots": "Finalizações",
            "Shots on target": "Chutes no gol",
            "Shots off target": "Chutes para fora",
            "Blocked shots": "Chutes bloqueados",
            "Big chances": "Grandes chances",
            "Corner kicks": "Escanteios",
            "Passes": "Passes",
            "Yellow cards": "Cartões amarelos",
            "Red cards": "Cartões vermelhos",
            "xG on target (xGOT)": "xG no alvo (xGOT)",
            "Shots inside the box": "Chutes dentro da área",
            "Shots outside the box": "Chutes de fora da área",
            "Hit the woodwork": "Bolas na trave",
            "Headed goals": "Gols de cabeça",
            "Touches in opposition box": "Toques na área adversária",
            "Accurate through passes": "Passes em profundidade certos",
            "Offsides": "Impedimentos",
            "Free kicks": "Tiros livres",
            "Long passes": "Passes longos",
            "Passes in final third": "Passes no terço final",
            "Crosses": "Cruzamentos",
            "Expected assists (xA)": "Assistências esperadas (xA)",
            "Throw ins": "Laterais",
            "Fouls": "Faltas",
            "Tackles": "Desarmes",
            "Duels won": "Duelos ganhos",
            "Clearances": "Cortes",
            "Interceptions": "Interceptações",
            "Errors leading to shot": "Erros que geraram chute",
            "Errors leading to goal": "Erros que geraram gol",
            "Goalkeeper saves": "Defesas do goleiro",
            "xGOT faced": "xGOT sofrido",
            "Goals prevented": "Gols evitados",
            "Goal kicks": "Tiros de meta",
        ]
        return table[raw] ?? raw
    }
}

struct H2HRow: Identifiable, Sendable {
    let id: String
    let date: Date
    let competition: String
    let home: String
    let away: String
    let homeLogo: URL?
    let awayLogo: URL?
    let homeScore: Int?
    let awayScore: Int?
    let outcome: Outcome?
}

struct H2HGroup: Identifiable, Sendable {
    let id: Int
    let title: String
    let rows: [H2HRow]
}

enum H2HFeed {
    static func groups(_ text: String) -> [H2HGroup] {
        var groups: [H2HGroup] = []
        var title: String?
        var rows: [H2HRow] = []
        var blocks = 0

        func close() {
            if let title, !rows.isEmpty {
                groups.append(H2HGroup(id: groups.count, title: title, rows: rows))
            }
            rows = []
        }

        for fields in Feed.rows(text) {
            if fields["KA"] != nil {
                blocks += 1
                if blocks > 1 { break }
                continue
            }
            if let header = fields["KB"] {
                close()
                title = header
                continue
            }
            guard let stamp = fields["KC"].flatMap(TimeInterval.init), let home = fields["KJ"], let away = fields["KK"] else { continue }
            let outcome: Outcome? = switch fields["WIS"] {
            case "w": .win
            case "d": .draw
            case "l": .loss
            default: nil
            }
            rows.append(H2HRow(
                id: (fields["KP"] ?? UUID().uuidString) + "\(rows.count)",
                date: Date(timeIntervalSince1970: stamp),
                competition: fields["KF"] ?? fields["KI"] ?? "",
                home: home.replacingOccurrences(of: "*", with: ""),
                away: away.replacingOccurrences(of: "*", with: ""),
                homeLogo: logo(fields["EC"]),
                awayLogo: logo(fields["ED"]),
                homeScore: fields["KU"].flatMap { Int($0) },
                awayScore: fields["KT"].flatMap { Int($0) },
                outcome: outcome
            ))
        }
        close()
        return groups
    }

    private static func logo(_ file: String?) -> URL? {
        guard let file, !file.isEmpty else { return nil }
        return URL(string: "https://static.flashscore.com/res/image/data/\(file)")
    }
}
