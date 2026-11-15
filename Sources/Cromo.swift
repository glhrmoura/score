import SwiftUI

struct CromoGrid: View {
    let matches: [Match]
    var origin: LeagueHub.Origin?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(matches) { match in
                MatchLine(match: match, origin: origin)
                Hairline()
            }
        }
    }
}

struct MatchLine: View {
    @Environment(LeagueHub.self) private var hub
    let match: Match
    var origin: LeagueHub.Origin?
    var leading: CGFloat = 52
    @State private var hovering = false

    var body: some View {
        Button {
            hub.open(match, origin: origin)
        } label: {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        line(match.home)
                        line(match.away)
                    }
                    Spacer(minLength: 12)
                    status(at: context.date)
                    VStack(alignment: .trailing, spacing: 5) {
                        score(match.homeScore, team: match.home)
                        score(match.awayScore, team: match.away)
                    }
                    .frame(minWidth: 22, alignment: .trailing)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.inkFaint)
                        .opacity(hovering ? 1 : 0)
                }
                .padding(.leading, leading)
                .padding(.trailing, 40)
                .padding(.vertical, 9)
                .background(background)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }

    @ViewBuilder
    private var background: some View {
        if match.phase.isLive {
            Palette.primary.opacity(hovering ? 0.18 : 0.09)
        } else if hovering {
            Palette.raised.opacity(0.6)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func status(at now: Date) -> some View {
        switch match.phase {
        case .scheduled:
            Text(match.kickoff.formatted(.dateTime.hour().minute().locale(.ptBR)))
                .font(.ui(13, 650))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
        case .finished:
            tag("Encerrado", Palette.inkFaint)
        case .postponed:
            tag("Adiado", Palette.europa)
        case .cancelled:
            tag("Cancelado", Palette.live)
        case .abandoned:
            tag("Interrompido", Palette.live)
        case .halfTime:
            liveTag("Intervalo")
        case .extraTime:
            liveTag("Prorrog.")
        case .penalties:
            liveTag("Pênaltis")
        case .firstHalf, .secondHalf, .live:
            liveTag(match.minute(at: now) ?? "Ao vivo")
        }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.ui(11.5, 600))
            .foregroundStyle(color)
    }

    private func liveTag(_ text: String) -> some View {
        HStack(spacing: 6) {
            LiveDot(size: 6)
            Text(text)
                .font(.ui(12.5, 700))
                .monospacedDigit()
                .foregroundStyle(Palette.primaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func lost(_ team: Team) -> Bool {
        match.phase == .finished && match.winner != nil && match.winner?.id != team.id
    }

    private func line(_ team: Team) -> some View {
        HStack(spacing: 10) {
            TeamBadge(team: team, size: 17)
            Text(team.name)
                .font(.ui(14, lost(team) ? 400 : 500))
                .foregroundStyle(lost(team) ? Palette.inkSoft : Palette.ink)
                .lineLimit(1)
        }
        .frame(height: 19)
    }

    @ViewBuilder
    private func score(_ value: Int?, team: Team) -> some View {
        if match.phase.hasScore, let value {
            Text("\(value)")
                .font(.display(15, weight: lost(team) ? 500 : 750))
                .monospacedDigit()
                .foregroundStyle(match.phase.isLive ? Palette.primaryInk : (lost(team) ? Palette.inkSoft : Palette.ink))
                .contentTransition(.numericText(value: Double(value)))
                .frame(height: 19)
        } else {
            Text("–")
                .font(.display(15, weight: 500))
                .foregroundStyle(Palette.inkFaint)
                .frame(height: 19)
        }
    }
}
