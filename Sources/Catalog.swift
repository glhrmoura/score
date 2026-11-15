import Foundation
import Observation

@MainActor
@Observable
final class Catalog {
    private struct Snapshot: Codable {
        var countries: [Country] = []
        var countriesSavedAt: Date?
        var competitions: [String: [League]] = [:]
        var competitionsSavedAt: [String: Date] = [:]
    }

    private static let maxAge: TimeInterval = 7 * 24 * 3600

    private(set) var countries: [Country] = []
    private(set) var competitions: [String: [League]] = [:]
    private(set) var loading: Set<String> = []
    private(set) var failed: Set<String> = []

    @ObservationIgnored private var snapshot = Snapshot()
    @ObservationIgnored private let client = FeedClient()

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Score", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("catalog.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
            countries = saved.countries
            competitions = saved.competitions
        }
    }

    var regions: [Country] {
        Country.regionSlugs.compactMap { slug in countries.first { $0.slug == slug } }
    }

    var nations: [Country] {
        countries
            .filter { !$0.isRegion }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func loadCountries() async {
        let fresh = snapshot.countriesSavedAt.map { Date.now.timeIntervalSince($0) < Self.maxAge } ?? false
        guard !(fresh && !countries.isEmpty), !loading.contains("") else { return }
        loading.insert("")
        defer { loading.remove("") }
        guard let html = try? await client.html(URL(string: "https://www.flashscore.com/football/")!) else { return }
        let found = Self.links(#"href="/football/([a-z0-9-]+)/">([^<]+)<"#, in: html)
            .map { Country(slug: $0.0, english: Self.decode($0.1)) }
        guard found.count > 20 else { return }
        var seen = Set<String>()
        countries = found.filter { seen.insert($0.slug).inserted }
        snapshot.countries = countries
        snapshot.countriesSavedAt = .now
        save()
    }

    func loadCompetitions(of country: Country) async {
        let saved = snapshot.competitionsSavedAt[country.slug].map { Date.now.timeIntervalSince($0) < Self.maxAge } ?? false
        guard !(saved && competitions[country.slug] != nil), !loading.contains(country.slug) else { return }
        loading.insert(country.slug)
        failed.remove(country.slug)
        defer { loading.remove(country.slug) }
        let url = URL(string: "https://www.flashscore.com/football/\(country.slug)/")!
        var page = try? await client.html(url)
        if page == nil {
            try? await Task.sleep(for: .seconds(1.5))
            page = try? await client.html(url)
        }
        guard let html = page else {
            failed.insert(country.slug)
            return
        }
        let pattern = #"href="/football/\#(country.slug)/([a-z0-9-]+)/">([^<]+)<"#
        var seen = Set<String>()
        let leagues = Self.links(pattern, in: html)
            .filter { seen.insert($0.0).inserted }
            .map { League(path: "\(country.slug)/\($0.0)", name: Self.decode($0.1), country: country.name) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        competitions[country.slug] = leagues
        snapshot.competitions[country.slug] = leagues
        snapshot.competitionsSavedAt[country.slug] = .now
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private static func links(_ pattern: String, in text: String) -> [(String, String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { found in
            guard
                let slug = Range(found.range(at: 1), in: text),
                let name = Range(found.range(at: 2), in: text)
            else { return nil }
            return (String(text[slug]), String(text[name]).trimmingCharacters(in: .whitespaces))
        }
    }

    private static func decode(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}
