import Foundation
import SwiftUI

// MARK: - Schedule

nonisolated enum CampaignSchedule: Codable, Hashable {
    case oneTime(Date)
    case monthlyRecurring(day: Int)
    case ongoing

    var label: String {
        switch self {
        case .oneTime(let date): return Fmt.dateLong(date)
        case .monthlyRecurring(let day): return "Monthly · day \(day)"
        case .ongoing: return "Ongoing"
        }
    }

    var shortLabel: String {
        switch self {
        case .oneTime(let date): return Fmt.date(date)
        case .monthlyRecurring(let day): return "MO·\(day)"
        case .ongoing: return "ONGOING"
        }
    }
}

// MARK: - Status

nonisolated enum CampaignStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case pitch
    case briefing
    case filming
    case editing
    case posted
    case paid
    case archived

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pitch: return "Pitch"
        case .briefing: return "Briefing"
        case .filming: return "Filming"
        case .editing: return "Editing"
        case .posted: return "Posted"
        case .paid: return "Paid"
        case .archived: return "Archived"
        }
    }

    var code: String { rawValue.uppercased() }

    var color: Color {
        switch self {
        case .pitch: return Palette.signalBlue
        case .briefing: return Palette.signalCyan
        case .filming: return Palette.signalAmber
        case .editing: return Palette.signalViolet
        case .posted: return Palette.signalGreen
        case .paid: return Palette.signalGreen
        case .archived: return Palette.textTertiary
        }
    }

    static func fromFreeText(_ s: String) -> CampaignStatus {
        let l = s.lowercased()
        if l.contains("pitch") { return .pitch }
        if l.contains("brief") { return .briefing }
        if l.contains("film") || l.contains("record") || l.contains("shoot") { return .filming }
        if l.contains("edit") { return .editing }
        if l.contains("paid") || l.contains("invoic") { return .paid }
        if l.contains("post") || l.contains("publish") || l.contains("live") { return .posted }
        if l.contains("arch") { return .archived }
        return .filming
    }
}

// MARK: - Take (recorded video)

nonisolated struct UGCVideo: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var durationSeconds: Double
    var fileName: String?
    var views: Int
    var likes: Int
    var comments: Int
    var postedURL: String?
    var notes: String?

    var durationLabel: String { Fmt.duration(durationSeconds) }

    var fileURL: URL? {
        guard let fileName else { return nil }
        return URL.documentsDirectory.appending(path: fileName)
    }

    var isPosted: Bool {
        guard let url = postedURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return false }
        return true
    }
}

// MARK: - Script

nonisolated struct ScriptDraft: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var hook: String
    var body: String
    var createdAt: Date?
}

// MARK: - Accent (palette)

nonisolated enum AccentPalette: Int, Codable, CaseIterable, Identifiable {
    case cyan, pink, orange, green, purple, yellow
    var id: Int { rawValue }
    var color: Color {
        switch self {
        case .cyan: return Palette.signalBlue
        case .pink: return Palette.pInstagram
        case .orange: return Palette.signalAmber
        case .green: return Palette.signalGreen
        case .purple: return Palette.signalViolet
        case .yellow: return Palette.signalAmber
        }
    }
    var name: String {
        switch self {
        case .cyan: return "Blue"
        case .pink: return "Pink"
        case .orange: return "Amber"
        case .green: return "Green"
        case .purple: return "Violet"
        case .yellow: return "Yellow"
        }
    }
}

// MARK: - Campaign

