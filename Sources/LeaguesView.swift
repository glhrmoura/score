import SwiftUI

struct LeaguesScreen: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        if let country = hub.country {
            CountryScreen(country: country)
        } else {
            LeaguesIndex()
        }
    }
}

struct LeaguesIndex: View {
    @Environment(LeagueHub.self) private var hub
    @Environment(Catalog.self) private var catalog
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ligas")
                        .font(.display(28, weight: 780))
                        .tracking(-0.5)
                        .foregroundStyle(Palette.ink)
                    Text("Campeonatos de todos os países")
                        .font(.ui(14, 550))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                SearchField(text: $query, prompt: "Buscar país ou campeonato")
                    .frame(width: 300)
            }
            .padding(.horizontal, 40)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .windowDraggable()
            Hairline()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    let featured = League.featured.filter(matches)
                    let favorites = hub.favorites.filter(matches)
                    if !favorites.isEmpty {
                        Section {
                            LeagueTiles(leagues: favorites).padding(.bottom, 28)
                        } header: {
                            LetterHeader(text: "Favoritas")
                        }
                    }
                    if !featured.isEmpty {
                        Section {
                            LeagueTiles(leagues: featured).padding(.bottom, 28)
                        } header: {
                            LetterHeader(text: "Principais")
                        }
                    }
                    let regions = catalog.regions.filter(matches)
                    if !regions.isEmpty {
                        Section {
                            ForEach(regions) { CountryRow(country: $0) }
                        } header: {
                            LetterHeader(text: "Internacionais")
                        }
                    }
                    ForEach(letters, id: \.letter) { group in
                        Section {
                            ForEach(group.countries) { CountryRow(country: $0) }
                        } header: {
                            LetterHeader(text: group.letter)
                        }
                    }
                    if catalog.countries.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Carregando países…")
                                .font(.ui(13))
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .padding(.top, 30)
                    } else if !query.isEmpty, letters.isEmpty, regions.isEmpty, featured.isEmpty, favorites.isEmpty {
                        Notice(text: "Nada encontrado para “\(query)”.")
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .frame(maxWidth: 980, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .task { await catalog.loadCountries() }
    }

    private var letters: [(letter: String, countries: [Country])] {
        let visible = catalog.nations.filter(matches)
        let grouped = Dictionary(grouping: visible) { country in
            String(fold(country.name).prefix(1)).uppercased()
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    private func matches(_ league: League) -> Bool {
        query.isEmpty || fold(league.name).contains(fold(query)) || fold(league.country).contains(fold(query))
    }

    private func matches(_ country: Country) -> Bool {
        guard !query.isEmpty else { return true }
        if fold(country.name).contains(fold(query)) || fold(country.english).contains(fold(query)) { return true }
        return catalog.competitions[country.slug]?.contains { fold($0.name).contains(fold(query)) } ?? false
    }

    private func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .ptBR)
    }
}

struct LetterHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.display(16, weight: 760))
            .foregroundStyle(Palette.ink)
            .padding(.top, 26)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.canvas)
    }
}

struct LeagueTiles: View {
    @Environment(LeagueHub.self) private var hub
    let leagues: [League]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(leagues) { league in
                LeagueTile(league: league)
            }
        }
    }
}

struct LeagueTile: View {
    @Environment(LeagueHub.self) private var hub
    let league: League
    @State private var hovering = false

    var body: some View {
        Button {
            hub.select(league)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(league.name)
                        .font(.ui(13.5, 620))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(league.country)
                        .font(.ui(11.5, 500))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                FavoriteButton(league: league, size: 12)
                    .opacity(hovering || hub.isFavorite(league) ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Palette.raised : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(hovering ? Palette.inkSoft : Palette.rule, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct CountryRow: View {
    @Environment(LeagueHub.self) private var hub
    let country: Country
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.25)) { hub.country = country }
        } label: {
            HStack(spacing: 14) {
                Flag(country: country)
                Text(country.name)
                    .font(.ui(14, 560))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hovering ? Palette.ink : Palette.inkFaint)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Palette.raised.opacity(0.7) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .overlay(alignment: .bottom) { Hairline().padding(.leading, 50).opacity(hovering ? 0 : 1) }
    }
}

struct Flag: View {
    let country: Country
    var width: CGFloat = 24

    var body: some View {
        Group {
            if let url = country.flag {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().interpolation(.high).scaledToFill()
                    } else {
                        Palette.raised
                    }
                }
            } else {
                Image(systemName: country.regionSymbol)
                    .font(.system(size: width * 0.62, weight: .regular))
                    .foregroundStyle(Palette.pitch)
                    .frame(width: width, height: width * 0.68)
            }
        }
        .frame(width: width, height: width * 0.68)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay {
            if country.flag != nil {
                RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Palette.ink.opacity(0.12), lineWidth: 1)
            }
        }
    }
}

struct CountryScreen: View {
    @Environment(LeagueHub.self) private var hub
    @Environment(Catalog.self) private var catalog
    let country: Country

    var body: some View {
        VStack(spacing: 0) {
            PageBar(back: "Ligas") {
                withAnimation(.snappy(duration: 0.25)) { hub.country = nil }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    Flag(country: country, width: 48)
                    Text(country.name)
                        .font(.display(28, weight: 780))
                        .tracking(-0.5)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 22)
            Hairline()
            ScrollView {
                Group {
                    if let leagues = catalog.competitions[country.slug] {
                        if leagues.isEmpty {
                            Notice(text: "Nenhum campeonato encontrado.")
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(leagues) { CompetitionLink(league: $0) }
                            }
                        }
                    } else if catalog.failed.contains(country.slug) {
                        FailureNotice(message: "Não deu pra buscar os campeonatos.") {
                            Task { await catalog.loadCompetitions(of: country) }
                        }
                        .padding(.top, 40)
                    } else {
                        SkeletonList(rows: 8, rowHeight: 40, band: false)
                            .padding(.horizontal, -40)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: country.slug) { await catalog.loadCompetitions(of: country) }
    }
}

struct CompetitionLink: View {
    @Environment(LeagueHub.self) private var hub
    let league: League
    @State private var hovering = false

    var body: some View {
        Button {
            hub.select(league)
        } label: {
            HStack(spacing: 12) {
                Text(league.name)
                    .font(.ui(14, 560))
                    .foregroundStyle(Palette.ink)
                Spacer()
                FavoriteButton(league: league, size: 13)
                    .opacity(hovering || hub.isFavorite(league) ? 1 : 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hovering ? Palette.ink : Palette.inkFaint)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Palette.raised.opacity(0.7) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .overlay(alignment: .bottom) { Hairline().padding(.leading, 12).opacity(hovering ? 0 : 1) }
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.ui(14, 500))
                .foregroundStyle(Palette.ink)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
                .pointingHand()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(focused ? Palette.ink : Palette.rule, lineWidth: focused ? 1.5 : 1))
    }
}
