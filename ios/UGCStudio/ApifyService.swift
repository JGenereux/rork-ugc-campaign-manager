import Foundation

// MARK: - Aggregate handle stats

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
        case .missingToken: return "Apify token missing. Add it in Settings."
        case .badResponse(let code): return "Apify responded with status \(code)."
        case .decoding: return "Could not decode Apify response."
        case .empty: return "No data returned for that handle."
        }
    }
}

// MARK: - Disk cache payload

private struct ApifyCachePayload: Codable {
    var stats: [String: HandleStats]
    var posts: [String: [SocialPost]]
}

@MainActor
@Observable
final class ApifyService {
    static let shared = ApifyService()

    private(set) var statsCache: [String: HandleStats] = [:]
    private(set) var postsCache: [String: [SocialPost]] = [:]
    var inflight: Set<String> = []
    var lastError: String?

    private let session: URLSession = .shared

    // Apify actor IDs (public scrapers).
    private let instagramActor = "apify~instagram-profile-scraper"
    private let tiktokActor = "clockworks~tiktok-profile-scraper"
    private let youtubeActor = "streamers~youtube-channel-scraper"

    private var token: String { TokenStore.resolvedApifyToken }

    private var cacheURL: URL {
        URL.documentsDirectory.appending(path: "apify-cache.json")
    }

    init() { loadFromDisk() }

    // MARK: - Keys / accessors

    func key(platform: String, handle: String) -> String {
        "\(platform.lowercased())|\(handle.lowercased())"
    }

    func stats(platform: String, handle: String) -> HandleStats? {
        statsCache[key(platform: platform, handle: handle)]
    }

    func posts(platform: String, handle: String) -> [SocialPost] {
        postsCache[key(platform: platform, handle: handle)] ?? []
    }

    var allPosts: [SocialPost] {
        postsCache.values.flatMap { $0 }
            .sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
    }

