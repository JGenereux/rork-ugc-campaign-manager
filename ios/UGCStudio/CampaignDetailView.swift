import SwiftUI
import UIKit

struct CampaignDetailView: View {
    @Binding var campaign: Campaign
    @Bindable var store: CampaignStore
    var onEdit: () -> Void

    @State private var apify = ApifyService.shared
    @State private var openAI = OpenAIService.shared

    @State private var showingRecorder: Bool = false
    @State private var brief: String = ""
    @State private var generationError: String?
    @State private var pendingDeleteScriptID: UUID?

    private var handles: [(platform: String, handle: String)] {
        campaign.nonEmptyHandles.map { (p, h) in
            (p, h.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")))
        }
    }

    private var allCampaignPosts: [SocialPost] {
        handles.flatMap { apify.posts(platform: $0.platform, handle: $0.handle) }
            .sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    headerStrip
                    metricsBar
                    handlesSection
                    recorderCTA
                    postsSection
                    takesSection
                    scriptsSection
                    insightsSection
                }
                .padding(14)
            }
            .refreshable {
                await refreshAll()
            }
        }
        .navigationTitle(campaign.brand.isEmpty ? "Campaign" : campaign.brand)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: onEdit)
                    .foregroundStyle(Palette.textPrimary)
            }
        }
        .sheet(isPresented: $showingRecorder) {
            NavigationStack {
                RecorderView(store: store, lockedCampaignID: campaign.id)
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            for h in handles { apify.loadIfNeeded(platform: h.platform, handle: h.handle) }
            mergePostMetricsForPostedTakes()
        }
        .alert("Generation failed", isPresented: Binding(
            get: { generationError != nil }, set: { if !$0 { generationError = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(generationError ?? "") }
    }

    // MARK: - Header strip

    private var headerStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StatusDot(color: campaign.status.color)
                Text(campaign.brand.uppercased())
                    .font(TypeScale.mono(13, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                MonoChip(text: campaign.status.code, color: campaign.status.color, bg: campaign.status.color.opacity(0.12))
            }
            Text(campaign.title.isEmpty ? "Untitled campaign" : campaign.title)
                .font(TypeScale.display(26))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 6) {
                ForEach(campaign.allPlatforms, id: \.self) { p in
                    MonoChip(text: PlatformName.code(p), color: PlatformName.color(p), bg: Palette.surface)
                }
                if campaign.allPlatforms.isEmpty {
                    Text("No platforms connected.")
                        .font(TypeScale.body(11))
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Text(campaign.schedule.shortLabel)
                    .font(TypeScale.mono(11))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    // MARK: - Metrics bar

    private var metricsBar: some View {
        let postedCount = campaign.videos.filter { $0.isPosted }.count
        let totalViews = campaign.videos.reduce(0) { $0 + $1.views }
        return HStack(spacing: 0) {
            MetricCell(label: "Takes", value: "\(campaign.videos.count)/\(campaign.targetVideoCount)")
            Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
            MetricCell(label: "Posted", value: "\(postedCount)")
            Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
            MetricCell(label: "Views", value: Fmt.compact(totalViews))
            Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
            MetricCell(label: "Progress", value: progressLabel, valueColor: campaign.status.color)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private var progressLabel: String {
        "\(Int((campaign.videoProgress * 100).rounded()))%"
    }

    // MARK: - Handles

    private var handlesSection: some View {
        DataSection(
            title: "Connected Accounts",
            trailing: AnyView(
                Button {
                    apify.refreshAll(handles: handles)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("REFRESH").tracking(1.2)
                    }
                    .font(TypeScale.caps(10))
                    .foregroundStyle(Palette.signalBlue)
                }
                .buttonStyle(.plain)
                .disabled(handles.isEmpty)
                .opacity(handles.isEmpty ? 0.4 : 1)
            )
        ) {
            if handles.isEmpty {
                Text("No accounts connected. Tap Edit to add Instagram, TikTok or YouTube handles.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(handles, id: \.handle) { item in
                        HandleStatRow(platform: item.platform, handle: item.handle)
                    }
                }
            }
        }
    }

    // MARK: - Recorder CTA

    private var recorderCTA: some View {
        Button { showingRecorder = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.signalRed).frame(width: 10, height: 10)
                }
                Text("RECORD INTO THIS CAMPAIGN")
                    .font(TypeScale.caps(12))
                    .tracking(1.5)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Palette.signalAmber)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Posts feed

    private var postsSection: some View {
        DataSection(
            title: "Live Posts (\(allCampaignPosts.count))",
            trailing: AnyView(
                Text(handles.isEmpty ? "—" : "swipe →")
                    .font(TypeScale.caps(9))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textTertiary)
            )
        ) {
            PostsFeed(posts: allCampaignPosts)
        }
    }

    // MARK: - Takes

    private var takesSection: some View {
        DataSection(
            title: "Takes (\(campaign.videos.count)/\(campaign.targetVideoCount))",
            trailing: AnyView(
                Button {
                    showingRecorder = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("NEW").tracking(1.2)
                    }
                    .font(TypeScale.caps(10))
                    .foregroundStyle(Palette.signalBlue)
                }
                .buttonStyle(.plain)
            )
        ) {
            if campaign.videos.isEmpty {
                Text("No takes yet. Tap RECORD INTO THIS CAMPAIGN above.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(campaign.videos.enumerated()), id: \.element.id) { idx, video in
                        VideoRow(
                            store: store,
                            campaignID: campaign.id,
                            video: video,
                            index: campaign.videos.count - idx
                        )
                    }
                }
            }
        }
    }

    // MARK: - Scripts (with OpenAI)

    private var scriptsSection: some View {
        DataSection(
            title: "Scripts (\(campaign.scripts.count))",
            trailing: AnyView(
                Group {
                    if openAI.inflight {
                        HStack(spacing: 6) {
                            ProgressView().tint(Palette.signalBlue).controlSize(.mini)
                            Text("GENERATING").tracking(1.2)
                        }
                        .font(TypeScale.caps(10))
                        .foregroundStyle(Palette.signalBlue)
                    } else if openAI.isConfigured {
                        Text("GPT-4o-MINI")
                            .font(TypeScale.caps(9))
                            .tracking(1.5)
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("KEY MISSING")
                            .font(TypeScale.caps(9))
                            .tracking(1.5)
                            .foregroundStyle(Palette.signalAmber)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Direction (optional)")
                    .font(TypeScale.caps(9))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textTertiary)
                TextField("e.g. unboxing reaction, problem-solution, before/after", text: $brief, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(TypeScale.body(13))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(10)
                    .background(Palette.surface)
                    .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
                    .lineLimit(1...4)

                HStack(spacing: 8) {
                    PrimaryButton(title: "Generate", systemImage: "sparkles") {
                        Task { await generateOne() }
                    }
                    GhostButton(title: "× 3 variants", systemImage: "rectangle.stack") {
                        Task { await generateThree() }
                    }
                }

                if !campaign.scripts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(campaign.scripts) { script in
                            ScriptCard(script: script) {
                                pendingDeleteScriptID = script.id
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this script?",
            isPresented: Binding(
                get: { pendingDeleteScriptID != nil },
                set: { if !$0 { pendingDeleteScriptID = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteScriptID {
                    campaign.scripts.removeAll { $0.id == id }
                }
                pendingDeleteScriptID = nil
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    @MainActor
    private func generateOne() async {
        do {
            let draft = try await openAI.generateScript(brand: campaign.brand, campaignTitle: campaign.title, brief: brief)
            campaign.scripts.insert(draft, at: 0)
        } catch {
            generationError = error.localizedDescription
        }
    }

    @MainActor
    private func generateThree() async {
        do {
            let drafts = try await openAI.generateScriptBatch(brand: campaign.brand, campaignTitle: campaign.title, brief: brief)
            for d in drafts.reversed() { campaign.scripts.insert(d, at: 0) }
        } catch {
            generationError = error.localizedDescription
        }
    }

    // MARK: - Insights summary

    private var insightsSection: some View {
        DataSection(title: "Account Aggregates") {
            if handles.isEmpty {
                Text("Add handles to see follower / engagement rollups.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.vertical, 6)
            } else {
                let stats = handles.compactMap { apify.stats(platform: $0.platform, handle: $0.handle) }
                if stats.isEmpty {
                    Text("Fetching live data via Apify…")
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textTertiary)
                } else {
                    let followers = stats.reduce(0) { $0 + $1.followers }
                    let avgViews = stats.reduce(0) { $0 + $1.avgViews } / max(stats.count, 1)
                    let er = stats.reduce(0.0) { $0 + $1.engagementRate } / Double(max(stats.count, 1))
                    HStack(spacing: 0) {
                        MetricCell(label: "Followers", value: Fmt.compact(followers))
                        Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                        MetricCell(label: "Avg / post", value: Fmt.compact(avgViews))
                        Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
                        MetricCell(label: "Engagement", value: String(format: "%.1f%%", er), valueColor: Palette.signalGreen)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Palette.surface)
                    .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Refresh

    @MainActor
    private func refreshAll() async {
        apify.refreshAll(handles: handles)
        // Allow some time for the actor calls to land before re-merging metrics.
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        mergePostMetricsForPostedTakes()
    }

    private func mergePostMetricsForPostedTakes() {
        for v in campaign.videos where v.isPosted {
            if let url = v.postedURL, let match = apify.post(matchingURL: url) {
                store.mergePostMetrics(videoID: v.id, in: campaign.id, views: match.views, likes: match.likes, comments: match.comments)
            }
        }
    }
}

// MARK: - Handle stat row

struct HandleStatRow: View {
    let platform: String
    let handle: String
    @State private var apify = ApifyService.shared

    private var stats: HandleStats? { apify.stats(platform: platform, handle: handle) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MonoChip(text: PlatformName.code(platform), color: PlatformName.color(platform), bg: Palette.surfaceHi)
                Text("@\(handle)")
                    .font(TypeScale.mono(12, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Button {
                    apify.refresh(platform: platform, handle: handle)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
            if let s = stats {
                HStack(spacing: 0) {
                    MetricCell(label: "Followers", value: Fmt.compact(s.followers))
                    MetricCell(label: "Avg views", value: Fmt.compact(s.avgViews))
                    MetricCell(label: "ER", value: String(format: "%.1f%%", s.engagementRate), valueColor: Palette.signalGreen)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini).tint(Palette.signalBlue)
                    Text("Fetching live data via Apify…")
                        .font(TypeScale.mono(11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        .onAppear { apify.loadIfNeeded(platform: platform, handle: handle) }
    }
}

// MARK: - Script card

struct ScriptCard: View {
    let script: ScriptDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CapsLabel(text: script.title, color: Palette.signalBlue)
                Spacer()
                Menu {
                    Button {
                        UIPasteboard.general.string = formatted()
                    } label: { Label("Copy script", systemImage: "doc.on.doc") }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            if !script.hook.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    CapsLabel(text: "Hook", color: Palette.textTertiary, size: 9)
                    Text(script.hook)
                        .font(TypeScale.title(15))
                        .foregroundStyle(Palette.signalAmber)
                }
            }
            if !script.body.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    CapsLabel(text: "Body", color: Palette.textTertiary, size: 9)
                    Text(script.body)
                        .font(TypeScale.mono(12))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private func formatted() -> String {
        var out = "\(script.title)\n\nHOOK: \(script.hook)\n\n"
        out.append(script.body)
        return out
    }
}
