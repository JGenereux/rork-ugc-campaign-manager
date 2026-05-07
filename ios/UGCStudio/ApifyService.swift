import Foundation

nonisolated struct HandleStats: Hashable, Codable {
    let platform: String
    let handle: String
    let followers: Int
    let posts: Int
    let avgViews: Int
    let avgLikes: Int
    let engagementRate: Double
    var fetchedAt: Date
}

nonisolated enum ApifyError: Error, LocalizedError {
    case missingToken
    case badResponse(Int)
    case decoding
    case empty

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Apify token missing. Add EXPO_PUBLIC_APIFY_TOKEN."
        case .badResponse(let code): return "Apify responded with status \(code)."
        case .decoding: return "Could not decode Apify response."
        case .empty: return "No data returned for that handle."
        }
    }
}

@MainActor
@Observable
final class ApifyService {
    static let shared = ApifyService()

    var cache: [String: HandleStats] = [:]
    var inflight: Set<String> = []
    var lastError: String?

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = JSONDecoder()

    // Apify actor IDs (public scrapers).
    private let instagramActor = "apify~instagram-profile-scraper"
    private let tiktokActor = "clockworks~tiktok-profile-scraper"
    private let youtubeActor = "streamers~youtube-channel-scraper"

    private var token: String { Config.EXPO_PUBLIC_APIFY_TOKEN }

    func key(platform: String, handle: String) -> String { "\(platform.lowercased())|\(handle.lowercased())" }

    func stats(platform: String, handle: String) -> HandleStats? {
        cache[key(platform: platform, handle: handle)]
    }

    func loadIfNeeded(platform: String, handle: String) {
        let k = key(platform: platform, handle: handle)
        guard cache[k] == nil, !inflight.contains(k) else { return }
        let cleaned = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        guard !cleaned.isEmpty, !token.isEmpty else { return }
        inflight.insert(k)
        Task { await fetch(platform: platform, handle: cleaned, key: k) }
    }

    private func fetch(platform: String, handle: String, key: String) async {
        defer { inflight.remove(key) }
        do {
            let stats: HandleStats
            switch platform.lowercased() {
            case "instagram": stats = try await fetchInstagram(handle: handle)
            case "tiktok": stats = try await fetchTikTok(handle: handle)
            case "youtube": stats = try await fetchYouTube(handle: handle)
            default: return
            }
            cache[key] = stats
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Run helpers

    private func runActor(_ actorId: String, input: [String: Any]) async throws -> [[String: Any]] {
        guard !token.isEmpty else { throw ApifyError.missingToken }
        var url = URLComponents(string: "https://api.apify.com/v2/acts/\(actorId)/run-sync-get-dataset-items")!
        url.queryItems = [URLQueryItem(name: "token", value: token), URLQueryItem(name: "timeout", value: "55")]
        var req = URLRequest(url: url.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: input)
        req.timeoutInterval = 60
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ApifyError.badResponse(0) }
        guard (200..<300).contains(http.statusCode) else { throw ApifyError.badResponse(http.statusCode) }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw ApifyError.decoding }
        guard !arr.isEmpty else { throw ApifyError.empty }
        return arr
    }

    private func int(_ any: Any?) -> Int {
        if let n = any as? Int { return n }
        if let n = any as? Double { return Int(n) }
        if let s = any as? String, let n = Int(s) { return n }
        return 0
    }

    // MARK: - Platform fetchers

    private func fetchInstagram(handle: String) async throws -> HandleStats {
        let input: [String: Any] = [
            "usernames": [handle],
            "resultsLimit": 12
        ]
        let items = try await runActor(instagramActor, input: input)
        let profile = items.first ?? [:]
        let followers = int(profile["followersCount"])
        let posts = int(profile["postsCount"])
        let latest = (profile["latestPosts"] as? [[String: Any]]) ?? []
        let likes = latest.map { int($0["likesCount"]) }.reduce(0, +)
        let plays = latest.map { int($0["videoPlayCount"]) }.reduce(0, +)
        let count = max(latest.count, 1)
        let avgLikes = likes / count
        let avgViews = plays > 0 ? plays / count : avgLikes * 8
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        return HandleStats(platform: "Instagram", handle: handle, followers: followers, posts: posts, avgViews: avgViews, avgLikes: avgLikes, engagementRate: engagement, fetchedAt: Date())
    }

    private func fetchTikTok(handle: String) async throws -> HandleStats {
        let input: [String: Any] = [
            "profiles": [handle],
            "resultsPerPage": 12,
            "shouldDownloadVideos": false,
            "shouldDownloadCovers": false
        ]
        let items = try await runActor(tiktokActor, input: input)
        let stats = items.compactMap { $0["authorMeta"] as? [String: Any] }.first ?? [:]
        let followers = int(stats["fans"])
        let posts = int(stats["video"])
        let plays = items.map { int($0["playCount"]) }.reduce(0, +)
        let likes = items.map { int($0["diggCount"]) }.reduce(0, +)
        let count = max(items.count, 1)
        let avgViews = plays / count
        let avgLikes = likes / count
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        return HandleStats(platform: "TikTok", handle: handle, followers: followers, posts: posts, avgViews: avgViews, avgLikes: avgLikes, engagementRate: engagement, fetchedAt: Date())
    }

    private func fetchYouTube(handle: String) async throws -> HandleStats {
        let url = "https://www.youtube.com/@\(handle)"
        let input: [String: Any] = [
            "startUrls": [["url": url]],
            "maxResults": 12,
            "maxResultsShorts": 0,
            "maxResultStreams": 0
        ]
        let items = try await runActor(youtubeActor, input: input)
        let channel = items.first ?? [:]
        let followers = int(channel["numberOfSubscribers"])
        let posts = int(channel["videosCount"])
        let videos = (channel["videos"] as? [[String: Any]]) ?? items
        let plays = videos.map { int($0["viewCount"]) }.reduce(0, +)
        let likes = videos.map { int($0["likes"]) }.reduce(0, +)
        let count = max(videos.count, 1)
        let avgViews = plays / count
        let avgLikes = likes / count
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        return HandleStats(platform: "YouTube", handle: handle, followers: followers, posts: posts, avgViews: avgViews, avgLikes: avgLikes, engagementRate: engagement, fetchedAt: Date())
    }
}
