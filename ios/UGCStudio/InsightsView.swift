import SwiftUI

struct InsightsView: View {
    @Bindable var store: CampaignStore
    @State private var apify = ApifyService.shared

    private var allHandles: [(platform: String, handle: String)] {
        var seen: Set<String> = []
        var out: [(String, String)] = []
        for c in store.campaigns {
            for h in c.nonEmptyHandles {
                let cleaned = h.handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
                let k = "\(h.platform.lowercased())|\(cleaned.lowercased())"
                if seen.contains(k) { continue }
                seen.insert(k)
                out.append((h.platform, cleaned))
            }
        }
        return out
    }

    private var stats: [HandleStats] {
        allHandles.compactMap { apify.stats(platform: $0.platform, handle: $0.handle) }
    }

    private var totalVideos: Int { store.campaigns.reduce(0) { $0 + $1.videos.count } }
    private var postedVideos: Int { store.campaigns.flatMap(\.videos).filter(\.isPosted).count }
    private var totalFollowers: Int { stats.reduce(0) { $0 + $1.followers } }
    private var totalAvgViews: Int {
        stats.isEmpty ? 0 : stats.reduce(0) { $0 + $1.avgViews } / stats.count
    }
    private var totalER: Double {
        stats.isEmpty ? 0 : stats.reduce(0.0) { $0 + $1.engagementRate } / Double(stats.count)
    }

    private var topPosts: [SocialPost] {
        let sources: [SocialPost] = allHandles.flatMap { apify.posts(platform: $0.platform, handle: $0.handle) }
        return sources.sorted { $0.views > $1.views }.prefix(10).map { $0 }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    grid
                    handlesSection
                    topPostsSection
                    campaignsSection
                }
                .padding(14)
            }
            .refreshable {
                apify.refreshAll(handles: allHandles)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for h in allHandles { apify.loadIfNeeded(platform: h.platform, handle: h.handle) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: "Aggregate · all campaigns")
            Text("Studio Telemetry")
                .font(TypeScale.display(30))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
            insightTile(label: "Followers", value: Fmt.compact(totalFollowers), color: Palette.signalBlue)
            insightTile(label: "Avg / post", value: Fmt.compact(totalAvgViews), color: Palette.signalAmber)
            insightTile(label: "Engagement", value: String(format: "%.1f%%", totalER), color: Palette.signalGreen)
            insightTile(label: "Takes", value: "\(postedVideos) / \(totalVideos)", color: Palette.signalViolet)
        }
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private func insightTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Rectangle().fill(color).frame(width: 3, height: 12)
                CapsLabel(text: label, color: Palette.textTertiary, size: 9)
            }
            Text(value)
                .font(TypeScale.mono(26, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay(
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Palette.hairline).frame(height: 0.5)
            }
        )
        .overlay(
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Palette.hairline).frame(width: 0.5)
            }
        )
    }

    private var handlesSection: some View {
        DataSection(title: "Per-account performance") {
            if allHandles.isEmpty {
                Text("Add handles in any campaign to fetch live data.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(allHandles, id: \.handle) { item in
                        HandleStatRow(platform: item.platform, handle: item.handle)
                    }
                }
            }
        }
    }

    private var topPostsSection: some View {
        DataSection(title: "Top live posts (\(topPosts.count))") {
            if topPosts.isEmpty {
                Text("No live post data yet. Pull to refresh, or check Apify token in Settings.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(topPosts.enumerated()), id: \.element.id) { idx, post in
                        TopPostRow(post: post, rank: idx + 1)
                    }
                }
            }
        }
    }

    private var campaignsSection: some View {
        DataSection(title: "Campaign performance") {
            if store.campaigns.isEmpty {
                Text("No campaigns yet.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.campaigns) { c in
                        CampaignInsightRow(campaign: c)
                    }
                }
            }
        }
    }
}

struct CampaignInsightRow: View {
    let campaign: Campaign
    var body: some View {
        let totalViews = campaign.videos.reduce(0) { $0 + $1.views }
        let posted = campaign.videos.filter(\.isPosted).count
        return HStack(spacing: 12) {
            StatusDot(color: campaign.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(campaign.brand.uppercased())
                    .font(TypeScale.mono(11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.textPrimary)
                Text(campaign.title.isEmpty ? "(no title)" : campaign.title)
                    .font(TypeScale.body(11))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.compact(totalViews))
                    .font(TypeScale.mono(13, weight: .semibold))
                    .foregroundStyle(campaign.status.color)
                Text("\(posted)/\(campaign.videos.count) POSTED")
                    .font(TypeScale.caps(8))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }
}
