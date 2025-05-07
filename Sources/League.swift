import Foundation

struct League: Hashable, Identifiable, Codable, Sendable {
    let path: String
    let name: String
    let country: String
    var site: String? = nil

    static let brazilSite = "br"

    var id: String { site.map { "\($0):\(path)" } ?? path }

    var page: URL {
        if site == Self.brazilSite {
            return URL(string: "https://www.flashscore.com.br/futebol/\(path)/")!
        }
        return URL(string: "https://www.flashscore.com/football/\(path)/")!
    }

    var zones: [ZoneRule] {
        ZoneRule.rules[path] ?? []
    }

    static let featured: [League] = [
        League(path: "brazil/serie-a", name: "Brasileirão Série A", country: "Brasil"),
        League(path: "brazil/serie-b", name: "Brasileirão Série B", country: "Brasil"),
        League(path: "brazil/copa-do-brasil", name: "Copa do Brasil", country: "Brasil"),
        League(path: "south-america/copa-libertadores", name: "Copa Libertadores", country: "América do Sul"),
        League(path: "south-america/copa-sudamericana", name: "Copa Sul-Americana", country: "América do Sul"),
        League(path: "europe/champions-league", name: "Champions League", country: "Europa"),
        League(path: "europe/europa-league", name: "Europa League", country: "Europa"),
        League(path: "europe/conference-league", name: "Conference League", country: "Europa"),
        League(path: "england/premier-league", name: "Premier League", country: "Inglaterra"),
        League(path: "spain/laliga", name: "LaLiga", country: "Espanha"),
        League(path: "italy/serie-a", name: "Serie A", country: "Itália"),
        League(path: "germany/bundesliga", name: "Bundesliga", country: "Alemanha"),
        League(path: "france/ligue-1", name: "Ligue 1", country: "França"),
        League(path: "portugal/liga-portugal", name: "Liga Portugal", country: "Portugal"),
        League(path: "netherlands/eredivisie", name: "Eredivisie", country: "Holanda"),
        League(path: "argentina/liga-profesional", name: "Liga Profesional", country: "Argentina"),
        League(path: "usa/mls", name: "MLS", country: "Estados Unidos"),
        League(path: "saudi-arabia/saudi-professional-league", name: "Saudi Pro League", country: "Arábia Saudita"),
    ]

    static let fallback = featured[0]
}

enum ZoneKind: Hashable, Sendable {
    case libertadores
    case libertadoresQualifying
    case sudamericana
    case champions
    case europa
    case conference
    case relegationPlayoff
    case relegation

    var title: String {
        switch self {
        case .libertadores: "Libertadores"
        case .libertadoresQualifying: "Pré-Libertadores"
        case .sudamericana: "Sul-Americana"
        case .champions: "Champions League"
        case .europa: "Europa League"
        case .conference: "Conference League"
        case .relegationPlayoff: "Playoff de rebaixamento"
        case .relegation: "Rebaixamento"
        }
    }
}

struct ZoneRule: Hashable, Sendable {
    let kind: ZoneKind
    let from: Int
    let to: Int

    static func kind(for position: Int, total: Int, in rules: [ZoneRule]) -> ZoneKind? {
        rules.first { rule in
            let from = rule.from > 0 ? rule.from : total + rule.from + 1
            let to = rule.to > 0 ? rule.to : total + rule.to + 1
            return (from...to).contains(position)
        }?.kind
    }

    private static let europeanTop: [ZoneRule] = [
        ZoneRule(kind: .champions, from: 1, to: 4),
        ZoneRule(kind: .europa, from: 5, to: 5),
        ZoneRule(kind: .conference, from: 6, to: 6),
        ZoneRule(kind: .relegation, from: -3, to: -1),
    ]

    private static let germanStyle: [ZoneRule] = [
        ZoneRule(kind: .champions, from: 1, to: 4),
        ZoneRule(kind: .europa, from: 5, to: 5),
        ZoneRule(kind: .conference, from: 6, to: 6),
        ZoneRule(kind: .relegationPlayoff, from: -3, to: -3),
        ZoneRule(kind: .relegation, from: -2, to: -1),
    ]