nonisolated struct Campaign: Identifiable, Hashable, Codable {
    let id: UUID
    var brand: String
    var title: String
    var status: CampaignStatus
    var schedule: CampaignSchedule
    var targetVideoCount: Int
    var instagramHandles: [String]
    var tiktokHandles: [String]
    var youtubeHandles: [String]
    var videos: [UGCVideo]
    var scripts: [ScriptDraft]
    var accent: AccentPalette
    var createdAt: Date

    var accentColor: Color { accent.color }

    var allPlatforms: [String] {
        var out: [String] = []
        if instagramHandles.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { out.append(PlatformName.instagram) }
        if tiktokHandles.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { out.append(PlatformName.tiktok) }
        if youtubeHandles.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { out.append(PlatformName.youtube) }
        return out
    }

    var nonEmptyHandles: [HandleRef] {
        var out: [HandleRef] = []
        for h in instagramHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(HandleRef(platform: PlatformName.instagram, handle: h))
        }
        for h in tiktokHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(HandleRef(platform: PlatformName.tiktok, handle: h))
        }
        for h in youtubeHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(HandleRef(platform: PlatformName.youtube, handle: h))
        }
        return out
    }

    var videoProgress: Double {
        guard targetVideoCount > 0 else { return 0 }
        return min(1.0, Double(videos.count) / Double(targetVideoCount))
    }

    /// For `monthlyRecurring`: the most recent occurrence of `day` on or before
    /// today. For other schedules: `createdAt` (period == lifetime).
    var currentPeriodStart: Date {
        let cal = Calendar.current
        switch schedule {
        case .monthlyRecurring(let day):
            let now = Date()
            var comps = cal.dateComponents([.year, .month], from: now)
            comps.day = min(max(day, 1), 28)
            let thisMonthStart = cal.date(from: comps) ?? now
            if thisMonthStart <= now { return thisMonthStart }
            return cal.date(byAdding: .month, value: -1, to: thisMonthStart) ?? thisMonthStart
        case .oneTime, .ongoing:
            return createdAt
        }
    }

    /// Number of takes recorded since the start of the current period.
    /// For non-recurring schedules, this equals `videos.count`.
    var takesInCurrentPeriod: Int {
        switch schedule {
        case .monthlyRecurring:
            let start = currentPeriodStart
            return videos.filter { $0.date >= start }.count
        case .oneTime, .ongoing:
            return videos.count
        }
    }

    /// What we display in the primary "Takes" cell of cards / detail.
    /// Recurring → period count, others → lifetime total.
    var displayTakeCount: Int {
        switch schedule {
        case .monthlyRecurring: return takesInCurrentPeriod
        case .oneTime, .ongoing: return videos.count
        }
    }

    /// Caps label ("THIS MONTH", "TOTAL", "ONGOING") for the takes metric.
    var takesCellLabel: String {
        switch schedule {
        case .monthlyRecurring: return "Takes · this period"
        case .oneTime: return "Takes"
        case .ongoing: return "Takes"
        }
    }

    /// Progress relative to the period target (where applicable).
    var periodProgress: Double {
        guard targetVideoCount > 0 else { return 0 }
        switch schedule {
        case .monthlyRecurring:
            return min(1.0, Double(takesInCurrentPeriod) / Double(targetVideoCount))
        case .oneTime, .ongoing:
            return min(1.0, Double(videos.count) / Double(targetVideoCount))
        }
    }

    /// Cross-posted uploads are treated as the same video, so we use the
    /// highest per-platform count instead of summing TikTok + Instagram +
    /// YouTube together.
    func liveVideoCount(using posts: [SocialPost], since startDate: Date? = nil) -> Int {
        let filteredPosts = posts.filter { post in
            guard let startDate else { return true }
            guard let postedAt = post.postedAt else { return false }
            return postedAt >= startDate
        }
        let countsByPlatform = Dictionary(grouping: filteredPosts, by: { $0.platform.lowercased() })
            .mapValues { Set($0.map(\.id)).count }
        return countsByPlatform.values.max() ?? 0
    }

    /// For monthly campaigns, target hit should come from live posts in the
    /// current period rather than recorded takes.
    func targetHitCount(using posts: [SocialPost]) -> Int {
        switch schedule {
        case .monthlyRecurring:
            return liveVideoCount(using: posts, since: currentPeriodStart)
        case .oneTime, .ongoing:
            return videos.count
        }
    }

    func targetProgress(using posts: [SocialPost]) -> Double {
        guard targetVideoCount > 0 else { return 0 }
        return min(1.0, Double(targetHitCount(using: posts)) / Double(targetVideoCount))
    }

    init(
        id: UUID,
        brand: String,
        title: String,
        status: CampaignStatus,
        schedule: CampaignSchedule,
        targetVideoCount: Int,
        instagramHandles: [String],
        tiktokHandles: [String],
        youtubeHandles: [String],
        videos: [UGCVideo],
        scripts: [ScriptDraft],
        accent: AccentPalette,
        createdAt: Date
    ) {
        self.id = id
        self.brand = brand
        self.title = title
        self.status = status
        self.schedule = schedule
        self.targetVideoCount = targetVideoCount
        self.instagramHandles = instagramHandles
        self.tiktokHandles = tiktokHandles
        self.youtubeHandles = youtubeHandles
        self.videos = videos
        self.scripts = scripts
        self.accent = accent
        self.createdAt = createdAt
    }

    static func empty() -> Campaign {
        Campaign(
            id: UUID(),
            brand: "",
            title: "",
            status: .pitch,
            schedule: .ongoing,
            targetVideoCount: 30,
            instagramHandles: [],
            tiktokHandles: [],
            youtubeHandles: [],
            videos: [],
            scripts: [],
            accent: .cyan,
            createdAt: Date()
        )
    }

    // Lenient decoder for migration from earlier free-text status.
    enum CodingKeys: String, CodingKey {
        case id, brand, title, status, schedule, targetVideoCount,
             instagramHandles, tiktokHandles, youtubeHandles, videos, scripts, accent, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        brand = (try? c.decode(String.self, forKey: .brand)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        if let raw = try? c.decode(String.self, forKey: .status) {
            status = CampaignStatus(rawValue: raw.lowercased()) ?? CampaignStatus.fromFreeText(raw)
        } else {
            status = .filming
        }
        schedule = (try? c.decode(CampaignSchedule.self, forKey: .schedule)) ?? .ongoing
        targetVideoCount = (try? c.decode(Int.self, forKey: .targetVideoCount)) ?? 4
        instagramHandles = (try? c.decode([String].self, forKey: .instagramHandles)) ?? []
        tiktokHandles = (try? c.decode([String].self, forKey: .tiktokHandles)) ?? []
        youtubeHandles = (try? c.decode([String].self, forKey: .youtubeHandles)) ?? []
        videos = (try? c.decode([UGCVideo].self, forKey: .videos)) ?? []
        scripts = (try? c.decode([ScriptDraft].self, forKey: .scripts)) ?? []
        accent = (try? c.decode(AccentPalette.self, forKey: .accent)) ?? .cyan
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(brand, forKey: .brand)
        try c.encode(title, forKey: .title)
        try c.encode(status.rawValue, forKey: .status)
        try c.encode(schedule, forKey: .schedule)
        try c.encode(targetVideoCount, forKey: .targetVideoCount)
        try c.encode(instagramHandles, forKey: .instagramHandles)
        try c.encode(tiktokHandles, forKey: .tiktokHandles)
        try c.encode(youtubeHandles, forKey: .youtubeHandles)
        try c.encode(videos, forKey: .videos)
        try c.encode(scripts, forKey: .scripts)
        try c.encode(accent, forKey: .accent)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Handle reference (platform + handle, uniquely identifiable)

nonisolated struct HandleRef: Hashable, Identifiable {
    let platform: String
    let handle: String
    var id: String { "\(platform.lowercased())|\(handle.lowercased())" }
    var cleanedHandle: String {
        handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
    }
}

// MARK: - Social post (live data from Apify)

nonisolated struct SocialPost: Identifiable, Hashable, Codable {
    let id: String          // platform|handle|postId
    let platform: String
    let handle: String
    var caption: String
    var thumbnailURL: String?
    var postURL: String?
    var postedAt: Date?
    var views: Int
    var likes: Int
    var comments: Int

    var dateLabel: String { postedAt.map { Fmt.date($0) } ?? "—" }
}

// MARK: - Store

@MainActor
@Observable
final class CampaignStore {
    static let shared = CampaignStore()

    private let storageKey = "ugc.campaigns.v2"
    var campaigns: [Campaign] = [] {
        didSet { persist() }
    }

    init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        if let decoded = try? JSONDecoder().decode([Campaign].self, from: data) {
            campaigns = decoded
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(campaigns) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func upsert(_ c: Campaign) {
        if let idx = campaigns.firstIndex(where: { $0.id == c.id }) {
            campaigns[idx] = c
        } else {
            campaigns.insert(c, at: 0)
        }
    }

    func delete(_ id: UUID) {
        if let idx = campaigns.firstIndex(where: { $0.id == id }) {
            for v in campaigns[idx].videos {
                if let url = v.fileURL { try? FileManager.default.removeItem(at: url) }
            }
            campaigns.remove(at: idx)
        }
    }

    func addVideo(_ video: UGCVideo, toCampaign campaignID: UUID) {
        guard let idx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        campaigns[idx].videos.insert(video, at: 0)
    }

    func deleteVideo(videoID: UUID, fromCampaign campaignID: UUID) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        if let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == videoID }) {
            if let url = campaigns[cIdx].videos[vIdx].fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            campaigns[cIdx].videos.remove(at: vIdx)
        }
    }

    func renameVideo(videoID: UUID, in campaignID: UUID, to newTitle: String) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        guard let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == videoID }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        campaigns[cIdx].videos[vIdx].title = trimmed.isEmpty ? "Untitled take" : trimmed
    }

    func updateVideo(_ video: UGCVideo, in campaignID: UUID) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        if let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == video.id }) {
            campaigns[cIdx].videos[vIdx] = video
        }
    }

    func setPostedURL(_ url: String?, videoID: UUID, in campaignID: UUID) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        guard let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == videoID }) else { return }
        let cleaned = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        campaigns[cIdx].videos[vIdx].postedURL = (cleaned?.isEmpty == false) ? cleaned : nil
    }

    /// Remove takes that lack a recorded file AND have no metrics — these
    /// indicate a failed save or migration debris.
    @discardableResult
    func cleanEmptyVideos(in campaignID: UUID) -> Int {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return 0 }
        let before = campaigns[cIdx].videos.count
        campaigns[cIdx].videos.removeAll { v in
            let hasFile = v.fileURL.flatMap { FileManager.default.fileExists(atPath: $0.path) } ?? false
            let hasMetric = v.views > 0 || v.likes > 0 || v.comments > 0
            return !hasFile && !hasMetric
        }
        return before - campaigns[cIdx].videos.count
    }

    func mergePostMetrics(videoID: UUID, in campaignID: UUID, views: Int, likes: Int, comments: Int) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        guard let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == videoID }) else { return }
        campaigns[cIdx].videos[vIdx].views = views
        campaigns[cIdx].videos[vIdx].likes = likes
        campaigns[cIdx].videos[vIdx].comments = comments
    }
}
