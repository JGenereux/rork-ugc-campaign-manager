import SwiftUI
import AVFoundation

nonisolated enum AppTab: Hashable { case campaigns, record, insights }

struct ContentView: View {
    @State private var store = CampaignStore.shared
    @State private var selectedTab: AppTab = .campaigns
    @State private var showingEditor: Bool = false
    @State private var editingCampaign: Campaign?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CampaignsView(
                    store: store,
                    showingEditor: $showingEditor,
                    editingCampaign: $editingCampaign
                )
            }
            .tabItem { Label("Campaigns", systemImage: "rectangle.stack.fill") }
            .tag(AppTab.campaigns)

            NavigationStack {
                RecorderView(store: store)
            }
            .tabItem { Label("Record", systemImage: "record.circle") }
            .tag(AppTab.record)

            NavigationStack {
                GlobalInsightsView(store: store)
            }
            .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.insights)
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingEditor) {
            CampaignEditorView(initial: editingCampaign) { saved in
                store.upsert(saved)
            }
        }
    }
}

// MARK: - Campaigns list

struct CampaignsView: View {
    @Bindable var store: CampaignStore
    @Binding var showingEditor: Bool
    @Binding var editingCampaign: Campaign?
    @State private var query: String = ""
    @State private var pendingDeleteID: UUID?

