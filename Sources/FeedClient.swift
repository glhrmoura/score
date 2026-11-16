import Foundation

enum FeedError: LocalizedError {
    case badResponse(Int)
    case notFound

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): "O servidor respondeu com status \(code)."
        case .notFound: "Não encontrei os dados deste campeonato."
        }
    }
}

struct LeagueConfig: Hashable, Sendable {
    static let defaultSign = "SW9D1eZo"
    var sign = defaultSign
    var country: String
    var tournament: String
    var season: String
}

enum Feed {
    static func rows(_ text: String) -> [[String: String]] {
        text.split(separator: "~").map { row in
            var fields: [String: String] = [:]
            for pair in row.split(separator: "¬") {
                let parts = pair.split(separator: "÷", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else { continue }
                fields[String(parts[0])] = String(parts[1])
            }
            return fields
        }
    }

    static func matches(in text: String, tournament: String) -> [Match] {
        var inside = false
        var section = ""
        var sectionTitle: String?
        var result: [Match] = []
        for fields in rows(text) {
            if let header = fields["ZA"] {
                inside = fields["ZEE"] == tournament
                section = fields["ZC"] ?? header
                sectionTitle = title(of: header)
                continue
            }
            guard inside, fields["AA"] != nil,
                  let match = Match(fields: fields, section: section, sectionTitle: sectionTitle)
            else { continue }
            result.append(match)
        }
        return result
    }

    private static func title(of header: String) -> String? {
        let name = header.split(separator: ":", maxSplits: 1).last.map(String.init) ?? header
        let parts = name.components(separatedBy: " - ")
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: " · ").trimmingCharacters(in: .whitespaces)
    }
}

