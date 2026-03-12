import SwiftUI

enum MatchTab: String, CaseIterable, Identifiable {
    case summary
    case stats
    case h2h
    case details

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary: "Sumário"
        case .stats: "Estatísticas"
        case .h2h: "Confrontos"
        case .details: "Detalhes"
        }
    }
}

struct MatchPage: View {
    @Environment(LeagueHub.self) private var hub
    let initial: Match
    let origin: LeagueHub.Origin?

    @State private var live: Match?
    @State private var detail: MatchDetail?
    @State private var h2h: [H2HGroup]?
    @State private var h2hFailed = false
    @State private var channels: [String]?
    @State private var failure: String?
    @State private var tab: MatchTab = .summary

    private let client = FeedClient()

    private var match: Match {
        live ?? initial
    }

    private var tabs: [MatchTab] {
        MatchTab.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            MatchTopBar(origin: origin) { hub.closeMatch() }
            ScrollView {
                VStack(spacing: 0) {
                    MatchHero(match: match)
                    MatchTabs(tabs: tabs, selection: tab) { tab = $0 }
                    Hairline()
                    content
                }
                .padding(.bottom, 40)
            }
        }
        .background(Palette.canvas)
        .task(id: initial.id) { await poll() }
        .task(id: tab) {
            if tab == .h2h, h2h == nil { await loadH2H() }
            if tab == .details, channels == nil { channels = (try? await client.tv(initial.id)) ?? [] }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .summary:
            if let detail {
                SummaryPanel(detail: detail, match: match) { tab = .stats }
            } else {
                loadingOrFailure
            }
        case .stats:
            if let detail {
                StatsPanel(groups: detail.groups, limit: nil)
            } else {
                loadingOrFailure
            }
        case .details:
            if let detail {
                DetailsPanel(facts: detail.facts, channels: channels)
            } else {
                loadingOrFailure
            }
        case .h2h:
            if let h2h {
                H2HPanel(groups: h2h)
            } else if h2hFailed {
                Notice(text: "Não deu pra carregar os confrontos.")
            } else {
                SkeletonList(rows: 8, rowHeight: 56)
            }
        }
    }

    @ViewBuilder
    private var loadingOrFailure: some View {
        if let failure {
            Notice(text: failure)
        } else {
            SkeletonList(rows: 6, rowHeight: 46)
        }
    }

    private func loadH2H() async {
        do {
            h2h = try await client.h2h(initial.id)
        } catch {
            h2hFailed = true
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            async let status = try? client.status(of: match)
            async let fresh = try? client.detail(initial.id)
            let (updated, loaded) = await (status, fresh)
            withAnimation(.snappy) {
                if let updated { live = updated }
                if let loaded { detail = loaded }
            }
            if detail == nil { failure = "Não deu pra carregar os detalhes deste jogo." }
            let soon = match.phase == .scheduled && match.kickoff.timeIntervalSinceNow < 15 * 60
            guard match.phase.isLive || soon else { return }
            try? await Task.sleep(for: .seconds(30))
        }
    }
}

struct MatchTopBar: View {
    @Environment(LeagueHub.self) private var hub
    let origin: LeagueHub.Origin?
    let back: () -> Void
    @State private var hoveringName = false

    var body: some View {
        PageBar(back: "Voltar", action: back) {
            if let origin {
                competition(origin)
            }
        }
    }

    private func competition(_ origin: LeagueHub.Origin) -> some View {
        Button {
            if let league = origin.league { hub.select(league) }
        } label: {
            HStack(spacing: 10) {
                if origin.logo != nil {
                    CompetitionLogo(url: origin.logo, fallback: origin.country ?? origin.name)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(origin.name)
                        .font(.ui(14, 650))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    if let country = origin.country, !country.isEmpty {
                        Text(country.uppercased())
                            .font(.ui(10.5, 700))
                            .tracking(0.6)
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                }
                if origin.league != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(hoveringName ? Palette.ink : Palette.inkFaint)
                        .padding(.leading, 4)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 14)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(hoveringName ? Palette.raised : .clear))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(hoveringName ? Palette.inkFaint : Palette.rule, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(origin.league == nil)
        .onHover { hoveringName = $0 }
        .pointingHand()
        .help(origin.league == nil ? "" : "Ver tabela e rodadas")
    }
}

struct MatchHero: View {
    let match: Match

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            HeroTeam(team: match.home)
            VStack(spacing: 8) {
                Text(match.kickoff.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute().locale(.ptBR)))
                    .font(.ui(12.5, 600))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSoft)
                HeroScore(match: match)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    HeroStatus(match: match, now: context.date)
                }
            }
            .frame(width: 240)
            .padding(.top, 6)
            HeroTeam(team: match.away)
        }
        .padding(.horizontal, 40)
        .padding(.top, 30)
        .padding(.bottom, 28)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
    }
}