    func post(matchingURL urlString: String) -> SocialPost? {
        let needle = urlString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return nil }
        for posts in postsCache.values {
            for p in posts {
                if let u = p.postURL?.lowercased(), u == needle || u.contains(needle) || needle.contains(u) {
                    return p
                }
            }
        }
        return nil
    }

    // MARK: - Load orchestration

    func loadIfNeeded(platform: String, handle: String) {
        let cleaned = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        guard !cleaned.isEmpty else { return }
        let k = key(platform: platform, handle: cleaned)
        if statsCache[k] != nil { return }
        if inflight.contains(k) { return }
        guard !token.isEmpty else { return }
        inflight.insert(k)
        Task { await fetch(platform: platform, handle: cleaned, key: k) }
    }

    func refresh(platform: String, handle: String) {
        let cleaned = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
        guard !cleaned.isEmpty else { return }
        let k = key(platform: platform, handle: cleaned)
        if inflight.contains(k) { return }
        guard !token.isEmpty else {
            lastError = ApifyError.missingToken.errorDescription
            return
        }
        inflight.insert(k)
        Task { await fetch(platform: platform, handle: cleaned, key: k) }
    }

    func refreshAll(handles: [(platform: String, handle: String)]) {
        for h in handles { refresh(platform: h.platform, handle: h.handle) }
    }

    private func fetch(platform: String, handle: String, key: String) async {
        defer { inflight.remove(key) }
        do {
            let result: (HandleStats, [SocialPost])
            switch platform.lowercased() {
            case "instagram": result = try await fetchInstagram(handle: handle)
            case "tiktok":    result = try await fetchTikTok(handle: handle)
            case "youtube":   result = try await fetchYouTube(handle: handle)
            default: return
            }
            statsCache[key] = result.0
            postsCache[key] = result.1
            saveToDisk()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Disk cache

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        guard let payload = try? JSONDecoder().decode(ApifyCachePayload.self, from: data) else { return }
        statsCache = payload.stats
        postsCache = payload.posts
    }

    private func saveToDisk() {
        let payload = ApifyCachePayload(stats: statsCache, posts: postsCache)
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    // MARK: - Run helpers

    private func runActor(_ actorId: String, input: [String: Any]) async throws -> [[String: Any]] {
        guard !token.isEmpty else { throw ApifyError.missingToken }
        var url = URLComponents(string: "https://api.apify.com/v2/acts/\(actorId)/run-sync-get-dataset-items")!
        url.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "timeout", value: "55"),
        ]
        var req = URLRequest(url: url.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: input)
        req.timeoutInterval = 60
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ApifyError.badResponse(0) }
        guard (200..<300).contains(http.statusCode) else { throw ApifyError.badResponse(http.statusCode) }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ApifyError.decoding
        }
        guard !arr.isEmpty else { throw ApifyError.empty }
        return arr
    }

    private func int(_ any: Any?) -> Int {
        if let n = any as? Int { return n }
        if let n = any as? Double { return Int(n) }
        if let s = any as? String, let n = Int(s) { return n }
        return 0
    }

    private func str(_ any: Any?) -> String? {
        if let s = any as? String, !s.isEmpty { return s }
        return nil
    }

    private func date(unix any: Any?) -> Date? {
        let v = int(any)
        guard v > 0 else { return nil }
        // Some scrapers return seconds, some milliseconds. Heuristic: > 10^12 => ms.
        let seconds: TimeInterval = v > 1_000_000_000_000 ? Double(v) / 1000.0 : Double(v)
        return Date(timeIntervalSince1970: seconds)
    }

    private func dateISO(_ any: Any?) -> Date? {
        guard let s = any as? String, !s.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    // MARK: - Instagram

    private func fetchInstagram(handle: String) async throws -> (HandleStats, [SocialPost]) {
        let input: [String: Any] = [
            "usernames": [handle],
            "resultsLimit": 12,
        ]
        let items = try await runActor(instagramActor, input: input)
        let profile = items.first ?? [:]
        let followers = int(profile["followersCount"])
        let postsTotal = int(profile["postsCount"])
        let latest = (profile["latestPosts"] as? [[String: Any]]) ?? []
        let likes = latest.map { int($0["likesCount"]) }.reduce(0, +)
        let plays = latest.map { int($0["videoPlayCount"]) }.reduce(0, +)
        let denom = max(latest.count, 1)
        let avgLikes = likes / denom
        let avgViews = plays > 0 ? plays / denom : avgLikes * 8
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        let stats = HandleStats(
            platform: PlatformName.instagram, handle: handle,
            followers: followers, posts: postsTotal,
            avgViews: avgViews, avgLikes: avgLikes,
            engagementRate: engagement, fetchedAt: Date()
        )

        let socialPosts: [SocialPost] = latest.map { post in
            let pid = str(post["id"]) ?? str(post["shortCode"]) ?? UUID().uuidString
            let url = str(post["url"]) ?? str(post["shortCode"]).map { "https://www.instagram.com/p/\($0)/" }
            return SocialPost(
                id: "instagram|\(handle)|\(pid)",
                platform: PlatformName.instagram,
                handle: handle,
                caption: str(post["caption"]) ?? "",
                thumbnailURL: str(post["displayUrl"]) ?? str(post["thumbnailSrc"]),
                postURL: url,
                postedAt: date(unix: post["timestamp"]) ?? date(unix: post["takenAtTimestamp"]) ?? dateISO(post["timestamp"]),
                views: int(post["videoPlayCount"]),
                likes: int(post["likesCount"]),
                comments: int(post["commentsCount"])
            )
        }
        return (stats, socialPosts)
    }

    // MARK: - TikTok

    private func fetchTikTok(handle: String) async throws -> (HandleStats, [SocialPost]) {
        let input: [String: Any] = [
            "profiles": [handle],
            "resultsPerPage": 12,
            "shouldDownloadVideos": false,
            "shouldDownloadCovers": false,
        ]
        let items = try await runActor(tiktokActor, input: input)
        let author = items.compactMap { $0["authorMeta"] as? [String: Any] }.first ?? [:]
        let followers = int(author["fans"])
        let postsTotal = int(author["video"])
        let plays = items.map { int($0["playCount"]) }.reduce(0, +)
        let likesSum = items.map { int($0["diggCount"]) }.reduce(0, +)
        let denom = max(items.count, 1)
        let avgViews = plays / denom
        let avgLikes = likesSum / denom
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        let stats = HandleStats(
            platform: PlatformName.tiktok, handle: handle,
            followers: followers, posts: postsTotal,
            avgViews: avgViews, avgLikes: avgLikes,
            engagementRate: engagement, fetchedAt: Date()
        )

        let socialPosts: [SocialPost] = items.map { item in
            let pid = str(item["id"]) ?? UUID().uuidString
            let cover = (item["videoMeta"] as? [String: Any])?["coverUrl"] as? String
            return SocialPost(
                id: "tiktok|\(handle)|\(pid)",
                platform: PlatformName.tiktok,
                handle: handle,
                caption: str(item["text"]) ?? "",
                thumbnailURL: cover,
                postURL: str(item["webVideoUrl"]),
                postedAt: date(unix: item["createTime"]) ?? date(unix: item["createTimeISO"]) ?? dateISO(item["createTimeISO"]),
                views: int(item["playCount"]),
                likes: int(item["diggCount"]),
                comments: int(item["commentCount"])
            )
        }
        return (stats, socialPosts)
    }

    // MARK: - YouTube

    private func fetchYouTube(handle: String) async throws -> (HandleStats, [SocialPost]) {
        let url = "https://www.youtube.com/@\(handle)"
        let input: [String: Any] = [
            "startUrls": [["url": url]],
            "maxResults": 12,
            "maxResultsShorts": 0,
            "maxResultStreams": 0,
        ]
        let items = try await runActor(youtubeActor, input: input)
        let channel = items.first ?? [:]
        let followers = int(channel["numberOfSubscribers"])
        let postsTotal = int(channel["videosCount"])
        let videos = (channel["videos"] as? [[String: Any]]) ?? items
        let plays = videos.map { int($0["viewCount"]) }.reduce(0, +)
        let likesSum = videos.map { int($0["likes"]) }.reduce(0, +)
        let denom = max(videos.count, 1)
        let avgViews = plays / denom
        let avgLikes = likesSum / denom
        let engagement = followers > 0 ? Double(avgLikes) / Double(followers) * 100 : 0
        let stats = HandleStats(
            platform: PlatformName.youtube, handle: handle,
            followers: followers, posts: postsTotal,
            avgViews: avgViews, avgLikes: avgLikes,
            engagementRate: engagement, fetchedAt: Date()
        )

        let socialPosts: [SocialPost] = videos.map { v in
            let pid = str(v["id"]) ?? UUID().uuidString
            return SocialPost(
                id: "youtube|\(handle)|\(pid)",
                platform: PlatformName.youtube,
                handle: handle,
                caption: str(v["title"]) ?? "",
                thumbnailURL: str(v["thumbnailUrl"]) ?? str(v["thumbnail"]),
                postURL: str(v["url"]),
                postedAt: dateISO(v["date"]) ?? date(unix: v["uploadDate"]),
                views: int(v["viewCount"]),
                likes: int(v["likes"]),
                comments: int(v["commentsCount"])
            )
        }
        return (stats, socialPosts)
    }
}
