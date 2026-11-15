import AppKit
import SwiftUI

enum LeagueSection: String, CaseIterable, Identifiable {
    case rounds
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rounds: "Jogos"
        case .table: "Classificação"
        }
    }
}

struct ContentView: View {
    @Environment(LeagueHub.self) private var hub
    @State private var section: LeagueSection = .rounds

    var body: some View {
        HStack(spacing: 0) {
            Spine()
            ZStack {
                Group {
                    switch hub.screen {
                    case .today:
                        if let id = hub.competition {
                            CompetitionDayPage(id: id)
                        } else {
                            TodayScreen()
                        }
                    case .live:
                        LiveScreen()
                    case .leagues:
                        LeaguesScreen()
                    case .search:
                        SearchScreen()
                    case .league:
                        LeagueScreen(section: $section)
                            .environment(hub.current)
                            .id(hub.selected.id)
                    }
                }
                .opacity(hub.opened == nil ? 1 : 0)
                .allowsHitTesting(hub.opened == nil)

                if let opened = hub.opened {
                    MatchPage(initial: opened.match, origin: opened.origin)
                        .id(opened.match.id)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.3), value: hub.opened?.match.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.canvas)
            .ignoresSafeArea(.container, edges: .top)
        }
        .background(Palette.canvas)
        .task { hub.start() }
    }
}

struct Spine: View {
    @Environment(LeagueHub.self) private var hub

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 56, height: 56)
                .padding(.bottom, 12)
                .help("Score")
            SpineItem(title: "Hoje", symbol: "calendar", active: hub.screen == .today, badge: nil) { hub.show(.today) }
            SpineItem(title: "Ao vivo", symbol: "dot.radiowaves.left.and.right", active: hub.screen == .live, badge: hub.today.liveCount) { hub.show(.live) }
            SpineItem(title: "Ligas", symbol: "trophy", active: hub.screen == .leagues || hub.screen == .league, badge: nil) { hub.showLeagues() }
            SpineItem(title: "Buscar", symbol: "magnifyingglass", active: hub.screen == .search, badge: nil) { hub.showSearch() }
            Spacer()
        }
        .padding(.top, 42)
        .frame(width: 92)
        .frame(maxHeight: .infinity)
        .windowDraggable()
        .background(Palette.spine)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct SpineItem: View {
    let title: String
    let symbol: String
    let active: Bool
    let badge: Int?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 24)
                    .foregroundStyle(active ? Palette.onPrimary : Palette.spineInk.opacity(hovering ? 1 : 0.72))
                Text(title)
                    .font(.ui(11, active ? 750 : 600))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(active ? Palette.onPrimary : Palette.spineInk.opacity(hovering ? 1 : 0.72))
            }
            .frame(width: 72, height: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? Palette.primary : Palette.spineInk.opacity(hovering ? 0.1 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .pointingHand()
    }
}

struct LeagueScreen: View {
    @Environment(LeagueStore.self) private var store
    @Binding var section: LeagueSection

    @Environment(LeagueHub.self) private var hub

    var body: some View {
        let hasTables = !store.tables.isEmpty
        let active = hasTables ? section : .rounds
        VStack(spacing: 0) {
            PageBar(back: hub.backTitle, action: { hub.goBack() }) {
                StarButton(on: hub.isFavorite(store.league)) {
                    withAnimation(.snappy) { hub.toggleFavorite(store.league) }
                }
            }
            Header(section: $section, hasTables: hasTables)
            Hairline()
            Group {
                switch store.load {
                case .idle, .loading:
                    LoadingState()
                case .failed(let message):
                    FailureState(message: message) { store.reload() }
                case .ready:
                    if store.matches.isEmpty {
                        EmptyLeague()
                    } else {
                        switch active {
                        case .rounds: RoundsView()
                        case .table: TableView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct Header: View {
    @Environment(LeagueStore.self) private var store
    @Environment(LeagueHub.self) private var hub
    @Binding var section: LeagueSection
    let hasTables: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 14) {
                    Text(store.league.name)
                        .font(.display(28, weight: 780))
                        .tracking(-0.5)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(store.league.country)
                    .font(.ui(14, 550))
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 12) {
                SectionPicker(selection: $section)
                    .opacity(hasTables ? 1 : 0)
                    .allowsHitTesting(hasTables)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }
}

struct FavoriteButton: View {
    @Environment(LeagueHub.self) private var hub
    let league: League
    var size: CGFloat = 12

    var body: some View {
        let on = hub.isFavorite(league)
        Button {
            withAnimation(.snappy) { hub.toggleFavorite(league) }
        } label: {
            Image(systemName: on ? "star.fill" : "star")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(on ? Palette.gold : Palette.inkFaint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(on ? "Remover dos favoritos" : "Adicionar aos favoritos")
        .pointingHand()
    }
}

struct SectionPicker: View {
    @Binding var selection: LeagueSection
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LeagueSection.allCases) { item in
                let active = item == selection
                Button {
                    withAnimation(.snappy(duration: 0.28)) { selection = item }
                } label: {
                    Text(item.title)
                        .font(.ui(13, 600))
                        .foregroundStyle(active ? Palette.canvas : Palette.inkSoft)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background {
                            if active {
                                Capsule().fill(Palette.ink).matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .pointingHand()
            }
        }
        .padding(3)
        .background(Capsule().fill(Palette.raised))
    }
}

struct LoadingState: View {
    var body: some View {
        SkeletonList(rows: 10)
    }
}

struct EmptyLeague: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Nenhum jogo nesta temporada")
                .font(.display(20, weight: 700))
                .foregroundStyle(Palette.ink)
            Text("O campeonato ainda não tem jogos marcados ou já terminou.")
                .font(.ui(13))
                .foregroundStyle(Palette.inkSoft)
        }
    }
}

struct FailureState: View {
    @Environment(LeagueStore.self) private var store
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Não deu pra carregar \(store.league.name)")
                .font(.display(22, weight: 700))
                .foregroundStyle(Palette.ink)
            Text(message)
                .font(.ui(13))
                .foregroundStyle(Palette.inkSoft)
            Button("Tentar de novo", action: retry)
                .buttonStyle(.plain)
                .font(.ui(13, 600))
                .foregroundStyle(Palette.surface)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(Capsule().fill(Palette.ink))
                .pointingHand()
        }
    }
}

extension Locale {
    static let ptBR = Locale(identifier: "pt_BR")
}