struct HeroTeam: View {
    let team: Team

    var body: some View {
        VStack(spacing: 12) {
            TeamBadge(team: team, size: 52)
                .frame(width: 84, height: 84)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
            Text(team.name)
                .font(.ui(17, 650))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HeroScore: View {
    let match: Match

    var body: some View {
        if match.phase.hasScore, let home = match.homeScore, let away = match.awayScore {
            HStack(spacing: 10) {
                digit(home)
                Text("-")
                    .font(.display(44, weight: 700))
                    .foregroundStyle(match.phase.isLive ? Palette.live : Palette.inkSoft)
                digit(away)
            }
        } else {
            Text(match.kickoff.formatted(.dateTime.hour().minute().locale(.ptBR)))
                .font(.display(44, weight: 780))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
    }

    private func digit(_ value: Int) -> some View {
        Text("\(value)")
            .font(.display(52, weight: 800))
            .monospacedDigit()
            .foregroundStyle(match.phase.isLive ? Palette.live : Palette.ink)
            .contentTransition(.numericText(value: Double(value)))
    }
}

struct HeroStatus: View {
    let match: Match
    let now: Date

    var body: some View {
        switch match.phase {
        case .scheduled:
            Text("Ainda não começou")
                .font(.ui(13, 600))
                .foregroundStyle(Palette.inkSoft)
        case .finished:
            Text("Encerrado")
                .font(.ui(13, 650))
                .foregroundStyle(Palette.inkSoft)
        case .postponed:
            Text("Adiado").font(.ui(13, 650)).foregroundStyle(Palette.europa)
        case .cancelled:
            Text("Cancelado").font(.ui(13, 650)).foregroundStyle(Palette.live)
        case .abandoned:
            Text("Interrompido").font(.ui(13, 650)).foregroundStyle(Palette.live)
        case .halfTime:
            liveText("Intervalo")
        case .extraTime:
            liveText("Prorrogação")
        case .penalties:
            liveText("Pênaltis")
        case .firstHalf, .secondHalf, .live:
            liveText(match.minute(at: now) ?? "Ao vivo")
        }
    }

    private func liveText(_ text: String) -> some View {
        HStack(spacing: 6) {
            LiveDot(size: 6)
            Text(text)
                .font(.ui(14, 700))
                .monospacedDigit()
                .foregroundStyle(Palette.live)
        }
    }
}

struct MatchTabs: View {
    let tabs: [MatchTab]
    let selection: MatchTab
    let pick: (MatchTab) -> Void

    var body: some View {
        HStack(spacing: 28) {
            ForEach(tabs) { item in
                TabLabel(title: item.title, active: item == selection) { pick(item) }
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct TabLabel: View {
    let title: String
    let active: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.band(13, 700))
                .tracking(0.6)
            .foregroundStyle(active || hovering ? Palette.ink : Palette.inkSoft)
            .frame(height: 44)
            .overlay(alignment: .bottom) {
                Rectangle().fill(active ? Palette.ink : .clear).frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct Notice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.ui(13))
            .foregroundStyle(Palette.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
    }
}

struct PeriodBand: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.band(12.5, 700))
                .tracking(0.8)
                .foregroundStyle(Palette.inkSoft)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.ui(12, 700))
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 40)
        .frame(height: 32)
        .background(Palette.raised)
    }
}

struct SummaryPanel: View {
    let detail: MatchDetail
    let match: Match
    let showStats: () -> Void

    var body: some View {
        let periods = detail.periods.filter { !$0.incidents.isEmpty || $0.homeScore != nil }
        VStack(spacing: 0) {
            if periods.isEmpty {
                Notice(text: match.phase == .scheduled ? "Os lances aparecem aqui quando o jogo começar." : "Nenhum lance registrado ainda.")
                    .padding(.bottom, 40)
            }
            ForEach(periods) { period in
                PeriodBand(title: period.title, trailing: period.homeScore.flatMap { home in period.awayScore.map { "\(home) - \($0)" } })
                if period.incidents.isEmpty {
                    Text("Sem lances")
                        .font(.ui(13))
                        .foregroundStyle(Palette.inkFaint)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                ForEach(period.incidents) { incident in
                    IncidentRow(incident: incident)
                }
            }
            if let top = detail.groups.first, !top.stats.isEmpty {
                PeriodBand(title: "Estatísticas")
                VStack(spacing: 18) {
                    ForEach(top.stats.prefix(5)) { StatRow(stat: $0) }
                    Button(action: showStats) {
                        Text("Mostrar mais")
                            .font(.ui(13, 650))
                            .underline()
                            .foregroundStyle(Palette.ink)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 22)
            }
        }
    }
}

struct DetailsPanel: View {
    let facts: [MatchFact]
    let channels: [String]?

    var body: some View {
        VStack(spacing: 0) {
            PeriodBand(title: "Canal de TV")
            Group {
                if let channels {
                    if channels.isEmpty {
                        Text("Nenhuma transmissão informada.")
                            .font(.ui(13))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(channels, id: \.self) { channel in
                                HStack(spacing: 6) {
                                    Image(systemName: "tv")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Palette.inkSoft)
                                    Text(channel)
                                        .font(.ui(13, 600))
                                        .foregroundStyle(Palette.ink)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.rule, lineWidth: 1))
                            }
                            Spacer()
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Skeleton(width: 130, height: 30, radius: 6)
                        Skeleton(width: 160, height: 30, radius: 6)
                        Spacer()
                    }
                }
            }
            .frame(minHeight: 30)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            PeriodBand(title: "Detalhes do jogo")
            if facts.isEmpty {
                Text("Sem detalhes para este jogo.")
                    .font(.ui(13))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            ForEach(facts) { fact in
                HStack(spacing: 12) {
                    Image(systemName: fact.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 22)
                    Text(fact.label)
                        .font(.ui(14, 500))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text(fact.value)
                        .font(.ui(14, 650))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 40)
                .frame(height: 46)
                Hairline()
            }
        }
    }
}

struct IncidentRow: View {
    let incident: Incident

    var body: some View {
        HStack(spacing: 12) {
            if incident.side == .home {
                minute
                IncidentIcon(kind: incident.kind, score: score)
                names(alignment: .leading)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                names(alignment: .trailing)
                IncidentIcon(kind: incident.kind, score: score)
                minute
            }
        }
        .padding(.horizontal, 40)
        .frame(minHeight: 46)
    }

    private var minute: some View {
        Text(incident.minute)
            .font(.ui(13, 700))
            .monospacedDigit()
            .foregroundStyle(Palette.inkSoft)
            .frame(width: 40, alignment: incident.side == .home ? .leading : .trailing)
    }

    private func names(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 6) {
            if alignment == .trailing, let note { noteText(note) }
            Text(title)
                .font(.ui(14, 650))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            if alignment == .leading, let note { noteText(note) }
        }
    }

    private func noteText(_ text: String) -> some View {
        Text("(\(text))")
            .font(.ui(13, 500))
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(1)
    }

    private var score: String? {
        guard incident.kind == .goal || incident.kind == .ownGoal,
              let home = incident.homeScore, let away = incident.awayScore else { return nil }
        return "\(home) - \(away)"
    }

    private var title: String {
        switch incident.kind {
        case .shootoutScored: incident.player.isEmpty ? "Pênalti convertido" : incident.player
        case .shootoutMissed: incident.player.isEmpty ? "Pênalti perdido" : incident.player
        case .substitution: incident.detail ?? incident.player
        default: incident.player
        }
    }

    private var note: String? {
        switch incident.kind {
        case .goal: incident.detail?.replacingOccurrences(of: "Assist.: ", with: "")
        case .ownGoal: "contra"
        case .substitution: incident.detail == nil ? nil : incident.player
        case .penaltyMissed: "pênalti perdido"
        case .yellowCard, .redCard: incident.detail
        case .shootoutScored, .shootoutMissed: nil
        }
    }
}

struct IncidentIcon: View {
    let kind: IncidentKind
    var score: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let score {
                Text(score)
                    .font(.ui(13, 750))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            symbol
        }
        .padding(.horizontal, score == nil ? 0 : 8)
        .frame(minWidth: 30, minHeight: 30)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.rule, lineWidth: 1))
    }

    @ViewBuilder
    private var symbol: some View {
        switch kind {
        case .goal, .shootoutScored:
            Image(systemName: "soccerball")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ink)
        case .ownGoal:
            Image(systemName: "soccerball")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.live)
        case .yellowCard:
            card(Color(red: 0.98, green: 0.80, blue: 0.16))
        case .redCard:
            card(Palette.live)
        case .substitution:
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.pitch)
        case .penaltyMissed, .shootoutMissed:
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.live)
        }
    }

    private func card(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 10, height: 14)
    }
}

