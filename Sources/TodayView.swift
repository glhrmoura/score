import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.display(28, weight: 780))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(detail)
                    .font(.ui(13, 500))
                    .foregroundStyle(Palette.inkSoft)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 40)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .windowDraggable()
    }
}

struct TodayScreen: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        let today = hub.today
        let date = today.date(for: today.offset)
        let day = today.days[today.offset]
        VStack(spacing: 0) {
            ScreenHeader(title: title(today.offset, date), detail: detail(date: date, day: day)) {
                EmptyView()
            }
            DateStrip()
            Hairline()
            Group {
                if let day {
                    if day.isEmpty {
                        Notice(text: "Nenhum jogo neste dia.")
                    } else {
                        CompetitionList(competitions: day, alwaysOpen: false)
                            .id(today.offset)
                    }
                } else if let failure = today.failures[today.offset] {
                    FailureNotice(message: failure) { today.reload() }
                } else {
                    SkeletonList(rows: 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detail(date: Date, day: [Competition]?) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ptBR)).capitalizingFirst
    }

    private func title(_ offset: Int, _ date: Date) -> String {
        switch offset {
        case 0: "Hoje"
        case -1: "Ontem"
        case 1: "Amanhã"
        default: date.formatted(.dateTime.weekday(.wide).locale(.ptBR)).capitalized(with: .ptBR)
        }
    }
}

struct LiveScreen: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        let today = hub.today
        let live = today.live
        VStack(spacing: 0) {
            ScreenHeader(title: "Ao vivo", detail: "Jogos em andamento") {
                EmptyView()
            }
            Hairline()
            Group {
                if today.days[0] == nil {
                    if let failure = today.failures[0] {
                        FailureNotice(message: failure) { today.reload() }
                    } else {
                        SkeletonList(rows: 12)
                    }
                } else if live.isEmpty {
                    VStack(spacing: 10) {
                        Text("Nenhum jogo ao vivo agora")
                            .font(.display(22, weight: 750))
                            .foregroundStyle(Palette.ink)
                        Text("Os jogos aparecem aqui assim que a bola rolar.")
                            .font(.ui(14))
                            .foregroundStyle(Palette.inkSoft)
                        Button("Ver jogos de hoje") { hub.show(.today) }
                            .buttonStyle(.plain)
                            .font(.ui(13, 650))
                            .foregroundStyle(Palette.canvas)
                            .padding(.horizontal, 18)
                            .frame(height: 34)
                            .background(Capsule().fill(Palette.ink))
                            .pointingHand()
                            .padding(.top, 8)
                    }
                } else {
                    CompetitionList(competitions: live, alwaysOpen: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FailureNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Não deu pra carregar os jogos")
                .font(.display(22, weight: 750))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.ui(14))
                .foregroundStyle(Palette.inkSoft)
            Button("Tentar de novo", action: retry)
                .buttonStyle(.plain)
                .font(.ui(13, 650))
                .foregroundStyle(Palette.canvas)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Capsule().fill(Palette.ink))
                .pointingHand()
        }
    }
}

struct DateStrip: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        let today = hub.today
        HStack(spacing: 0) {
            ForEach(Array(TodayStore.range), id: \.self) { offset in
                DayChip(date: today.date(for: offset), isToday: offset == 0, selected: offset == today.offset) {
                    withAnimation(.snappy) { today.offset = offset }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct DayChip: View {
    let date: Date
    let isToday: Bool
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(isToday ? "HOJE" : weekday)
                    .font(.band(11.5, 700))
                    .tracking(0.6)
                Text(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.ptBR)))
                    .font(.ui(12.5, 650))
                    .monospacedDigit()
            }
            .foregroundStyle(isToday ? Palette.live : (selected || hovering ? Palette.ink : Palette.inkSoft))
            .frame(minWidth: 50, maxWidth: .infinity)
            .frame(height: 44)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? (isToday ? Palette.live : Palette.ink) : .clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .help(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ptBR)))
    }

    private var weekday: String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(.ptBR))
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
    }
}

struct CompetitionList: View {
    @Environment(LeagueHub.self) private var hub
    let competitions: [Competition]
    let alwaysOpen: Bool

    var body: some View {
        let favorites = competitions.filter { isFavorite($0) }
        let others = competitions.filter { !isFavorite($0) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if !favorites.isEmpty {
                    Section {
                        ForEach(favorites) { CompetitionBlock(competition: $0, inline: alwaysOpen) }
                    } header: {
                        SectionBand(text: "Competições favoritas", color: Palette.gold)
                    }
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others) { CompetitionBlock(competition: $0, inline: alwaysOpen) }
                    } header: {
                        SectionBand(text: "Competições A–Z", color: Palette.inkSoft)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private func isFavorite(_ competition: Competition) -> Bool {
        hub.isFavorite(competition)
    }
}

struct SectionBand: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.band(12.5, 700))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background(Palette.raised)
    }
}

