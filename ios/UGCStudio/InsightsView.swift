import SwiftUI

struct InsightsView: View {
    @Bindable var store: CampaignStore
    @State private var apify = ApifyService.shared

    private var allHandles: [HandleRef] {
        var seen: Set<String> = []
        var out: [HandleRef] = []
        for c in store.campaigns {
            for h in c.nonEmptyHandles {
                let ref = HandleRef(platform: h.platform, handle: h.cleanedHandle)
                if seen.contains(ref.id) { continue }
                seen.insert(ref.id)
                out.append(ref)
            }
        }
        return out
    }

    private var stats: [HandleStats] {
        allHandles.compactMap { apify.stats(platform: $0.platform, handle: $0.handle) }
    }

    private var posts: [SocialPost] {
        allHandles.flatMap { apify.posts(platform: $0.platform, handle: $0.handle) }
    }

    // MARK: - Aggregates

    private var totalFollowers: Int { stats.reduce(0) { $0 + $1.followers } }
    private var totalViews: Int { posts.reduce(0) { $0 + $1.views } }
    private var totalLikes: Int { posts.reduce(0) { $0 + $1.likes } }
    private var totalComments: Int { posts.reduce(0) { $0 + $1.comments } }
    private var totalPosts: Int { posts.count }

    private var avgViews: Int { totalPosts == 0 ? 0 : totalViews / totalPosts }
    private var avgLikes: Int { totalPosts == 0 ? 0 : totalLikes / totalPosts }
    private var avgComments: Int { totalPosts == 0 ? 0 : totalComments / totalPosts }
    private var avgEngagement: Double {
        stats.isEmpty ? 0 : stats.reduce(0.0) { $0 + $1.engagementRate } / Double(stats.count)
    }

    private var topPosts: [SocialPost] {
        posts.sorted { $0.views > $1.views }.prefix(10).map { $0 }
    }

    private var totalTakes: Int { store.campaigns.reduce(0) { $0 + $1.videos.count } }
    private var postedTakes: Int { store.campaigns.flatMap(\.videos).filter(\.isPosted).count }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    totalsBlock
                    averagesBlock
                    studioBlock
                    NavigationLink(value: "all-posts") {
                        allPostsCTA
                    }
                    .buttonStyle(.plain)
                    topPostsSection
                    if !allHandles.isEmpty {
                        handlesSection
                    }
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
        .navigationDestination(for: String.self) { route in
            if route == "all-posts" {
                AllPostsView(store: store)
            }
        }
        .onAppear {
            for h in allHandles { apify.loadIfNeeded(platform: h.platform, handle: h.handle) }
        }
    }

    private var allPostsCTA: some View {
        HStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(Palette.signalBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Browse all posts")
                    .font(TypeScale.title(14))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(totalPosts) cached across \(allHandles.count) handles")
                    .font(TypeScale.body(11))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: "Aggregate · all accounts")
            Text("Studio Telemetry")
                .font(TypeScale.display(30))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 6) {
                MonoChip(text: "\(allHandles.count) handles", color: Palette.signalBlue, bg: Palette.surface)
                MonoChip(text: "\(totalPosts) posts", color: Palette.signalAmber, bg: Palette.surface)
                MonoChip(text: "\(store.campaigns.count) campaigns", color: Palette.signalViolet, bg: Palette.surface)
            }
        }
    }

    // MARK: - Totals (sum across all accounts)

    private var totalsBlock: some View {
        DataSection(title: "Totals · all accounts") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)], spacing: 0) {
                bigTile(label: "Followers",  value: Fmt.compact(totalFollowers), color: Palette.signalBlue)
                bigTile(label: "Live posts", value: Fmt.compact(totalPosts),     color: Palette.signalCyan)
                bigTile(label: "Total views",    value: Fmt.compact(totalViews),    color: Palette.signalAmber)
                bigTile(label: "Total likes",    value: Fmt.compact(totalLikes),    color: Palette.signalGreen)
                bigTile(label: "Comments",       value: Fmt.compact(totalComments), color: Palette.signalViolet)
                bigTile(label: "Engagement",     value: String(format: "%.1f%%", avgEngagement), color: Palette.signalCyan)
            }
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        }
    }

    // MARK: - Averages

    private var averagesBlock: some View {
        DataSection(
            title: "Averages · per post",
            trailing: AnyView(
                Text(totalPosts == 0 ? "—" : "n=\(totalPosts)")
                    .font(TypeScale.caps(9))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textTertiary)
            )
        ) {
            HStack(spacing: 0) {
                MetricCell(label: "Avg views", value: Fmt.compact(avgViews), valueColor: Palette.signalAmber)
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                MetricCell(label: "Avg likes", value: Fmt.compact(avgLikes), valueColor: Palette.signalGreen)
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                MetricCell(label: "Avg comments", value: Fmt.compact(avgComments), valueColor: Palette.signalViolet)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        }
    }

    // MARK: - Studio totals

    private var studioBlock: some View {
        DataSection(title: "Studio") {
            HStack(spacing: 0) {
                MetricCell(label: "Campaigns", value: "\(store.campaigns.count)")
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                MetricCell(label: "Takes recorded", value: "\(totalTakes)")
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                MetricCell(label: "Posted", value: "\(postedTakes)", valueColor: postedTakes > 0 ? Palette.signalGreen : Palette.textPrimary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        }
    }

    // MARK: - Top live posts

    private var topPostsSection: some View {
        DataSection(
            title: "Top live posts",
            trailing: AnyView(
                Text("by views")
                    .font(TypeScale.caps(9))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textTertiary)
            )
        ) {
            if topPosts.isEmpty {
                Text(allHandles.isEmpty
                     ? "Add handles to your campaigns to fetch live data."
                     : "No live post data yet. Pull to refresh, or check Apify token in Settings.")
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

    // MARK: - Per-account compact

    private var handlesSection: some View {
        DataSection(title: "Per-account") {
            VStack(spacing: 6) {
                ForEach(allHandles) { item in
                    HandleStatRow(platform: item.platform, handle: item.handle)
                }
            }
        }
    }

    // MARK: - Helpers

    private func bigTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Rectangle().fill(color).frame(width: 3, height: 12)
                CapsLabel(text: label, color: Palette.textTertiary, size: 9)
            }
            Text(value)
                .font(TypeScale.mono(24, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
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
}
