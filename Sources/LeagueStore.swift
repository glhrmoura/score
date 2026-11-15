import Foundation
import Observation

@MainActor
@Observable
final class LeagueStore {
    enum Load: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    let league: League
    private(set) var matches: [String: Match] = [:]
    private(set) var load: Load = .idle
    private(set) var updatedAt: Date?
    private(set) var isRefreshing = false
    var selectedStage: String?

    @ObservationIgnored private let client = FeedClient()
    @ObservationIgnored private var config: LeagueConfig?
    @ObservationIgnored private var lastSeasonLoad: Date?
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(league: League) {
        self.league = league
    }

    var stages: [Stage] {
        let grouped = Dictionary(grouping: matches.values, by: \.stageKey)
        return grouped.map { key, items in
            let dates = items.map(\.kickoff).sorted()
            let described = StageName.describe(key)
            return Stage(
                key: key,
                title: described.title,
                short: described.short,
                round: StageName.roundNumber(key),
                anchor: dates[dates.count / 2]
            )
        }
        .sorted { lhs, rhs in
            if let left = lhs.round, let right = rhs.round { return left < right }
            return lhs.anchor < rhs.anchor
        }
    }

    var liveMatches: [Match] {
        matches.values.filter { $0.phase.isLive }.sorted { $0.kickoff < $1.kickoff }
    }