struct FeedClient: Sendable {
    private static let feedBase = "https://2.flashscore.ninja/2/x/feed/"
    private static let brazilBase = "https://401.flashscore.ninja/401/x/feed/"
    private static let agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
    private static let maxPages = 6

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": agent,
            "Referer": "https://www.flashscore.com/",
            "Accept-Language": "en-US,en;q=0.9",
        ]
        return URLSession(configuration: configuration)
    }()

    func html(_ url: URL) async throws -> String {
        try await text(URLRequest(url: url))
    }

    func discover(_ league: League) async throws -> LeagueConfig {
        let page = try await html(league.page)
        guard
            let tournament = Self.match(#"tournament_id\s*[:=]\s*"([^"]+)""#, in: page),
            let country = Self.match(#"country_id\s*[:=]\s*(\d+)"#, in: page),
            let season = Self.match(#"seasonId\s*[:=]\s*(\d+)"#, in: page)
        else { throw FeedError.notFound }
        let sign = Self.match(#"feed_sign"\s*:\s*"([^"]+)""#, in: page) ?? "SW9D1eZo"
        return LeagueConfig(sign: sign, country: country, tournament: tournament, season: season)
    }

    func season(_ config: LeagueConfig) async throws -> [Match] {
        async let results = pages(prefix: "tr", config: config)
        async let fixtures = pages(prefix: "tf", config: config)
        return try await fixtures + results
    }

    func today(_ config: LeagueConfig) async throws -> [Match] {
        let body: String
        do {
            body = try await feed("f_1_0_1_en_1", sign: config.sign)
        } catch {
            body = try await feed("f_1_0_3_en_1", sign: config.sign)
        }
        return Feed.matches(in: body, tournament: config.tournament)
    }

    func day(offset: Int) async throws -> [Competition] {
        let zone = TimeZone.current.secondsFromGMT() / 3600
        var request = URLRequest(url: URL(string: "\(Self.brazilBase)f_1_\(offset)_\(zone)_pt-br_1")!)
        request.setValue(LeagueConfig.defaultSign, forHTTPHeaderField: "x-fsign")
        request.setValue("https://www.flashscore.com.br/", forHTTPHeaderField: "Referer")
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now)) else {
            return DayFeed.competitions(in: try await text(request))
        }
        return DayFeed.competitions(in: try await text(request)).compactMap { competition in
            var competition = competition
            competition.matches = competition.matches.filter {
                $0.phase.isLive || calendar.isDate($0.kickoff, inSameDayAs: target)
            }
            return competition.matches.isEmpty ? nil : competition
        }
    }

    func searchTeams(_ query: String) async throws -> [TeamHit] {
        var components = URLComponents(string: "https://s.livesport.services/api/v2/search/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "lang-id", value: "31"),
            URLQueryItem(name: "type-ids", value: "2"),
            URLQueryItem(name: "project-id", value: "401"),
            URLQueryItem(name: "project-type-id", value: "1"),
            URLQueryItem(name: "sport-ids", value: "1"),
        ]
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.badResponse(http.statusCode)
        }
        let raw = try JSONDecoder().decode([TeamHit.Raw].self, from: data)
        return raw.compactMap(TeamHit.init)
    }

    func searchCompetitions(_ query: String) async throws -> [League] {
        async let local = searchRaw(query, language: "31", types: "1")
        async let english = searchRaw(query, language: "1", types: "1")
        let (portuguese, reference) = try await (local, english)
        let slugs = Dictionary(reference.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return portuguese.compactMap { hit in
            guard hit.sport?.id == 1, let reference = slugs[hit.id], let slug = reference.url, let country = reference.defaultCountry?.name else { return nil }
            let countrySlug = country
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
                .lowercased()
                .replacingOccurrences(of: "&", with: " ")
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .joined(separator: "-")
            return League(path: "\(countrySlug)/\(slug)", name: hit.name, country: hit.defaultCountry?.name ?? country)
        }
    }

    private func searchRaw(_ query: String, language: String, types: String) async throws -> [TeamHit.Raw] {
        var components = URLComponents(string: "https://s.livesport.services/api/v2/search/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "lang-id", value: language),
            URLQueryItem(name: "type-ids", value: types),
            URLQueryItem(name: "project-id", value: "401"),
            URLQueryItem(name: "project-type-id", value: "1"),
            URLQueryItem(name: "sport-ids", value: "1"),
        ]
        let (data, response) = try await session.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.badResponse(http.statusCode)
        }
        return try JSONDecoder().decode([TeamHit.Raw].self, from: data)
    }

    func teamMatches(_ team: TeamHit) async throws -> (fixtures: [Competition], results: [Competition]) {
        var request = URLRequest(url: team.page)
        request.setValue("https://www.flashscore.com.br/", forHTTPHeaderField: "Referer")
        let page = try await text(request)
        func feed(_ name: String) -> [Competition] {
            let pattern = "initialFeeds\\[\"\(name)\"\\]\\s*=\\s*\\{\\s*data:\\s*`([^`]*)`"
            guard let body = Self.match(pattern, in: page) else { return [] }
            return DayFeed.competitions(in: body)
        }
        return (feed("fixtures"), feed("results"))
    }

    func tv(_ id: String) async throws -> [String] {
        TVFeed.channels(try await brazilFeed("df_tv_1_\(id)", sign: LeagueConfig.defaultSign))
    }

    func h2h(_ id: String) async throws -> [H2HGroup] {
        var request = URLRequest(url: URL(string: "\(Self.brazilBase)df_hh_1_\(id)")!)
        request.setValue(LeagueConfig.defaultSign, forHTTPHeaderField: "x-fsign")
        request.setValue("https://www.flashscore.com.br/", forHTTPHeaderField: "Referer")
        return H2HFeed.groups(try await text(request))
    }

    func status(of match: Match) async throws -> Match {
        let body = try await feed("dc_1_\(match.id)", sign: LeagueConfig.defaultSign)
        guard let fields = Feed.rows(body).first, fields["DA"] != nil else { return match }
        return match.updated(
            phase: Phase.from(status: fields["DA"], detail: fields["DB"]),
            homeScore: fields["DE"].flatMap { Int($0) },
            awayScore: fields["DF"].flatMap { Int($0) },
            phaseStart: fields["DD"].flatMap(TimeInterval.init).map { Date(timeIntervalSince1970: $0) },
            addedTime: fields["CW"].flatMap { Int($0) }.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    func largeLogos(_ id: String) async throws -> (home: URL?, away: URL?) {
        var request = URLRequest(url: URL(string: "https://www.flashscore.com.br/jogo/futebol/\(id)/")!)
        request.setValue("https://www.flashscore.com.br/", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 5
        let page = try await text(request)
        func image(_ side: String) -> URL? {
            Self.match("\"\(side)\":\\[\\{[^\\]]*?\"image_path\":\"([^\"]+)\"", in: page)
                .map { $0.replacingOccurrences(of: "\\/", with: "/") }
                .flatMap(URL.init(string:))
        }
        return (image("home"), image("away"))
    }

    func detail(_ id: String, sign: String = LeagueConfig.defaultSign) async throws -> MatchDetail {
        async let summaryBody = brazilFeed("df_sui_1_\(id)", sign: sign)
        async let statsBody = try? brazilFeed("df_st_1_\(id)", sign: sign)
        let summary = DetailFeed.summary(try await summaryBody)
        let groups = await statsBody.map(DetailFeed.stats) ?? []
        return MatchDetail(periods: summary.periods, groups: groups, facts: summary.facts)
    }

    private func pages(prefix: String, config: LeagueConfig) async throws -> [Match] {
        var seen = Set<String>()
        var collected: [Match] = []
        for page in 0..<Self.maxPages {
            let name = "\(prefix)_1_\(config.country)_\(config.tournament)_\(config.season)_\(page)_3_en_1"
            let body: String
            do {
                body = try await feed(name, sign: config.sign)
            } catch {
                if page == 0 { throw error }
                break
            }
            let fresh = Feed.matches(in: body, tournament: config.tournament).filter { seen.insert($0.id).inserted }
            if fresh.isEmpty { break }
            collected += fresh
        }
        return collected
    }

    private func brazilFeed(_ name: String, sign: String) async throws -> String {
        var request = URLRequest(url: URL(string: Self.brazilBase + name)!)
        request.setValue(sign, forHTTPHeaderField: "x-fsign")
        request.setValue("https://www.flashscore.com.br/", forHTTPHeaderField: "Referer")
        return try await text(request)
    }

    private func feed(_ name: String, sign: String) async throws -> String {
        var request = URLRequest(url: URL(string: Self.feedBase + name)!)
        request.setValue(sign, forHTTPHeaderField: "x-fsign")
        return try await text(request)
    }

    private func text(_ request: URLRequest) async throws -> String {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.badResponse(http.statusCode)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func match(_ pattern: String, in text: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let found = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(found.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