    private var filtered: [Campaign] {
        query.isEmpty ? store.campaigns : store.campaigns.filter {
            $0.brand.localizedCaseInsensitiveContains(query) ||
            $0.title.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            StudioBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if store.campaigns.isEmpty {
                        EmptyStateView(
                            icon: "rectangle.stack.badge.plus",
                            title: "No campaigns yet",
                            subtitle: "Tap + to add your first brand campaign."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(filtered) { campaign in
                            NavigationLink(value: campaign.id) {
                                CampaignCard(campaign: campaign)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingCampaign = campaign
                                    showingEditor = true
                                } label: { Label("Edit", systemImage: "pencil") }
                                Button(role: .destructive) {
                                    pendingDeleteID = campaign.id
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDeleteID = campaign.id
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .searchable(text: $query, prompt: "Search brands or campaigns")
        .navigationDestination(for: UUID.self) { id in
            if let index = store.campaigns.firstIndex(where: { $0.id == id }) {
                CampaignDetailView(campaign: $store.campaigns[index], store: store) {
                    editingCampaign = store.campaigns[index]
                    showingEditor = true
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCampaign = nil
                    showingEditor = true
                } label: { Image(systemName: "plus.circle.fill").font(.title2) }
            }
        }
        .confirmationDialog(
            "Delete this campaign?",
            isPresented: Binding(get: { pendingDeleteID != nil }, set: { if !$0 { pendingDeleteID = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID { store.delete(id) }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("All recorded takes for this campaign will also be removed.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UGC Studio")
                .font(.system(size: 38, weight: .black, design: .rounded))
            Text("Manage every brand campaign, recording, handle, and insight in one workspace.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                StatPill(title: "Campaigns", value: "\(store.campaigns.count)", color: .cyan)
                StatPill(title: "Takes", value: "\(store.campaigns.flatMap(\.videos).count)", color: .pink)
                StatPill(title: "Targets", value: "\(store.campaigns.reduce(0) { $0 + $1.targetVideoCount })", color: .orange)
            }
        }
    }
}

// MARK: - Campaign card

struct CampaignCard: View {
    let campaign: Campaign

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.brand.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(campaign.accentColor)
                    Text(campaign.title.isEmpty ? "Untitled campaign" : campaign.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(campaign.status)
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.white.opacity(0.1), in: .capsule)
            }
            if !campaign.allPlatforms.isEmpty {
                HStack { ForEach(campaign.allPlatforms, id: \.self) { PlatformChip(platform: $0) } }
            }
            ProgressView(value: campaign.videoProgress).tint(campaign.accentColor)
            HStack {
                Label("\(campaign.videos.count)/\(campaign.targetVideoCount) videos", systemImage: "video.fill")
                Spacer()
                Label(campaign.schedule.shortLabel, systemImage: "calendar")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial.opacity(0.9), in: .rect(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(campaign.accentColor.opacity(0.45), lineWidth: 1) }
    }
}

// MARK: - Campaign detail

struct CampaignDetailView: View {
    @Binding var campaign: Campaign
    @Bindable var store: CampaignStore
    var onEdit: () -> Void

    @State private var showingRecorder: Bool = false
    @State private var scriptPrompt: String = ""

    var body: some View {
        ZStack {
            StudioBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CampaignCard(campaign: campaign)
                    schedulePanel
                    handlesPanel
                    recorderCTA
                    videosPanel
                    scriptsPanel
                    CampaignInsightsBlock(campaign: campaign)
                }
                .padding(16)
            }
        }
        .navigationTitle(campaign.brand)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: onEdit)
            }
        }
        .sheet(isPresented: $showingRecorder) {
            NavigationStack {
                RecorderView(store: store, lockedCampaignID: campaign.id)
            }
        }
    }

    private var schedulePanel: some View {
        StudioPanel(title: "Schedule") {
            HStack {
                Image(systemName: scheduleIcon).foregroundStyle(campaign.accentColor)
                Text(campaign.schedule.label)
                Spacer()
                Text("Target \(campaign.targetVideoCount)").font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.white.opacity(0.08), in: .capsule)
            }
            .font(.subheadline)
        }
    }

    private var scheduleIcon: String {
        switch campaign.schedule {
        case .oneTime: return "calendar"
        case .monthlyRecurring: return "arrow.triangle.2.circlepath"
        case .ongoing: return "infinity"
        }
    }

    private var handlesPanel: some View {
        StudioPanel(title: "Connected accounts") {
            VStack(spacing: 14) {
                HandleGroup(platform: "Instagram", icon: "camera.aperture", accent: .pink, handles: campaign.instagramHandles)
                HandleGroup(platform: "TikTok", icon: "music.note", accent: .cyan, handles: campaign.tiktokHandles)
                HandleGroup(platform: "YouTube", icon: "play.rectangle.fill", accent: .red, handles: campaign.youtubeHandles)
            }
        }
    }

    private var recorderCTA: some View {
        Button { showingRecorder = true } label: {
            HStack {
                Image(systemName: "record.circle.fill")
                Text("Record into this campaign").bold()
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding(18)
            .background(campaign.accentColor.gradient, in: .rect(cornerRadius: 22))
            .foregroundStyle(.black)
        }
    }

    private var videosPanel: some View {
        StudioPanel(title: "Takes (\(campaign.videos.count))") {
            if campaign.videos.isEmpty {
                Text("No takes yet. Tap record to capture one.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(campaign.videos) { video in
                        VideoRow(video: video)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.deleteVideo(videoID: video.id, fromCampaign: campaign.id)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteVideo(videoID: video.id, fromCampaign: campaign.id)
                                } label: { Label("Delete take", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private var scriptsPanel: some View {
        StudioPanel(title: "Scripts") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Hook idea, CTA, talking point...", text: $scriptPrompt, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Add script idea") {
                    let trimmed = scriptPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    campaign.scripts.insert(
                        ScriptDraft(id: UUID(), title: "Draft", hook: trimmed, body: "Hook → pain point → product moment → proof → CTA."),
                        at: 0
                    )
                    scriptPrompt = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(scriptPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                ForEach(campaign.scripts) { script in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(script.title).bold()
                        Text(script.hook).foregroundStyle(.cyan)
                        Text(script.body).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                }
            }
        }
    }
}

struct HandleGroup: View {
    let platform: String
    let icon: String
    let accent: Color
    let handles: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(accent)
                Text(platform).font(.subheadline.bold())
                Spacer()
                Text("\(handles.count)").font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(accent.opacity(0.18), in: .capsule)
            }
            if handles.isEmpty {
                Text("No \(platform) accounts connected.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(handles, id: \.self) { h in
                    LiveHandleRow(platform: platform, handle: h, accent: accent)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 16))
    }
}

// MARK: - Recorder

struct RecorderView: View {
    @Bindable var store: CampaignStore
    var lockedCampaignID: UUID? = nil

    @State private var recorder = CameraRecorder()
    @State private var assignSheetURL: URL?
    @State private var assignSheetDuration: Double = 0

    var body: some View {
        ZStack {
            StudioBackground()
            VStack(spacing: 18) {
                preview
                controls
            }
            .padding(16)
        }
        .navigationTitle("Recorder")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !recorder.isConfigured && !recorder.permissionDenied {
                await recorder.requestAccessAndConfigure()
            }
        }
        .onDisappear { recorder.teardown() }
        .sheet(item: Binding(
            get: { assignSheetURL.map { TakeAssignment(url: $0, duration: assignSheetDuration) } },
            set: { newValue in if newValue == nil { assignSheetURL = nil } }
        )) { assignment in
            AssignTakeSheet(
                store: store,
                fileURL: assignment.url,
                duration: assignment.duration,
                presetCampaignID: lockedCampaignID
            )
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if recorder.permissionDenied {
                placeholder("Camera or microphone permission denied. Enable both in Settings to record.", icon: "lock.shield.fill")
            } else if !recorder.isConfigured {
                placeholder("Preparing camera...", icon: "video.fill")
            } else {
                CameraPreview(session: recorder.session)
                    .clipShape(.rect(cornerRadius: 28))
                    .overlay(alignment: .topLeading) {
                        if recorder.isRecording { recordingPill }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { recorder.flip() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.title3)
                                .padding(10)
                                .background(.black.opacity(0.5), in: .circle)
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 460)
        .background(.black, in: .rect(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.cyan.opacity(0.3), lineWidth: 1) }
    }

    private var recordingPill: some View {
        HStack(spacing: 6) {
            Circle().fill(.red).frame(width: 8, height: 8)
            Text(formatTime(recorder.elapsed)).font(.caption.monospacedDigit().bold())
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: .capsule)
        .foregroundStyle(.white)
        .padding(12)
    }

    private func placeholder(_ text: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(.cyan)
            Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
            if recorder.permissionDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        if let id = lockedCampaignID,
           let campaign = store.campaigns.first(where: { $0.id == id }) {
            HStack {
                Image(systemName: "rectangle.stack.fill").foregroundStyle(campaign.accentColor)
                Text("Saving to \(campaign.brand)").font(.subheadline.bold())
                Spacer()
            }
            .padding(12)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
        }

        Button {
            handleTap()
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? .red : .cyan)
                    .frame(width: 92, height: 92)
                if recorder.isRecording {
                    RoundedRectangle(cornerRadius: 6).fill(.white).frame(width: 32, height: 32)
                } else {
                    Circle().stroke(.white, lineWidth: 5).frame(width: 68, height: 68)
                }
            }
        }
        .disabled(!recorder.isConfigured && !recorder.isRecording)
        .opacity(recorder.isConfigured || recorder.isRecording ? 1 : 0.4)

        Text(recorder.isRecording ? "Tap to stop" : "Tap to record")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func handleTap() {
        if recorder.isRecording {
            Task {
                let url = await recorder.stopRecording()
                let duration = recorder.lastDuration
                guard let url else { return }
                if let lockedID = lockedCampaignID {
                    saveTake(url: url, duration: duration, toCampaignID: lockedID)
                } else {
                    assignSheetDuration = duration
                    assignSheetURL = url
                }
            }
        } else {
            recorder.startRecording()
        }
    }

    private func saveTake(url: URL, duration: Double, toCampaignID id: UUID) {
        let fileName = "take-\(UUID().uuidString).mov"
        let destination = URL.documentsDirectory.appending(path: fileName)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: url, to: destination)
            let campaign = store.campaigns.first(where: { $0.id == id })
            let title = "Take \((campaign?.videos.count ?? 0) + 1)"
            let video = UGCVideo(id: UUID(), title: title, date: Date(), durationSeconds: duration, fileName: fileName, views: 0, likes: 0, comments: 0)
            store.addVideo(video, toCampaign: id)
        } catch {
            // file move failed; ignore
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TakeAssignment: Identifiable {
    let id = UUID()
    let url: URL
    let duration: Double
}

struct AssignTakeSheet: View {
    @Bindable var store: CampaignStore
    let fileURL: URL
    let duration: Double
    let presetCampaignID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackground()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Assign take").font(.title2.bold())
                    Text("Save this \(Int(duration.rounded()))s recording into a campaign.")
                        .foregroundStyle(.secondary)
                    if store.campaigns.isEmpty {
                        EmptyStateView(icon: "rectangle.stack.badge.plus", title: "No campaigns", subtitle: "Create a campaign first.")
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(store.campaigns) { campaign in
                                    Button { selected = campaign.id } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(campaign.brand).bold()
                                                Text(campaign.title).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if selected == campaign.id {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(campaign.accentColor)
                                            }
                                        }
                                        .padding(14)
                                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(selected == campaign.id ? campaign.accentColor : .clear, lineWidth: 1.5)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Spacer()
                    Button {
                        save()
                    } label: {
                        Text("Save take").bold().frame(maxWidth: .infinity).padding(14)
                    }
                    .background(.cyan, in: .rect(cornerRadius: 16))
                    .foregroundStyle(.black)
                    .disabled(selected == nil)
                    .opacity(selected == nil ? 0.4 : 1)
                }
                .padding(16)
            }
            .navigationTitle("Save take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        try? FileManager.default.removeItem(at: fileURL)
                        dismiss()
                    }
                }
            }
            .onAppear { selected = presetCampaignID ?? store.campaigns.first?.id }
        }
    }