struct CompetitionBlock: View {
    @Environment(LeagueHub.self) private var hub
    let competition: Competition
    var inline = true
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()
            if inline {
                ForEach(sorted) { match in
                    MatchLine(match: match, origin: LeagueHub.Origin(competition))
                    Hairline()
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CompetitionStar(competition: competition)
                .frame(width: 16)
            Button {
                if inline {
                    if let league = competition.league { hub.select(league) }
                } else {
                    hub.openCompetition(competition.id)
                }
            } label: {
                HStack(spacing: 12) {
                    CompetitionLogo(url: competition.logo, fallback: competition.country)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(competition.name)
                            .font(.ui(14.5, 700))
                            .foregroundStyle(Palette.ink)
                            .underline(hovering && inline && competition.league != nil, color: Palette.inkSoft)
                            .lineLimit(1)
                        Text(competition.country.uppercased())
                            .font(.ui(10.5, 700))
                            .tracking(0.6)
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    let live = competition.liveCount
                    if live > 0 {
                        Text("\(live)")
                            .font(.ui(12, 750))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 20)
                            .padding(.horizontal, 2)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.live))
                            .help(live == 1 ? "1 jogo ao vivo" : "\(live) jogos ao vivo")
                    }
                    Text("\(competition.matches.count)")
                        .font(.ui(12.5, 650))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .frame(minWidth: 24, alignment: .trailing)
                        .help(competition.matches.count == 1 ? "1 jogo" : "\(competition.matches.count) jogos")
                    if !inline {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(hovering ? Palette.ink : Palette.inkFaint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(inline && competition.league == nil)
            .onHover { hovering = $0 }
            .pointingHand()
            .help(inline ? (competition.league == nil ? "" : "Ver tabela e rodadas") : "Ver jogos")
        }
        .padding(.leading, 24)
        .padding(.trailing, 40)
        .frame(height: 52)
        .background(inline ? Palette.surface : (hovering ? Palette.raised.opacity(0.6) : .clear))
    }

    private var sorted: [Match] {
        competition.matches.sorted { lhs, rhs in
            if lhs.phase.isLive != rhs.phase.isLive { return lhs.phase.isLive }
            return lhs.kickoff == rhs.kickoff ? lhs.home.name < rhs.home.name : lhs.kickoff < rhs.kickoff
        }
    }
}

struct CompetitionLogo: View {
    let url: URL?
    let fallback: String

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high).scaledToFit()
            } else {
                Text(fallback.prefix(2).uppercased())
                    .font(.ui(10, 750))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(width: 24, height: 24)
    }
}

extension String {
    var capitalizingFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}

struct CompetitionStar: View {
    @Environment(LeagueHub.self) private var hub
    let competition: Competition

    var body: some View {
        let on = hub.isFavorite(competition)
        Button {
            withAnimation(.snappy) { hub.toggleFavorite(competition) }
        } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(on ? Palette.gold : Palette.inkFaint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(competition.league == nil)
        .help(on ? "Remover dos favoritos" : "Adicionar aos favoritos")
        .pointingHand()
    }
}

struct CompetitionDayPage: View {
    @Environment(LeagueHub.self) private var hub
    let id: String

    var body: some View {
        let today = hub.today
        let competition = today.competitions.first { $0.id == id }
        VStack(spacing: 0) {
            PageBar(back: "Hoje", action: { hub.closeCompetition() }) {
                if let competition, let league = competition.league {
                    HStack(spacing: 10) {
                        PillLink(title: "Tabela e rodadas", symbol: "list.number") { hub.select(league) }
                        StarButton(on: hub.isFavorite(competition)) {
                            withAnimation(.snappy) { hub.toggleFavorite(competition) }
                        }
                    }
                }
            }
            HStack(alignment: .center, spacing: 16) {
                if let competition {
                    CompetitionLogo(url: competition.logo, fallback: competition.country)
                        .scaleEffect(1.6)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 12) {
                        Text(competition?.name ?? "Competição")
                            .font(.display(28, weight: 780))
                            .tracking(-0.5)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(detail(competition, today))
                        .font(.ui(13, 500))
                        .foregroundStyle(Palette.inkSoft)
                }
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 18)
            Hairline()
            if let competition {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groups(competition), id: \.key) { group in
                            SectionBand(text: group.title ?? "Jogos", color: Palette.inkSoft)
                            ForEach(group.matches) { match in
                                MatchLine(match: match, origin: LeagueHub.Origin(competition))
                                Hairline()
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            } else {
                Notice(text: "Esta competição não tem jogos neste dia.")
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func detail(_ competition: Competition?, _ today: TodayStore) -> String {
        var parts: [String] = []
        if let country = competition?.country, !country.isEmpty { parts.append(country) }
        parts.append(dayTitle(today))
        return parts.joined(separator: " · ")
    }

    private func dayTitle(_ today: TodayStore) -> String {
        let date = today.date(for: today.offset).formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.ptBR))
        switch today.offset {
        case 0: return "Hoje, \(date)"
        case -1: return "Ontem, \(date)"
        case 1: return "Amanhã, \(date)"
        default:
            let weekday = today.date(for: today.offset).formatted(.dateTime.weekday(.wide).locale(.ptBR)).capitalizingFirst
            return "\(weekday), \(date)"
        }
    }

    private func groups(_ competition: Competition) -> [(key: String, title: String?, matches: [Match])] {
        var order: [String] = []
        var grouped: [String: [Match]] = [:]
        for match in competition.matches {
            if grouped[match.section] == nil { order.append(match.section) }
            grouped[match.section, default: []].append(match)
        }
        return order.map { key in
            let items = (grouped[key] ?? []).sorted { lhs, rhs in
                if lhs.phase.isLive != rhs.phase.isLive { return lhs.phase.isLive }
                return lhs.kickoff == rhs.kickoff ? lhs.home.name < rhs.home.name : lhs.kickoff < rhs.kickoff
            }
            return (key, items.first?.sectionTitle, items)
        }
    }
}

struct StageHeader: View {
    let competition: Competition
    let stage: String?

    var body: some View {
        HStack(spacing: 12) {
            CompetitionLogo(url: competition.logo, fallback: competition.country)
            VStack(alignment: .leading, spacing: 1) {
                Text(stage.map { "\(competition.name) · \($0)" } ?? competition.name)
                    .font(.ui(14, 650))
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
                Text(competition.country.uppercased())
                    .font(.ui(10.5, 700))
                    .tracking(0.6)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(height: 52)
        .background(Palette.surface)
    }
}

