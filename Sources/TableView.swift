import SwiftUI

private enum Column {
    static let position: CGFloat = 34
    static let stat: CGFloat = 34
    static let goals: CGFloat = 60
    static let points: CGFloat = 46
    static let form: CGFloat = 104
}

struct TableView: View {
    @Environment(LeagueStore.self) private var store

    var body: some View {
        let tables = store.tables
        let rules = tables.count == 1 ? store.league.zones : []
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(tables) { table in
                    VStack(alignment: .leading, spacing: 10) {
                        if tables.count > 1, let title = table.title {
                            SectionTitle(text: StageName.describe(title).title)
                                .padding(.leading, 4)
                        }
                        Card {
                            VStack(spacing: 0) {
                                TableHeader()
                                Hairline()
                                ForEach(Array(table.rows.enumerated()), id: \.element.id) { index, row in
                                    if index > 0 { Hairline().padding(.leading, 18) }
                                    TableRow(
                                        position: index + 1,
                                        zone: ZoneRule.kind(for: index + 1, total: table.rows.count, in: rules),
                                        row: row
                                    )
                                }
                            }
                        }
                    }
                }
                Legend(kinds: rules.map(\.kind))
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 26)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct TableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            Eyebrow(text: "#").frame(width: Column.position, alignment: .center)
            Eyebrow(text: "Time").frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
            ForEach(["J", "V", "E", "D"], id: \.self) { title in
                Eyebrow(text: title).frame(width: Column.stat)
            }
            Eyebrow(text: "Gols").frame(width: Column.goals)
            Eyebrow(text: "SG").frame(width: Column.stat)
            Eyebrow(text: "Pts").frame(width: Column.points)
            Eyebrow(text: "Últimos 5").frame(width: Column.form, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: 40)
    }
}

private struct TableRow: View {
    let position: Int
    let zone: ZoneKind?
    let row: StandingRow
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 0) {
            Text("\(position)")
                .font(.ui(13, 700))
                .monospacedDigit()
                .foregroundStyle(zone.map(Palette.zone) ?? Palette.inkSoft)
                .frame(width: Column.position)
            HStack(spacing: 12) {
                TeamBadge(team: row.team, size: 24)
                Text(row.team.name)
                    .font(.ui(14, 600))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            stat(row.played)
            stat(row.won)
            stat(row.drawn)
            stat(row.lost)
            Text("\(row.goalsFor):\(row.goalsAgainst)")
                .font(.ui(13, 450))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
                .frame(width: Column.goals)
            Text(row.goalDifference > 0 ? "+\(row.goalDifference)" : "\(row.goalDifference)")
                .font(.ui(13, 500))
                .monospacedDigit()
                .foregroundStyle(Palette.inkSoft)
                .frame(width: Column.stat)
            Text("\(row.points)")
                .font(.display(17, weight: 760))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .frame(width: Column.points)
            FormStrip(form: row.form)
                .frame(width: Column.form, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                if hovering { Palette.raised.opacity(0.5) }
                if let zone {
                    Rectangle().fill(Palette.zone(zone)).frame(width: 3)
                }
            }
        }
        .onHover { hovering = $0 }
    }

    private func stat(_ value: Int) -> some View {
        Text("\(value)")
            .font(.ui(13, 450))
            .monospacedDigit()
            .foregroundStyle(Palette.inkSoft)
            .frame(width: Column.stat)
    }
}

private struct FormStrip: View {
    let form: [Outcome]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(form.enumerated()), id: \.offset) { _, outcome in
                Text(letter(outcome))
                    .font(.ui(10, 750))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.outcome(outcome)))
            }
        }
    }

    private func letter(_ outcome: Outcome) -> String {
        switch outcome {
        case .win: "V"
        case .draw: "E"
        case .loss: "D"
        }
    }
}

private struct Legend: View {
    let kinds: [ZoneKind]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(kinds.enumerated()), id: \.offset) { _, kind in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2).fill(Palette.zone(kind)).frame(width: 10, height: 10)
                    Text(kind.title)
                        .font(.ui(12, 500))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer()
            Text("Calculada a partir dos resultados")
                .font(.ui(12, 450))
                .foregroundStyle(Palette.inkFaint)
        }
    }
}
