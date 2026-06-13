import SwiftUI

struct TeamHit: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let country: String
    let logo: URL?
    let women: Bool

    var page: URL {
        URL(string: "https://www.flashscore.com.br/equipe/\(slug)/\(id)/")!
    }

    struct Raw: Decodable {
        struct Named: Decodable { let id: Int?; let name: String? }
        struct Image: Decodable { let path: String; let variantTypeId: Int? }
        struct Country: Decodable { let name: String? }
        let id: String
        let url: String?
        let name: String
        let gender: Named?
        let type: Named?
        let sport: Named?
        let defaultCountry: Country?
        let images: [Image]?
    }

    init?(_ raw: Raw) {
        guard raw.type?.id == 2, raw.sport?.id == 1, let slug = raw.url else { return nil }
        id = raw.id
        name = raw.name
        self.slug = slug
        country = raw.defaultCountry?.name ?? ""
        women = raw.gender?.id == 2
        let image = raw.images?.first { $0.variantTypeId == 15 } ?? raw.images?.first
        logo = image.flatMap { URL(string: "https://static.flashscore.com/res/image/data/\($0.path)") }
    }
}

struct SearchScreen: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        if let team = hub.team {
            TeamPage(team: team)
        } else {
            SearchIndex()
        }
    }
}

struct SearchIndex: View {
    @Environment(LeagueHub.self) private var hub
    @State private var hits: [TeamHit] = []
    @State private var leagues: [League] = []
    @State private var searching = false
    @State private var failed = false
    @FocusState private var focused: Bool

    private let client = FeedClient()