    var currentStage: String? {
        let ordered = matches.values.sorted { $0.kickoff < $1.kickoff }
        if let live = ordered.first(where: { $0.phase.isLive }) { return live.stageKey }
        let upcoming = ordered.filter { $0.phase == .scheduled && $0.kickoff > .now.addingTimeInterval(-3 * 3600) }.prefix(6)
        var counts: [String: Int] = [:]
        for match in upcoming { counts[match.stageKey, default: 0] += 1 }
        let order = stages.map(\.key)
        let best = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return (order.firstIndex(of: lhs.key) ?? 0) > (order.firstIndex(of: rhs.key) ?? 0)
        }
        if let best { return best.key }
        return ordered.last(where: { $0.phase == .finished })?.stageKey ?? order.last
    }

    var shownStage: String? {
        selectedStage ?? currentStage
    }

    var tables: [StandingTable] {
        Standings.tables(from: Array(matches.values))
    }

    func matches(in stage: String) -> [Match] {
        matches.values
            .filter { $0.stageKey == stage }
            .sorted { $0.kickoff == $1.kickoff ? $0.home.name < $1.home.name : $0.kickoff < $1.kickoff }
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            let stale = (self?.lastSeasonLoad.map { Date.now.timeIntervalSince($0) } ?? .infinity) > 600
            await self?.refresh(season: stale)
            while !Task.isCancelled {
                let wait = self?.pollInterval ?? 300
                try? await Task.sleep(for: .seconds(wait))
                guard let self, !Task.isCancelled else { return }
                let stale = (lastSeasonLoad.map { Date.now.timeIntervalSince($0) } ?? .infinity) > 600
                await refresh(season: stale)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func reload() {
        Task { await refresh(season: true) }
    }

    private var inMatchWindow: Bool {
        let now = Date.now
        return matches.values.contains { match in
            if match.phase.isLive { return true }
            let delta = now.timeIntervalSince(match.kickoff)
            return match.phase == .scheduled && delta > -20 * 60 && delta < 3 * 3600
        }
    }

    private var playsToday: Bool {
        matches.values.contains { Calendar.current.isDateInToday($0.kickoff) }
    }

    private var pollInterval: Double {
        if inMatchWindow { return 30 }
        return playsToday ? 60 : 300
    }

    private func merge(_ fresh: [Match]) {
        var next = matches
        for var match in fresh {
            if match.stage == nil {
                match.stage = next[match.id]?.stage ?? Self.neighbourStage(of: match, in: next.values)
            }
            next[match.id] = match
        }
        matches = next
    }

    private static func neighbourStage(of match: Match, in pool: Dictionary<String, Match>.Values) -> String? {
        pool
            .filter { $0.section == match.section && $0.stage != nil && $0.id != match.id }
            .min { abs($0.kickoff.timeIntervalSince(match.kickoff)) < abs($1.kickoff.timeIntervalSince(match.kickoff)) }?
            .stage
    }

    private func refresh(season: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if matches.isEmpty { load = .loading }

        do {
            if season || config == nil {
                let discovered = try await client.discover(league)
                config = discovered
                merge(try await client.season(discovered))
                lastSeasonLoad = .now
            }
            if let config, season || inMatchWindow || playsToday, let today = try? await client.today(config) {
                merge(today)
            }
            updatedAt = .now
            load = .ready
        } catch {
            if matches.isEmpty {
                load = .failed(error.localizedDescription)
            }
        }
    }
}

@MainActor
@Observable
final class LeagueHub {
    private static let selectionKey = "selectedLeague.v2"
    private static let favoritesKey = "favoriteLeagues"
    private static let tournamentsKey = "favoriteTournaments"

    enum Screen: Hashable {
        case today
        case live
        case leagues
        case league
        case search
    }

    struct Origin: Equatable, Sendable {
        let name: String
        let league: League?
        let tournament: String?
        var logo: URL? = nil
        var country: String? = nil

        init(name: String, league: League?, tournament: String?, logo: URL? = nil, country: String? = nil) {
            self.name = name
            self.league = league
            self.tournament = tournament
            self.logo = logo
            self.country = country
        }

        init(_ competition: Competition) {
            self.init(name: competition.name, league: competition.league, tournament: competition.id, logo: competition.logo, country: competition.country)
        }
    }

    struct Opened: Equatable {
        let match: Match
        let origin: Origin?
    }

    private(set) var selected: League
    private(set) var favorites: [League]
    private(set) var screen: Screen = .today
    private(set) var opened: Opened?
    private(set) var competition: String?
    private(set) var team: TeamHit?
    var query = ""
    var country: Country?
    let today = TodayStore()

    @ObservationIgnored private var stores: [String: LeagueStore] = [:]

    init() {
        let defaults = UserDefaults.standard
        selected = defaults.data(forKey: Self.selectionKey)
            .flatMap { try? JSONDecoder().decode(League.self, from: $0) } ?? League.fallback
        favorites = defaults.data(forKey: Self.favoritesKey)
            .flatMap { try? JSONDecoder().decode([League].self, from: $0) } ?? []
        tournaments = defaults.data(forKey: Self.tournamentsKey)
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    private(set) var tournaments: [String: String] = [:]

    func isFavorite(_ competition: Competition) -> Bool {
        isFavorite(Origin(competition))
    }

    func toggleFavorite(_ competition: Competition) {
        toggleFavorite(Origin(competition))
    }

    func isFavorite(_ origin: Origin) -> Bool {
        if let tournament = origin.tournament, tournaments.values.contains(tournament) { return true }
        return origin.league.map(isFavorite) ?? false
    }

    func toggleFavorite(_ origin: Origin) {
        if isFavorite(origin) {
            let ids = origin.tournament.map { tournament in tournaments.filter { $0.value == tournament }.map(\.key) } ?? []
            favorites.removeAll { fav in ids.contains(fav.id) || origin.league.map { Self.same(fav, $0) } == true }
            for id in ids { tournaments[id] = nil }
        } else if let league = origin.league {
            favorites.append(league)
            if let tournament = origin.tournament { tournaments[league.id] = tournament }
        }
        persist(favorites, key: Self.favoritesKey)
        persist(tournaments, key: Self.tournamentsKey)
        Task { await resolveTournaments() }
    }

    private func resolveTournaments() async {
        let client = FeedClient()
        for league in favorites where tournaments[league.id] == nil {
            guard let config = try? await client.discover(league) else { continue }
            tournaments[league.id] = config.tournament
            persist(tournaments, key: Self.tournamentsKey)
        }
    }

    var current: LeagueStore {
        store(for: selected)
    }

    func start() {
        today.start()
        if screen == .league { current.start() }
        Task { await resolveTournaments() }
    }

    func openCompetition(_ id: String) {
        opened = nil
        competition = id
    }

    func closeCompetition() {
        competition = nil
    }

    func openTeam(_ hit: TeamHit) {
        opened = nil
        team = hit
    }

    func closeTeam() {
        team = nil
    }

    func showSearch() {
        team = nil
        show(.search)
    }

    private struct Location {
        let screen: Screen
        let league: League
        let competition: String?
        let team: TeamHit?
        let country: Country?
        let opened: Opened?
    }

    @ObservationIgnored private var history: [Location] = []
    private(set) var backTitle = "Ligas"

    private func snapshot() -> Location {
        Location(screen: screen, league: selected, competition: competition, team: team, country: country, opened: opened)
    }

    private func title(for location: Location) -> String {
        if location.opened != nil { return "Voltar" }
        switch location.screen {
        case .today: return location.competition == nil ? "Hoje" : "Voltar"
        case .live: return "Ao vivo"
        case .leagues: return location.country?.name ?? "Ligas"
        case .search: return location.team?.name ?? "Buscar"
        case .league: return location.league.name
        }
    }

    func goBack() {
        guard let last = history.popLast() else {
            showLeagues()
            return
        }
        if last.screen != .league || last.league != selected {
            current.stop()
        }
        if last.league != selected {
            selected = last.league
        }
        screen = last.screen
        competition = last.competition
        team = last.team
        country = last.country
        opened = last.opened
        if screen == .league { current.start() }
        backTitle = history.last.map(title(for:)) ?? "Ligas"
    }

    func show(_ next: Screen) {
        history = []
        opened = nil
        competition = nil
        guard next != screen else { return }
        if next == .league { current.start() } else { current.stop() }
        screen = next
    }

    func showLeagues() {
        country = nil
        show(.leagues)
    }

    func select(_ league: League) {
        if screen != .league || league != selected || opened != nil {
            let here = snapshot()
            history.append(here)
            backTitle = title(for: here)
        }
        opened = nil
        if league != selected {
            current.stop()
            selected = league
            persist(selected, key: Self.selectionKey)
        }
        screen = .league
        current.start()
    }

    func open(_ match: Match, origin: Origin?) {
        opened = Opened(match: match, origin: origin)
    }

    func closeMatch() {
        opened = nil
    }

    func refresh() {
        switch screen {
        case .today, .live, .leagues, .search: today.reload()
        case .league: current.reload()
        }
    }

    func isFavorite(_ league: League) -> Bool {
        favorites.contains { Self.same($0, league) }
    }

    private static func same(_ lhs: League, _ rhs: League) -> Bool {
        if lhs.id == rhs.id { return true }
        let fold: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR")) }
        return fold(lhs.name) == fold(rhs.name) && fold(lhs.country) == fold(rhs.country)
    }

    func toggleFavorite(_ league: League) {
        if isFavorite(league) {
            favorites.removeAll { Self.same($0, league) }
        } else {
            favorites.append(league)
        }
        persist(favorites, key: Self.favoritesKey)
        Task { await resolveTournaments() }
    }

    private func store(for league: League) -> LeagueStore {
        if let existing = stores[league.id] { return existing }
        let created = LeagueStore(league: league)
        stores[league.id] = created
        return created
    }

    private func persist(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