struct StatsPanel: View {
    let groups: [StatGroup]
    let limit: Int?

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                Notice(text: "Estatísticas indisponíveis para este jogo.")
            }
            ForEach(groups) { group in
                PeriodBand(title: group.title)
                VStack(spacing: 18) {
                    ForEach(group.stats) { StatRow(stat: $0) }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 22)
            }
        }
    }
}

struct StatRow: View {
    let stat: MatchStat

    var body: some View {
        let share = stat.homeShare
        VStack(spacing: 7) {
            HStack {
                Text(stat.home)
                    .font(.ui(14, 700))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(stat.name)
                    .font(.ui(13, 620))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(stat.away)
                    .font(.ui(14, 700))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            if let share {
                HStack(spacing: 4) {
                    bar(fill: share, leading: false, lead: share > 0.5)
                    bar(fill: 1 - share, leading: true, lead: share < 0.5)
                }
                .frame(height: 8)
            }
        }
    }

    private func bar(fill: Double, leading: Bool, lead: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: leading ? .leading : .trailing) {
                Capsule().fill(Palette.raised)
                Capsule()
                    .fill(lead ? Palette.pitch : Palette.inkSoft)
                    .frame(width: max(0, proxy.size.width * fill))
            }
        }
    }
}

struct H2HPanel: View {
    let groups: [H2HGroup]

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty {
                Notice(text: "Nenhum confronto encontrado.")
            }
            ForEach(groups) { group in
                PeriodBand(title: group.title)
                ForEach(group.rows.prefix(10)) { row in
                    H2HLine(row: row)
                    Hairline()
                }
            }
        }
    }
}