    var body: some View {
        @Bindable var hub = hub
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Buscar")
                    .font(.display(28, weight: 780))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                    TextField("Time ou competição", text: $hub.query)
                        .textFieldStyle(.plain)
                        .font(.ui(16, 520))
                        .foregroundStyle(Palette.ink)
                        .focused($focused)
                    if searching {
                        ProgressView().controlSize(.small)
                    } else if !hub.query.isEmpty {
                        Button {
                            hub.query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(focused ? Palette.inkSoft : Palette.rule, lineWidth: 1))
            }
            .padding(.horizontal, 40)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .windowDraggable()
            Hairline()
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if hub.query.trimmingCharacters(in: .whitespaces).count < 2 {
                        Notice(text: "Digite o nome de um time ou de uma competição.")
                    } else if failed {
                        Notice(text: "Não deu pra buscar agora. Tente de novo em instantes.")
                    } else if hits.isEmpty && leagues.isEmpty && !searching {
                        Notice(text: "Nada encontrado para “\(hub.query)”.")
                    }
                    if !leagues.isEmpty {
                        Section {
                            ForEach(leagues) { league in
                                CompetitionHitRow(league: league)
                                Hairline()
                            }
                        } header: {
                            SectionBand(text: "Competições", color: Palette.inkSoft)
                        }
                    }
                    if !hits.isEmpty {
                        Section {
                            ForEach(hits) { hit in
                                TeamRow(hit: hit)
                                Hairline()
                            }
                        } header: {
                            SectionBand(text: "Times", color: Palette.inkSoft)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { focused = true }
        .task(id: hub.query) { await search(hub.query) }
    }

    private func search(_ raw: String) async {
        let query = raw.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            hits = []
            leagues = []
            searching = false
            return
        }
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }
        do {
            async let teams = client.searchTeams(query)
            async let competitions = try? client.searchCompetitions(query)
            let (found, foundLeagues) = try await (teams, competitions)
            guard !Task.isCancelled else { return }
            hits = found
            leagues = Array((foundLeagues ?? []).prefix(8))
            failed = false
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}

struct TeamRow: View {
    @Environment(LeagueHub.self) private var hub
    let hit: TeamHit
    @State private var hovering = false

    var body: some View {
        Button {
            hub.openTeam(hit)
        } label: {
            HStack(spacing: 14) {
                TeamLogo(url: hit.logo, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 8) {
                        Text(hit.name)
                            .font(.ui(14.5, 700))
                            .foregroundStyle(Palette.ink)
                        if hit.women {
                            Text("Feminino")
                                .font(.ui(10.5, 700))
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    Text(hit.country.uppercased())
                        .font(.ui(10.5, 700))
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hovering ? Palette.ink : Palette.inkFaint)
            }
            .padding(.horizontal, 40)
            .frame(height: 56)
            .background(hovering ? Palette.raised.opacity(0.6) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct CompetitionHitRow: View {
    @Environment(LeagueHub.self) private var hub
    let league: League
    @State private var hovering = false

    var body: some View {
        Button {
            hub.select(league)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "trophy")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(league.name)
                        .font(.ui(14.5, 700))
                        .foregroundStyle(Palette.ink)
                    Text(league.country.uppercased())
                        .font(.ui(10.5, 700))
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                FavoriteButton(league: league, size: 12)
                    .opacity(hovering || hub.isFavorite(league) ? 1 : 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hovering ? Palette.ink : Palette.inkFaint)
            }
            .padding(.horizontal, 40)
            .frame(height: 56)
            .background(hovering ? Palette.raised.opacity(0.6) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct TeamLogo: View {
    let url: URL?
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "shield")
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TeamPage: View {
    @Environment(LeagueHub.self) private var hub
    let team: TeamHit
    @State private var fixtures: [Competition] = []
    @State private var results: [Competition] = []
    @State private var loaded = false
    @State private var failed = false

    private let client = FeedClient()

    var body: some View {
        VStack(spacing: 0) {
            PageBar(back: "Buscar") { hub.closeTeam() }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    TeamLogo(url: team.logo, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name)
                            .font(.display(28, weight: 780))
                            .tracking(-0.5)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(team.women ? "\(team.country) · Feminino" : team.country)
                            .font(.ui(13, 500))
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 16)
            Hairline()
            Group {
                if !loaded {
                    SkeletonList(rows: 10, rowHeight: 56)
                } else if failed {
                    FailureNotice(message: "Não deu pra carregar os jogos deste time.") {
                        Task { await load() }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if !fixtures.isEmpty {
                                Section {
                                    rows(fixtures, newestFirst: false)
                                } header: {
                                    SectionBand(text: "Próximos jogos", color: Palette.inkSoft)
                                }
                            }
                            if !results.isEmpty {
                                Section {
                                    rows(results, newestFirst: true)
                                } header: {
                                    SectionBand(text: "Resultados", color: Palette.inkSoft)
                                }
                            }
                            if fixtures.isEmpty && results.isEmpty {
                                Notice(text: "Nenhum jogo encontrado para este time.")
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: team.id) { await load() }
    }

    @ViewBuilder
    private func rows(_ competitions: [Competition], newestFirst: Bool) -> some View {
        let items = competitions
            .flatMap { competition in competition.matches.map { (match: $0, origin: LeagueHub.Origin(competition)) } }
            .sorted { newestFirst ? $0.match.kickoff > $1.match.kickoff : $0.match.kickoff < $1.match.kickoff }
        ForEach(items, id: \.match.id) { item in
            DatedMatchLine(match: item.match, origin: item.origin)
            Hairline()
        }
    }

    private func load() async {
        failed = false
        do {
            let found = try await client.teamMatches(team)
            fixtures = found.fixtures
            results = found.results
        } catch {
            failed = true
        }
        loaded = true
    }
}

struct DatedMatchLine: View {
    let match: Match
    let origin: LeagueHub.Origin

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(match.kickoff.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits).locale(.ptBR)))
                    .font(.ui(12, 650))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(origin.name)
                    .font(.ui(10.5, 550))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.leading, 40)
            MatchLine(match: match, origin: origin, leading: 12)
        }
    }
}
