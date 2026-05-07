import Foundation
import SwiftUI

nonisolated enum CampaignSchedule: Codable, Hashable {
    case oneTime(Date)
    case monthlyRecurring(day: Int)
    case ongoing

    var label: String {
        switch self {
        case .oneTime(let date): return date.formatted(.dateTime.month().day().year())
        case .monthlyRecurring(let day): return "Monthly • day \(day)"
        case .ongoing: return "Ongoing"
        }
    }

    var shortLabel: String {
        switch self {
        case .oneTime(let date): return date.formatted(.dateTime.month().day())
        case .monthlyRecurring(let day): return "Monthly d\(day)"
        case .ongoing: return "Ongoing"
        }
    }
}

nonisolated struct UGCVideo: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var durationSeconds: Double
    var fileName: String?
    // Insights are optional placeholders until we wire per-video analytics by URL.
    var views: Int
    var likes: Int
    var comments: Int

    var durationLabel: String {
        let total = Int(durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var fileURL: URL? {
        guard let fileName else { return nil }
        return URL.documentsDirectory.appending(path: fileName)
    }
}

nonisolated struct ScriptDraft: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var hook: String
    var body: String
}

nonisolated enum AccentPalette: Int, Codable, CaseIterable, Identifiable {
    case cyan, pink, orange, green, purple, yellow
    var id: Int { rawValue }
    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .purple: return .purple
        case .yellow: return .yellow
        }
    }
    var name: String {
        switch self {
        case .cyan: return "Cyan"
        case .pink: return "Pink"
        case .orange: return "Orange"
        case .green: return "Green"
        case .purple: return "Purple"
        case .yellow: return "Yellow"
        }
    }
}

nonisolated struct Campaign: Identifiable, Hashable, Codable {
    let id: UUID
    var brand: String
    var title: String
    var status: String
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
        if !instagramHandles.isEmpty { out.append("Instagram") }
        if !tiktokHandles.isEmpty { out.append("TikTok") }
        if !youtubeHandles.isEmpty { out.append("YouTube") }
        return out
    }

    var videoProgress: Double {
        guard targetVideoCount > 0 else { return 0 }
        return min(1.0, Double(videos.count) / Double(targetVideoCount))
    }

    static func empty() -> Campaign {
        Campaign(
            id: UUID(),
            brand: "",
            title: "",
            status: "Pitch",
            schedule: .ongoing,
            targetVideoCount: 4,
            instagramHandles: [],
            tiktokHandles: [],
            youtubeHandles: [],
            videos: [],
            scripts: [],
            accent: .cyan,
            createdAt: Date()
        )
    }
}

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
            // best-effort cleanup of recorded files
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
}
