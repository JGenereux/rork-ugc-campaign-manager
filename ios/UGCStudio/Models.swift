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

    var nonEmptyHandles: [(platform: String, handle: String)] {
        var out: [(String, String)] = []
        for h in instagramHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append((PlatformName.instagram, h))
        }
        for h in tiktokHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append((PlatformName.tiktok, h))
        }
        for h in youtubeHandles where !h.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append((PlatformName.youtube, h))
        }
        return out
    }

    var videoProgress: Double {
        guard targetVideoCount > 0 else { return 0 }
        return min(1.0, Double(videos.count) / Double(targetVideoCount))
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

    func mergePostMetrics(videoID: UUID, in campaignID: UUID, views: Int, likes: Int, comments: Int) {
        guard let cIdx = campaigns.firstIndex(where: { $0.id == campaignID }) else { return }
        guard let vIdx = campaigns[cIdx].videos.firstIndex(where: { $0.id == videoID }) else { return }
        campaigns[cIdx].videos[vIdx].views = views
        campaigns[cIdx].videos[vIdx].likes = likes
        campaigns[cIdx].videos[vIdx].comments = comments
    }
}