    private func save() {
        guard let cid = selected else { return }
        let fileName = "take-\(UUID().uuidString).mov"
        let destination = URL.documentsDirectory.appending(path: fileName)
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
        let count = store.campaigns.first(where: { $0.id == cid })?.videos.count ?? 0
        let video = UGCVideo(id: UUID(), title: "Take \(count + 1)", date: Date(), durationSeconds: duration, fileName: fileName, views: 0, likes: 0, comments: 0)
        store.addVideo(video, toCampaign: cid)
        dismiss()
    }
}

// MARK: - Insights

struct GlobalInsightsView: View {
    @Bindable var store: CampaignStore
    @State private var service = ApifyService.shared

    private var allHandles: [(platform: String, handle: String)] {
        var out: [(String, String)] = []
        for c in store.campaigns {
            for h in c.instagramHandles { out.append(("Instagram", clean(h))) }
            for h in c.tiktokHandles { out.append(("TikTok", clean(h))) }
            for h in c.youtubeHandles { out.append(("YouTube", clean(h))) }
        }
        // Dedupe
        var seen: Set<String> = []
        return out.filter {
            let k = "\($0.0.lowercased())|\($0.1.lowercased())"
            if seen.contains(k) || $0.1.isEmpty { return false }
            seen.insert(k); return true
        }
    }

