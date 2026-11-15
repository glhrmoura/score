import Foundation
import Observation

struct Competition: Identifiable, Sendable {
    let id: String
    let name: String
    let country: String
    let logo: URL?
    let league: League?
    var matches: [Match]

    var liveCount: Int {
        matches.filter { $0.phase.isLive }.count
    }
}

enum DayFeed {
    static func competitions(in text: String) -> [Competition] {
        var order: [String] = []
        var groups: [String: Competition] = [:]
        var current: String?
        var section = ""
        var stage: String?

        for fields in Feed.rows(text) {
            if let header = fields["ZA"] {
                let id = fields["ZEE"] ?? header
                current = id
                section = fields["ZC"] ?? id
                let parts = split(header)
                stage = parts.stage
                if groups[id] == nil {
                    order.append(id)
                    let country = fields["ZY"] ?? ""
                    groups[id] = Competition(
                        id: id,
                        name: parts.name,
                        country: country,
                        logo: fields["OAJ"].flatMap { $0.isEmpty ? nil : URL(string: "https://static.flashscore.com/res/image/data/\($0)") },
                        league: league(path: fields["ZL"], name: parts.name, country: country),
                        matches: []
                    )
                }
                continue
            }
            guard let current, fields["AA"] != nil,
                  var match = Match(fields: fields, section: section, sectionTitle: stage)
            else { continue }
            if match.stage == nil { match.stage = stage }
            groups[current]?.matches.append(match)
        }

        return order.compactMap { groups[$0] }.filter { !$0.matches.isEmpty }
    }

    private static func league(path raw: String?, name: String, country: String) -> League? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmed.hasPrefix("futebol/") else { return nil }
        return League(path: String(trimmed.dropFirst(8)), name: name, country: country, site: League.brazilSite)
    }

    private static let stageWords = [
        "playoff", "play-off", "grupo", "qualifica", "fase", "quadrangular", "disputa", "final", "finais",
        "super final", "semifina", "quartas", "oitavas", "rodada", "abertura", "encerramento", "apertura",
        "clausura", "temporada", "primeira", "segunda", "terceira", "quarta fase", "liga a", "liga b", "liga c", "liga d", "acesso", "rebaixamento", "taça",
    ]

    static func split(_ header: String) -> (name: String, stage: String?) {
        let body = header.split(separator: ":", maxSplits: 1).last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? header
        var parts = body.components(separatedBy: " - ")
        var stages: [String] = []
        while parts.count > 1, let last = parts.last, isStage(last) {
            stages.insert(last, at: 0)
            parts.removeLast()
        }
        let name = parts.joined(separator: " - ")
        let unique = stages.reduce(into: [String]()) { result, item in
            if result.last != item { result.append(item) }
        }
        return (name, unique.isEmpty ? nil : unique.joined(separator: " · "))
    }

    private static func isStage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return stageWords.contains { lower.hasPrefix($0) }
    }
}

@MainActor
@Observable
final class TodayStore {
    static let range = -7...7

    var offset = 0 {
        didSet { if offset != oldValue { Task { await load(offset, force: false) } } }
    }
    private(set) var days: [Int: [Competition]] = [:]
    private(set) var failures: [Int: String] = [:]
    private(set) var loading: Set<Int> = []
    private(set) var updatedAt: Date?

    @ObservationIgnored private let client = FeedClient()
    @ObservationIgnored private var loadedAt: [Int: Date] = [:]
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var settled: [String: Match] = [:]

    var refreshing: Bool {
        loading.contains(offset)
    }

    var competitions: [Competition] {
        days[offset] ?? []
    }

    var live: [Competition] {
        (days[0] ?? []).compactMap { competition in
            var copy = competition
            copy.matches = competition.matches.filter { $0.phase.isLive }
            return copy.matches.isEmpty ? nil : copy
        }
    }

    var liveCount: Int {
        live.reduce(0) { $0 + $1.matches.count }
    }

    func date(for offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now)) ?? .now
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await load(0, force: true)
                await checkStoppage()
                if offset != 0 { await load(offset, force: false) }
                try? await Task.sleep(for: .seconds(busy ? 30 : 120))
            }
        }
    }

    func reload() {
        Task { await load(offset, force: true) }
    }

    func apply(_ fresh: Match) {
        if !fresh.phase.isLive, fresh.phase != .scheduled { settled[fresh.id] = fresh }
        for (day, list) in days {
            guard list.contains(where: { $0.matches.contains { $0.id == fresh.id } }) else { continue }
            days[day] = list.map { competition in
                var copy = competition
                copy.matches = competition.matches.map { $0.id == fresh.id ? $0.taking(fresh) : $0 }
                return copy
            }
        }
    }

    private func reconcile(_ fresh: [Competition]) -> [Competition] {
        guard !settled.isEmpty else { return fresh }
        return fresh.map { competition in
            var copy = competition
            copy.matches = competition.matches.map { match in
                guard match.phase.isLive, let done = settled[match.id] else { return match }
                return match.taking(done)
            }
            return copy
        }
    }

    private func checkStoppage() async {
        let now = Date.now
        let candidates = (days[0] ?? []).flatMap(\.matches).filter { match in
            guard let start = match.phaseStart else { return false }
            let minutes = now.timeIntervalSince(start) / 60
            return (match.phase == .firstHalf || match.phase == .secondHalf) && minutes >= 44
        }
        for match in candidates.prefix(8) {
            if let fresh = try? await client.status(of: match) { apply(fresh) }
        }
    }

    private var busy: Bool {
        let now = Date.now
        return (days[0] ?? []).contains { competition in
            competition.matches.contains { match in
                if match.phase.isLive { return true }
                let delta = now.timeIntervalSince(match.kickoff)
                return match.phase == .scheduled && delta > -15 * 60 && delta < 3 * 3600
            }
        }
    }

    private func load(_ day: Int, force: Bool) async {
        if !force, let stamp = loadedAt[day], Date.now.timeIntervalSince(stamp) < 600 { return }
        guard !loading.contains(day) else { return }
        loading.insert(day)
        defer { loading.remove(day) }
        do {
            days[day] = reconcile(try await client.day(offset: day))
            failures[day] = nil
            loadedAt[day] = .now
            if day == 0 { updatedAt = .now }
        } catch {
            if days[day] == nil { failures[day] = error.localizedDescription }
        }
    }
}
