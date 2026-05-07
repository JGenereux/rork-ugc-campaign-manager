import SwiftUI

enum PostSort: String, CaseIterable, Identifiable {
    case views, recent, likes, engagement
    var id: String { rawValue }
    var label: String {
        switch self {
        case .views: return "Views"
        case .recent: return "Recent"
        case .likes: return "Likes"
        case .engagement: return "ER"
        }
    }
}

struct AllPostsView: View {
    @Bindable var store: CampaignStore
    @State private var apify = ApifyService.shared
    @State private var sort: PostSort = .views
    @State private var platformFilter: String? = nil   // nil = all
    @State private var handleFilter: String? = nil

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

    private var allPosts: [SocialPost] {
        allHandles.flatMap { apify.posts(platform: $0.platform, handle: $0.handle) }
    }

    private var filtered: [SocialPost] {
        var list = allPosts
        if let p = platformFilter {
            list = list.filter { $0.platform == p }
        }
        if let h = handleFilter {
            list = list.filter { $0.handle.lowercased() == h.lowercased() }
        }
        switch sort {
        case .views:
            list.sort { $0.views > $1.views }
        case .recent:
            list.sort { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
        case .likes:
            list.sort { $0.likes > $1.likes }
        case .engagement:
            list.sort {
                let er0 = $0.views > 0 ? Double($0.likes) / Double($0.views) : 0
                let er1 = $1.views > 0 ? Double($1.likes) / Double($1.views) : 0
                return er0 > er1
            }
        }
        return list
    }

    private var filteredHandles: [String] {
        var seen: Set<String> = []
        var out: [String] = []
        for h in allHandles {
            if let p = platformFilter, p != h.platform { continue }
            if !seen.contains(h.handle) {
                seen.insert(h.handle)
                out.append(h.handle)
            }
        }
        return out
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    sortBar
                    platformBar
                    if filteredHandles.count > 1 {
                        handleBar
                    }
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 6) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, post in
                                TopPostRow(post: post, rank: idx + 1)
                            }
                        }
                    }
                }
                .padding(14)
            }
            .refreshable {
                apify.refreshAll(handles: allHandles)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        .navigationTitle("All Posts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for h in allHandles { apify.loadIfNeeded(platform: h.platform, handle: h.handle) }
        }
    }

    // MARK: - Bars

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            CapsLabel(text: "All accounts · \(allHandles.count) handles")
            Text("\(filtered.count) posts")
                .font(TypeScale.display(28))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PostSort.allCases) { s in
                    FilterChip(
                        label: "↓ \(s.label)",
                        selected: sort == s,
                        color: Palette.signalAmber
                    ) { sort = s }
                }
            }
        }
    }

    private var platformBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", selected: platformFilter == nil) {
                    platformFilter = nil
                    handleFilter = nil
                }
                ForEach(PlatformName.all, id: \.self) { p in
                    FilterChip(
                        label: PlatformName.code(p),
                        selected: platformFilter == p,
                        color: PlatformName.color(p)
                    ) {
                        platformFilter = (platformFilter == p) ? nil : p
                        handleFilter = nil
                    }
                }
            }
        }
    }

    private var handleBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "all handles", selected: handleFilter == nil) {
                    handleFilter = nil
                }
                ForEach(filteredHandles, id: \.self) { h in
                    FilterChip(
                        label: "@\(h)",
                        selected: handleFilter == h,
                        color: Palette.signalCyan
                    ) {
                        handleFilter = (handleFilter == h) ? nil : h
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Palette.textSecondary)
            Text(allHandles.isEmpty ? "No accounts connected" : "No posts cached for this filter")
                .font(TypeScale.title(14))
                .foregroundStyle(Palette.textPrimary)
            Text(allHandles.isEmpty
                 ? "Add Instagram, TikTok or YouTube handles to a campaign."
                 : "Pull to refresh, or check Apify token in Settings.")
                .font(TypeScale.body(12))
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }
}