    private var collectedStats: [HandleStats] {
        allHandles.compactMap { service.stats(platform: $0.platform, handle: $0.handle) }
    }

    private var totalVideos: Int { store.campaigns.reduce(0) { $0 + $1.videos.count } }
    private var totalFollowers: Int { collectedStats.reduce(0) { $0 + $1.followers } }
    private var totalAvgViews: Int {
        collectedStats.isEmpty ? 0 : collectedStats.reduce(0) { $0 + $1.avgViews } / collectedStats.count
    }
    private var totalER: Double {
        collectedStats.isEmpty ? 0 : collectedStats.reduce(0.0) { $0 + $1.engagementRate } / Double(collectedStats.count)
    }

    var body: some View {
        ZStack {
            StudioBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("All Insights").font(.largeTitle.bold())
                    Text("Aggregated across every connected account, campaign, and recording.")
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Followers", value: totalFollowers.formatted(.number.notation(.compactName)), color: .cyan)
                        MetricTile(title: "Avg views / post", value: totalAvgViews.formatted(.number.notation(.compactName)), color: .pink)
                        MetricTile(title: "Avg engagement", value: String(format: "%.1f%%", totalER), color: .orange)
                        MetricTile(title: "Recorded takes", value: totalVideos.formatted(), color: .green)
                    }
                    StudioPanel(title: "Per-account performance") {
                        if allHandles.isEmpty {
                            Text("Add handles to your campaigns to load insights.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(allHandles, id: \.handle) { item in
                                    LiveHandleRow(platform: item.platform, handle: item.handle, accent: accent(for: item.platform))
                                }
                            }
                        }
                    }
                    StudioPanel(title: "Campaign performance") {
                        if store.campaigns.isEmpty {
                            Text("No campaigns yet.").font(.caption).foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.campaigns) { CampaignInsightRow(campaign: $0) }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for item in allHandles {
                service.loadIfNeeded(platform: item.platform, handle: item.handle)
            }
        }
    }

    private func clean(_ s: String) -> String { s.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")) }
    private func accent(for platform: String) -> Color {
        switch platform { case "Instagram": return .pink; case "TikTok": return .cyan; case "YouTube": return .red; default: return .gray }
    }
}