struct H2HLine: View {
    let row: H2HRow

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits).locale(.ptBR)))
                    .font(.ui(12, 650))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(row.competition)
                    .font(.ui(10.5, 550))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                team(row.home, logo: row.homeLogo)
                team(row.away, logo: row.awayLogo)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                score(row.homeScore)
                score(row.awayScore)
            }
            badge
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 9)
    }

    private func team(_ name: String, logo: URL?) -> some View {
        HStack(spacing: 10) {
            TeamLogo(url: logo, size: 17)
            Text(name)
                .font(.ui(14, 500))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
        }
        .frame(height: 19)
    }

    private func score(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "-")
            .font(.display(15, weight: 740))
            .monospacedDigit()
            .foregroundStyle(Palette.ink)
            .frame(height: 19)
    }

    @ViewBuilder
    private var badge: some View {
        if let outcome = row.outcome {
            let letter = switch outcome {
            case .win: "V"
            case .draw: "E"
            case .loss: "D"
            }
            Text(letter)
                .font(.ui(12, 800))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.outcome(outcome)))
        } else {
            Color.clear.frame(width: 24, height: 24)
        }
    }
}

struct BackButton: View {
    var title = "Voltar"
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.ui(13.5, 650))
            }
            .foregroundStyle(hovering ? Palette.ink : Palette.inkSoft)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(hovering ? Palette.raised : .clear))
            .overlay(Capsule().strokeBorder(hovering ? Palette.inkFaint : Palette.rule, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct PageBar<Trailing: View>: View {
    let back: String
    let action: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                BackButton(title: back, action: action)
                    .keyboardShortcut(.cancelAction)
                Spacer(minLength: 20)
                trailing
            }
            .padding(.horizontal, 40)
            .frame(height: 56)
            .windowDraggable()
            Hairline()
        }
    }
}

extension PageBar where Trailing == EmptyView {
    init(back: String, action: @escaping () -> Void) {
        self.init(back: back, action: action) { EmptyView() }
    }
}

struct StarButton: View {
    let on: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? Palette.gold : (hovering ? Palette.ink : Palette.inkSoft))
                .frame(width: 34, height: 34)
                .background(Circle().fill(hovering ? Palette.raised : .clear))
                .overlay(Circle().strokeBorder(on ? Palette.gold.opacity(0.5) : (hovering ? Palette.inkFaint : Palette.rule), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
        .help(on ? "Remover dos favoritos" : "Adicionar aos favoritos")
    }
}

struct PillLink: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.ui(13, 650))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(hovering ? Palette.ink : Palette.inkSoft)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Capsule().fill(hovering ? Palette.raised : .clear))
            .overlay(Capsule().strokeBorder(hovering ? Palette.inkFaint : Palette.rule, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}
