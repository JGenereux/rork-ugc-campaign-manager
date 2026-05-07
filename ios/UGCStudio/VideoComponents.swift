import SwiftUI
import AVKit
import Photos

// MARK: - Video row

struct VideoRow: View {
    @Bindable var store: CampaignStore
    let campaignID: UUID
    let video: UGCVideo
    let index: Int

    @State private var editingTitle: Bool = false
    @State private var draftTitle: String = ""
    @State private var showingPlayer: Bool = false
    @State private var showingPostedEditor: Bool = false
    @State private var showingExportError: String?
    @State private var saveResultMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                IndexBadge(n: index)

                Button {
                    if video.fileURL != nil { showingPlayer = true }
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(Palette.surfaceLow)
                            .frame(width: 44, height: 44)
                        Image(systemName: video.fileURL != nil ? "play.fill" : "video.slash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(video.fileURL != nil ? Palette.signalBlue : Palette.textTertiary)
                    }
                    .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .disabled(video.fileURL == nil)

                VStack(alignment: .leading, spacing: 4) {
                    if editingTitle {
                        TextField("Take name", text: $draftTitle)
                            .font(TypeScale.title(14))
                            .foregroundStyle(Palette.textPrimary)
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit { commitTitle() }
                    } else {
                        Text(displayTitle)
                            .font(TypeScale.title(14))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 10) {
                        Text(Fmt.date(video.date))
                            .font(TypeScale.mono(10))
                            .foregroundStyle(Palette.textTertiary)
                        Text(video.durationLabel)
                            .font(TypeScale.mono(10))
                            .foregroundStyle(Palette.textTertiary)
                        if video.isPosted {
                            MonoChip(text: "POSTED", color: Palette.signalGreen, bg: Palette.signalGreen.opacity(0.1))
                        }
                    }
                }

                Spacer()

                if video.views > 0 || video.likes > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Fmt.compact(video.views))
                            .font(TypeScale.mono(13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("VIEWS")
                            .font(TypeScale.caps(8))
                            .tracking(1.2)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }

                Menu {
                    Button {
                        draftTitle = video.title
                        editingTitle = true
                    } label: { Label("Rename", systemImage: "pencil") }

                    Button {
                        showingPostedEditor = true
                    } label: { Label(video.isPosted ? "Edit posted URL" : "Mark as posted…", systemImage: "link") }

                    if let url = video.fileURL {
                        ShareLink(item: url) {
                            Label("Share / Export to CapCut…", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            saveToPhotos(url: url)
                        } label: { Label("Save to Photos", systemImage: "photo.on.rectangle.angled") }
                    }

                    Divider()

                    Button(role: .destructive) {
                        store.deleteVideo(videoID: video.id, fromCampaign: campaignID)
                    } label: { Label("Delete take", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Palette.surfaceLow)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        .sheet(isPresented: $showingPlayer) {
            if let url = video.fileURL {
                VideoPlayerSheet(url: url, title: video.title)
            }
        }
        .sheet(isPresented: $showingPostedEditor) {
            PostedURLEditorSheet(
                store: store,
                campaignID: campaignID,
                video: video
            )
            .presentationDetents([.medium])
        }
        .alert("Save failed", isPresented: Binding(
            get: { showingExportError != nil },
            set: { if !$0 { showingExportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(showingExportError ?? "") }
        .alert(saveResultMessage ?? "", isPresented: Binding(
            get: { saveResultMessage != nil },
            set: { if !$0 { saveResultMessage = nil } }
        )) { Button("OK", role: .cancel) {} }
    }

    private var displayTitle: String {
        let trimmed = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "Take #\(index)"
    }

    private func commitTitle() {
        store.renameVideo(videoID: video.id, in: campaignID, to: draftTitle)
        editingTitle = false
    }

    private func saveToPhotos(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    showingExportError = "Photos permission denied. Enable in Settings."
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                } completionHandler: { ok, err in
                    DispatchQueue.main.async {
                        if ok {
                            saveResultMessage = "Saved to Photos."
                        } else {
                            showingExportError = err?.localizedDescription ?? "Save failed."
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Video player sheet

struct VideoPlayerSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(spacing: 12) {
                    if let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
                    } else {
                        ProgressView().tint(Palette.signalBlue)
                    }

                    HStack(spacing: 10) {
                        ShareLink(item: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("EXPORT").tracking(1.2)
                            }
                            .font(TypeScale.caps(11))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.signalBlue)
                        }
                        GhostButton(title: "Save to Photos", systemImage: "photo.on.rectangle.angled") {
                            savePhotos()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { player = AVPlayer(url: url) }
        .onDisappear { player?.pause(); player = nil }
    }

    private func savePhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { _, _ in }
        }
    }
}

// MARK: - Posted URL editor

struct PostedURLEditorSheet: View {
    @Bindable var store: CampaignStore
    let campaignID: UUID
    let video: UGCVideo

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var service = ApifyService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    CapsLabel(text: "Posted URL")
                    TextField("https://www.tiktok.com/@brand/video/...", text: $draft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(TypeScale.mono(13))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(12)
                        .background(Palette.surface)
                        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Text("Linking the live URL pulls the post's view / like / comment metrics into this take. Stats refresh whenever you pull-to-refresh on the campaign.")
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textSecondary)

                    if let match = service.post(matchingURL: draft) {
                        DataSection(title: "Matched live post") {
                            HStack(spacing: 12) {
                                MetricCell(label: "Views", value: Fmt.compact(match.views))
                                MetricCell(label: "Likes", value: Fmt.compact(match.likes))
                                MetricCell(label: "Comments", value: Fmt.compact(match.comments))
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        if video.isPosted {
                            GhostButton(title: "Clear", systemImage: "xmark", color: Palette.signalRed) {
                                store.setPostedURL(nil, videoID: video.id, in: campaignID)
                                dismiss()
                            }
                        }
                        PrimaryButton(title: "Save", systemImage: "checkmark") {
                            store.setPostedURL(draft, videoID: video.id, in: campaignID)
                            if let m = service.post(matchingURL: draft) {
                                store.mergePostMetrics(videoID: video.id, in: campaignID, views: m.views, likes: m.likes, comments: m.comments)
                            }
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Mark as posted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { draft = video.postedURL ?? "" }
    }
}