struct CampaignInsightsBlock: View {
    let campaign: Campaign
    var body: some View {
        StudioPanel(title: "Campaign insights") {
            VStack(spacing: 10) {
                CampaignInsightRow(campaign: campaign)
                ForEach(campaign.instagramHandles, id: \.self) { LiveHandleRow(platform: "Instagram", handle: $0, accent: .pink) }
                ForEach(campaign.tiktokHandles, id: \.self) { LiveHandleRow(platform: "TikTok", handle: $0, accent: .cyan) }
                ForEach(campaign.youtubeHandles, id: \.self) { LiveHandleRow(platform: "YouTube", handle: $0, accent: .red) }
            }
        }
    }
}

struct CampaignInsightRow: View {
    let campaign: Campaign
    var body: some View {
        let total = campaign.videos.reduce(0) { $0 + $1.views }
        HStack {
            VStack(alignment: .leading) {
                Text(campaign.brand).bold()
                Text(campaign.allPlatforms.joined(separator: " • "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(campaign.videos.count) takes").font(.caption).foregroundStyle(.secondary)
                Text(total.formatted()).font(.title3.bold()).foregroundStyle(campaign.accentColor)
            }
        }
    }
}

struct LiveHandleRow: View {
    let platform: String
    let handle: String
    let accent: Color
    @State private var service = ApifyService.shared

    private var cleaned: String { handle.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")) }
    private var stats: HandleStats? { service.stats(platform: platform, handle: cleaned) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(accent)
                Text(handle.hasPrefix("@") ? handle : "@\(handle)").font(.subheadline.bold())
                Spacer()
                Text(platform).font(.caption).foregroundStyle(.secondary)
            }
            if let s = stats {
                HStack(spacing: 10) {
                    MetricChip(label: "Followers", value: s.followers.formatted(.number.notation(.compactName)))
                    MetricChip(label: "Avg views", value: s.avgViews.formatted(.number.notation(.compactName)))
                    MetricChip(label: "ER", value: String(format: "%.1f%%", s.engagementRate))
                }
            } else if cleaned.isEmpty {
                Text("Empty handle.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Fetching live insights via Apify…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
        .onAppear { service.loadIfNeeded(platform: platform, handle: cleaned) }
    }

    private var icon: String {
        switch platform { case "Instagram": return "camera.aperture"; case "TikTok": return "music.note"; case "YouTube": return "play.rectangle.fill"; default: return "person.fill" }
    }
}

// MARK: - Editor

struct CampaignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var campaign: Campaign
    @State private var scheduleType: ScheduleType
    @State private var scheduleDate: Date
    @State private var scheduleDay: Int
    @State private var newIG: String = ""
    @State private var newTT: String = ""
    @State private var newYT: String = ""

    let onSave: (Campaign) -> Void
    private let isNew: Bool

    enum ScheduleType: String, CaseIterable, Identifiable {
        case oneTime = "Date"
        case monthly = "Monthly"
        case ongoing = "Ongoing"
        var id: String { rawValue }
    }

    init(initial: Campaign?, onSave: @escaping (Campaign) -> Void) {
        let c = initial ?? Campaign.empty()
        _campaign = State(initialValue: c)
        switch c.schedule {
        case .oneTime(let date):
            _scheduleType = State(initialValue: .oneTime)
            _scheduleDate = State(initialValue: date)
            _scheduleDay = State(initialValue: 1)
        case .monthlyRecurring(let day):
            _scheduleType = State(initialValue: .monthly)
            _scheduleDate = State(initialValue: Date())
            _scheduleDay = State(initialValue: day)
        case .ongoing:
            _scheduleType = State(initialValue: .ongoing)
            _scheduleDate = State(initialValue: Date())
            _scheduleDay = State(initialValue: 1)
        }
        self.onSave = onSave
        self.isNew = initial == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Campaign") {
                    TextField("Brand", text: $campaign.brand)
                    TextField("Campaign title", text: $campaign.title)
                    TextField("Status (Pitch, Filming, Editing…)", text: $campaign.status)
                    Stepper("Target videos: \(campaign.targetVideoCount)", value: $campaign.targetVideoCount, in: 1...100)
                    Picker("Accent", selection: $campaign.accent) {
                        ForEach(AccentPalette.allCases) { p in
                            HStack { Circle().fill(p.color).frame(width: 14, height: 14); Text(p.name) }.tag(p)
                        }
                    }
                }

                Section("Schedule") {
                    Picker("Type", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch scheduleType {
                    case .oneTime:
                        DatePicker("Due date", selection: $scheduleDate, displayedComponents: .date)
                    case .monthly:
                        Stepper("Day of month: \(scheduleDay)", value: $scheduleDay, in: 1...28)
                        Text("Repeats every month. You can adjust this later.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .ongoing:
                        Text("No fixed deadline. Record continuously.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                handleSection(
                    title: "Instagram accounts",
                    icon: "camera.aperture",
                    accent: .pink,
                    handles: $campaign.instagramHandles,
                    new: $newIG,
                    placeholder: "@brand"
                )
                handleSection(
                    title: "TikTok accounts",
                    icon: "music.note",
                    accent: .cyan,
                    handles: $campaign.tiktokHandles,
                    new: $newTT,
                    placeholder: "@brand.co"
                )
                handleSection(
                    title: "YouTube channels",
                    icon: "play.rectangle.fill",
                    accent: .red,
                    handles: $campaign.youtubeHandles,
                    new: $newYT,
                    placeholder: "@brand"
                )
            }
            .navigationTitle(isNew ? "New campaign" : "Edit campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        applySchedule()
                        onSave(campaign)
                        dismiss()
                    }
                    .bold()
                    .disabled(campaign.brand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func applySchedule() {
        switch scheduleType {
        case .oneTime: campaign.schedule = .oneTime(scheduleDate)
        case .monthly: campaign.schedule = .monthlyRecurring(day: scheduleDay)
        case .ongoing: campaign.schedule = .ongoing
        }
    }

    @ViewBuilder
    private func handleSection(
        title: String,
        icon: String,
        accent: Color,
        handles: Binding<[String]>,
        new: Binding<String>,
        placeholder: String
    ) -> some View {
        Section {
            ForEach(handles.wrappedValue.indices, id: \.self) { i in
                HStack {
                    Image(systemName: icon).foregroundStyle(accent)
                    TextField(placeholder, text: Binding(
                        get: { handles.wrappedValue[i] },
                        set: { handles.wrappedValue[i] = $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            }
            .onDelete { idx in
                handles.wrappedValue.remove(atOffsets: idx)
            }
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(accent)
                TextField(placeholder, text: new)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addHandle(handles: handles, new: new) }
                Button("Add") { addHandle(handles: handles, new: new) }
                    .buttonStyle(.bordered)
                    .disabled(new.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Label(title, systemImage: icon)
        } footer: {
            Text("Add as many \(title.lowercased()) as belong to this campaign.")
        }
    }

    private func addHandle(handles: Binding<[String]>, new: Binding<String>) {
        let trimmed = new.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        handles.wrappedValue.append(trimmed)
        new.wrappedValue = ""
    }
}

// MARK: - Reusable bits

struct StudioPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 24))
    }
}

struct StudioBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.02, green: 0.025, blue: 0.04), Color(red: 0.05, green: 0.03, blue: 0.07)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct StatPill: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack { Text(value).bold(); Text(title).font(.caption2) }
            .frame(maxWidth: .infinity).padding(10)
            .background(color.opacity(0.15), in: .rect(cornerRadius: 16))
    }
}

struct PlatformChip: View {
    let platform: String
    var body: some View {
        Text(platform).font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.white.opacity(0.09), in: .capsule)
    }
}

struct VideoRow: View {
    let video: UGCVideo
    var body: some View {
        HStack {
            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(.pink)
            VStack(alignment: .leading) {
                Text(video.title).bold()
                Text("\(video.date.formatted(.dateTime.month().day().hour().minute())) • \(video.durationLabel)")
                    .font(.caption).foregroundStyle(.secondary)
                if video.views > 0 || video.likes > 0 {
                    Text("\(video.views.formatted()) views • \(video.likes.formatted()) likes • \(video.comments) comments")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
    }
}

struct MetricTile: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.16), in: .rect(cornerRadius: 20))
    }
}

struct MetricChip: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 10))
    }
}

struct EmptyStateView: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.cyan)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white.opacity(0.04), in: .rect(cornerRadius: 24))
    }
}

#Preview { ContentView() }
