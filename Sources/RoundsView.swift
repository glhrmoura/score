import SwiftUI

struct RoundsView: View {
    @Environment(LeagueStore.self) private var store

    var body: some View {
        let stages = store.stages
        let key = store.shownStage ?? stages.first?.key ?? ""
        VStack(spacing: 0) {
            if stages.count > 1 {
                StageStrip(stages: stages, shown: key)
                Hairline()
            }
            ScrollView {
                let days = Self.days(store.matches(in: key))
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if days.isEmpty {
                        Text("Sem jogos nesta fase ainda.")
                            .font(.ui(14))
                            .foregroundStyle(Palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                    ForEach(days, id: \.day) { group in
                        Section {
                            CromoGrid(matches: group.matches, origin: LeagueHub.Origin(name: store.league.name, league: store.league, tournament: nil))
                        } header: {
                            SectionBand(
                                text: (Calendar.current.isDateInToday(group.day) ? "Hoje · " : "") + group.day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(.ptBR)),
                                color: Calendar.current.isDateInToday(group.day) ? Palette.primaryInk : Palette.inkSoft
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .id(key)
        }
    }

    private static func days(_ matches: [Match]) -> [(day: Date, matches: [Match])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: matches) { calendar.startOfDay(for: $0.kickoff) }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }
}

struct StageStrip: View {
    @Environment(LeagueStore.self) private var store
    let stages: [Stage]
    let shown: String
    @State private var hovering = false
    @State private var open = false

    var body: some View {
        let index = stages.firstIndex { $0.key == shown } ?? 0
        let stage = stages[index]
        let allRounds = stages.allSatisfy { $0.round != nil }
        HStack(spacing: 10) {
            Spacer()
            StepButton(symbol: "chevron.left", enabled: index > 0) { select(stages[index - 1].key) }
            Button {
                open.toggle()
            } label: {
                HStack(spacing: 8) {
                    if stage.key == store.currentStage {
                        Circle().fill(Palette.primary).frame(width: 6, height: 6)
                    }
                    Text(stage.title)
                        .font(.ui(14, 700))
                        .foregroundStyle(Palette.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.inkSoft)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Capsule().fill(hovering || open ? Palette.raised : .clear))
                .overlay(Capsule().strokeBorder(hovering || open ? Palette.inkFaint : Palette.rule, lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .pointingHand()
            .popover(isPresented: $open, arrowEdge: .bottom) {
                StagePicker(stages: stages, shown: shown, current: store.currentStage, allRounds: allRounds) { key in
                    select(key)
                    open = false
                }
            }
            StepButton(symbol: "chevron.right", enabled: index < stages.count - 1) { select(stages[index + 1].key) }
        }
        .padding(.horizontal, 40)
        .frame(height: 56)
    }

    private func select(_ key: String) {
        withAnimation(.snappy) {
            store.selectedStage = key == store.currentStage ? nil : key
        }
    }
}

struct StagePicker: View {
    let stages: [Stage]
    let shown: String
    let current: String?
    let allRounds: Bool
    let pick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(allRounds ? "RODADAS" : "FASES")
                .font(.band(11, 700))
                .tracking(0.8)
                .foregroundStyle(Palette.inkSoft)
            if allRounds {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 6), spacing: 6) {
                    ForEach(stages) { stage in
                        PickerCell(label: "\(stage.round ?? 0)", selected: stage.key == shown, current: stage.key == current, width: 40) {
                            pick(stage.key)
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(stages) { stage in
                            PickerCell(label: stage.title, selected: stage.key == shown, current: stage.key == current, width: nil) {
                                pick(stage.key)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .frame(width: allRounds ? 300 : 260, alignment: .leading)
        .background(Palette.surface)
    }
}

struct PickerCell: View {
    let label: String
    let selected: Bool
    let current: Bool
    let width: CGFloat?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.ui(13.5, selected ? 750 : 600))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(selected ? (current ? Palette.onPrimary : Palette.canvas) : (current ? Palette.primaryInk : Palette.ink))
                .padding(.horizontal, width == nil ? 12 : 0)
                .frame(width: width, height: 34, alignment: width == nil ? .leading : .center)
                .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? (current ? Palette.primary : Palette.ink) : (hovering ? Palette.raised : .clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(current && !selected ? Palette.primary.opacity(0.6) : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct StepButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 30, height: 30)
                .background(Circle().fill(hovering ? Palette.raised : .clear))
                .overlay(Circle().strokeBorder(Palette.rule, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct StatusCell: View {
    let match: Match
    let now: Date

    var body: some View {
        switch match.phase {
        case .scheduled:
            Text(match.kickoff.formatted(.dateTime.hour().minute().locale(.ptBR)))
                .font(.ui(14, 600))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        case .finished:
            label("Fim", Palette.inkFaint)
        case .postponed:
            label("Adiado", Palette.europa)
        case .cancelled:
            label("Cancelado", Palette.live)
        case .abandoned:
            label("Interrompido", Palette.live)
        case .halfTime:
            liveLabel("Intervalo")
        case .extraTime:
            liveLabel("Prorrog.")
        case .penalties:
            liveLabel("Pênaltis")
        case .firstHalf, .secondHalf, .live:
            liveLabel(match.minute(at: now) ?? "Ao vivo")
        }
    }

    private func label(_ text: String, _ color: Color) -> some View {
        Text(text.uppercased())
            .font(.ui(11, 650))
            .tracking(0.8)
            .foregroundStyle(color)
    }

    private func liveLabel(_ text: String) -> some View {
        HStack(spacing: 7) {
            LiveDot(size: 6)
            Text(text)
                .font(.ui(13, 700))
                .monospacedDigit()
                .foregroundStyle(Palette.primaryInk)
        }
    }
}

struct TeamBadge: View {
    let team: Team
    var size: CGFloat = 22

    var body: some View {
        AsyncImage(url: team.logo, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high).scaledToFit()
            } else {
                Circle()
                    .fill(Palette.raised)
                    .overlay(
                        Text(team.short.prefix(3))
                            .font(.ui(size * 0.3, 700))
                            .foregroundStyle(Palette.inkSoft)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}
