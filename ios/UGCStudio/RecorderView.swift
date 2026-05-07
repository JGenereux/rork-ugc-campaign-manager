import SwiftUI
import AVFoundation
import UIKit

struct RecorderView: View {
    @Bindable var store: CampaignStore
    var lockedCampaignID: UUID? = nil

    @State private var recorder = CameraRecorder()
    @State private var assignSheetURL: URL?
    @State private var assignSheetDuration: Double = 0

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                headerStrip
                preview
                if let id = lockedCampaignID,
                   let campaign = store.campaigns.first(where: { $0.id == id }) {
                    lockedBadge(campaign: campaign)
                }
                controls
            }
            .padding(14)
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

    // MARK: - Header

    private var headerStrip: some View {
        HStack {
            CapsLabel(text: lockedCampaignID == nil ? "Free record" : "Campaign-bound", color: Palette.textSecondary)
            Spacer()
            if recorder.isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Palette.signalRed).frame(width: 8, height: 8)
                    Text(formatTime(recorder.elapsed))
                        .font(TypeScale.mono(13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.textPrimary)
                }
            } else {
                Text("READY")
                    .font(TypeScale.caps(10))
                    .tracking(1.5)
                    .foregroundStyle(Palette.signalGreen)
            }
        }
    }

    // MARK: - Preview

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if recorder.permissionDenied {
                placeholder("Camera or microphone permission denied. Enable both in Settings to record.", icon: "lock.shield.fill")
            } else if !recorder.isConfigured {
                placeholder("Preparing camera...", icon: "video.fill")
            } else {
                CameraPreview(session: recorder.session)
                    .overlay(alignment: .topTrailing) {
                        Button { recorder.flip() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(10)
                                .background(.black.opacity(0.55))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    .overlay(alignment: .topLeading) {
                        if recorder.isRecording {
                            HStack(spacing: 6) {
                                Circle().fill(Palette.signalRed).frame(width: 8, height: 8)
                                Text(formatTime(recorder.elapsed))
                                    .font(TypeScale.mono(11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.black.opacity(0.6))
                            .padding(10)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 480)
        .background(Color.black)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private func placeholder(_ text: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Palette.signalBlue)
            Text(text)
                .multilineTextAlignment(.center)
                .font(TypeScale.body(12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal)
            if recorder.permissionDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(TypeScale.caps(11))
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.signalBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Locked badge

    private func lockedBadge(campaign: Campaign) -> some View {
        HStack(spacing: 10) {
            StatusDot(color: campaign.status.color)
            VStack(alignment: .leading, spacing: 2) {
                CapsLabel(text: "Saving to", color: Palette.textTertiary, size: 9)
                Text(campaign.brand)
                    .font(TypeScale.title(14))
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            Text("\(campaign.videos.count)/\(campaign.targetVideoCount) takes")
                .font(TypeScale.mono(12))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 6) {
            Button { handleTap() } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Palette.signalRed : Palette.signalAmber)
                        .frame(width: 84, height: 84)
                    if recorder.isRecording {
                        Rectangle().fill(.white).frame(width: 28, height: 28)
                    } else {
                        Circle().stroke(.black, lineWidth: 4).frame(width: 60, height: 60)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!recorder.isConfigured && !recorder.isRecording)
            .opacity(recorder.isConfigured || recorder.isRecording ? 1 : 0.4)

            Text(recorder.isRecording ? "TAP TO STOP" : "TAP TO RECORD")
                .font(TypeScale.caps(10))
                .tracking(1.5)
                .foregroundStyle(Palette.textTertiary)
        }
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
            let video = UGCVideo(
                id: UUID(),
                title: title,
                date: Date(),
                durationSeconds: duration,
                fileName: fileName,
                views: 0, likes: 0, comments: 0,
                postedURL: nil, notes: nil
            )
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

// MARK: - Assign sheet

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
                AppBackground()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapsLabel(text: "New take · \(Int(duration.rounded()))s", color: Palette.textSecondary)
                        Text("Assign to a campaign")
                            .font(TypeScale.display(24))
                            .foregroundStyle(Palette.textPrimary)
                    }

                    if store.campaigns.isEmpty {
                        Text("No campaigns yet. Create one first, then re-record.")
                            .font(TypeScale.body(13))
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(store.campaigns) { campaign in
                                    Button { selected = campaign.id } label: {
                                        HStack(spacing: 10) {
                                            StatusDot(color: campaign.status.color)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(campaign.brand)
                                                    .font(TypeScale.title(14))
                                                    .foregroundStyle(Palette.textPrimary)
                                                Text(campaign.title.isEmpty ? "(no title)" : campaign.title)
                                                    .font(TypeScale.body(11))
                                                    .foregroundStyle(Palette.textTertiary)
                                            }
                                            Spacer()
                                            if selected == campaign.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(Palette.signalBlue)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Palette.surface)
                                        .overlay(
                                            Rectangle().stroke(
                                                selected == campaign.id ? Palette.signalBlue : Palette.hairline,
                                                lineWidth: selected == campaign.id ? 1 : 0.5
                                            )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Spacer()
                    PrimaryButton(title: "Save take", systemImage: "checkmark") {
                        save()
                    }
                    .opacity(selected == nil ? 0.4 : 1)
                    .disabled(selected == nil)
                }
                .padding(14)
            }
            .navigationTitle("Save take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        try? FileManager.default.removeItem(at: fileURL)
                        dismiss()
                    }
                    .foregroundStyle(Palette.signalRed)
                }
            }
            .onAppear { selected = presetCampaignID ?? store.campaigns.first?.id }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard let cid = selected else { return }
        let fileName = "take-\(UUID().uuidString).mov"
        let destination = URL.documentsDirectory.appending(path: fileName)
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: fileURL, to: destination)
        let count = store.campaigns.first(where: { $0.id == cid })?.videos.count ?? 0
        let video = UGCVideo(
            id: UUID(),
            title: "Take \(count + 1)",
            date: Date(),
            durationSeconds: duration,
            fileName: fileName,
            views: 0, likes: 0, comments: 0,
            postedURL: nil, notes: nil
        )
        store.addVideo(video, toCampaign: cid)
        dismiss()
    }
}