    static let rules: [String: [ZoneRule]] = [
        "brazil/serie-a": [
            ZoneRule(kind: .libertadores, from: 1, to: 4),
            ZoneRule(kind: .libertadoresQualifying, from: 5, to: 6),
            ZoneRule(kind: .sudamericana, from: 7, to: 12),
            ZoneRule(kind: .relegation, from: -4, to: -1),
        ],
        "england/premier-league": europeanTop,
        "spain/laliga": europeanTop,
        "italy/serie-a": europeanTop,
        "germany/bundesliga": germanStyle,
        "france/ligue-1": germanStyle,
    ]
}

struct Country: Hashable, Identifiable, Codable, Sendable {
    let slug: String
    let english: String

    var id: String { slug }

    static let regionSlugs: [String] = [
        "world", "europe", "south-america", "north-central-america", "africa", "asia", "australia-oceania",
    ]

    var regionSymbol: String {
        switch slug {
        case "south-america", "north-central-america": "globe.americas.fill"
        case "africa": "globe.europe.africa.fill"
        case "asia", "australia-oceania": "globe.asia.australia.fill"
        default: "globe"
        }
    }

    var isRegion: Bool {
        Self.regionSlugs.contains(slug)
    }

    var flag: URL? {
        if slug == "world" { return URL(string: "https://flagcdn.com/w80/un.png") }
        if slug == "europe" { return URL(string: "https://flagcdn.com/w80/eu.png") }
        guard !isRegion else { return nil }
        let special: [String: String] = [
            "england": "gb-eng", "scotland": "gb-sct", "wales": "gb-wls", "northern-ireland": "gb-nir",
            "kosovo": "xk",
        ]
        guard let code = special[slug] ?? Self.isoCodes[english.lowercased()] ?? Self.isoCodes[slug.replacingOccurrences(of: "-", with: " ")] else { return nil }
        return URL(string: "https://flagcdn.com/w80/\(code.lowercased()).png")
    }

    private static let isoCodes: [String: String] = {
        let english = Locale(identifier: "en_US")
        var map: [String: String] = [:]
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard code.count == 2, let name = english.localizedString(forRegionCode: code) else { continue }
            map[name.lowercased()] = code
        }
        map["usa"] = "US"
        map["south korea"] = "KR"
        map["north korea"] = "KP"
        map["czech republic"] = "CZ"
        map["bosnia and herzegovina"] = "BA"
        map["dr congo"] = "CD"
        map["ivory coast"] = "CI"
        map["turkey"] = "TR"
        map["russia"] = "RU"
        map["faroe islands"] = "FO"
        map["hong kong"] = "HK"
        map["macao"] = "MO"
        map["palestine"] = "PS"
        map["curacao"] = "CW"
        map["cape verde"] = "CV"
        map["eswatini"] = "SZ"
        map["myanmar"] = "MM"
        map["north macedonia"] = "MK"
        map["moldova"] = "MD"
        map["vietnam"] = "VN"
        map["syria"] = "SY"
        map["iran"] = "IR"
        map["chinese taipei"] = "TW"
        return map
    }()

    var name: String {
        if let region = Self.regions[slug] { return region }
        return Self.portuguese[english.lowercased()] ?? english
    }

    private static let regions: [String: String] = [
        "world": "Mundo",
        "europe": "Europa",
        "south-america": "América do Sul",
        "north-central-america": "América do Norte e Central",
        "africa": "África",
        "asia": "Ásia",
        "australia-oceania": "Oceania",
    ]

    private static let portuguese: [String: String] = {
        let english = Locale(identifier: "en_US")
        let target = Locale(identifier: "pt_BR")
        var map: [String: String] = [:]
        for region in Locale.Region.isoRegions {
            let code = region.identifier
            guard
                let from = english.localizedString(forRegionCode: code),
                let to = target.localizedString(forRegionCode: code)
            else { continue }
            map[from.lowercased()] = to
        }
        map["england"] = "Inglaterra"
        map["scotland"] = "Escócia"
        map["wales"] = "País de Gales"
        map["northern ireland"] = "Irlanda do Norte"
        map["usa"] = "Estados Unidos"
        map["south korea"] = "Coreia do Sul"
        map["north korea"] = "Coreia do Norte"
        map["czech republic"] = "República Tcheca"
        map["bosnia and herzegovina"] = "Bósnia e Herzegovina"
        map["dr congo"] = "RD Congo"
        map["ivory coast"] = "Costa do Marfim"
        map["faroe islands"] = "Ilhas Faroé"
        map["kosovo"] = "Kosovo"
        map["turkey"] = "Turquia"
        return map
    }()
}
