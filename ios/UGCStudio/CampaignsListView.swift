import SwiftUI

// MARK: - Filter type

enum CampaignFilter: String, CaseIterable, Identifiable {
    case all, active, posted, archived
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .posted: return "Posted"
        case .archived: return "Archived"
        }
    }
}

enum CampaignSort: String, CaseIterable, Identifiable {
    case dueAsc, progressDesc, recent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dueAsc: return "Due"
        case .progressDesc: return "Progress"
        case .recent: return "Recent"
        }
    }
}

// MARK: - Campaigns list

struct CampaignsListView: View {
    @Bindable var store: CampaignStore
    @Binding var showingEditor: Bool
    @Binding var editingCampaign: Campaign?
    @Binding var showingSettings: Bool

    @State private var query: String = ""
    @State private var filter: CampaignFilter = .all
    @State private var sort: CampaignSort = .recent
    @State private var pendingDeleteID: UUID?

    private var filtered: [Campaign] {
        var list = store.campaigns
        switch filter {
        case .all: break
        case .active:
            list = list.filter { $0.status != .archived && $0.status != .paid }
        case .posted:
            list = list.filter { $0.status == .posted || $0.status == .paid }
        case .archived:
            list = list.filter { $0.status == .archived }
        }
        if !query.isEmpty {
            list = list.filter {
                $0.brand.localizedCaseInsensitiveContains(query) ||
                $0.title.localizedCaseInsensitiveContains(query)
            }
        }
        switch sort {
        case .dueAsc:
            list.sort { dueValue($0) < dueValue($1) }
        case .progressDesc:
            list.sort { $0.videoProgress > $1.videoProgress }
        case .recent:
            list.sort { $0.createdAt > $1.createdAt }
        }
        return list
    }

    private func dueValue(_ c: Campaign) -> TimeInterval {
        switch c.schedule {
        case .oneTime(let d): return d.timeIntervalSince1970
        case .monthlyRecurring: return Date().timeIntervalSince1970
        case .ongoing: return .greatestFiniteMagnitude
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statsBar
                    controlBar
                    if store.campaigns.isEmpty {
                        emptyState
                    } else if filtered.isEmpty {
                        Text("No campaigns match the current filter.")
                            .font(TypeScale.body(13))
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.top, 16)
                    } else {
                        VStack(spacing: 10) {
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
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 32)
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
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCampaign = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .confirmationDialog(
            "Delete this campaign?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID { store.delete(id) }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("All recorded takes will also be removed.")
        }
    }

    // MARK: header / stats / control bar

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: "UGC Studio · v1")
            Text("Campaign Console")
                .font(TypeScale.display(34))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private var statsBar: some View {
        let totalTakes = store.campaigns.flatMap(\.videos).count
        let posted = store.campaigns.flatMap(\.videos).filter { $0.isPosted }.count
        let target = store.campaigns.reduce(0) { $0 + $1.targetVideoCount }
        return HStack(spacing: 0) {
            MetricCell(label: "Campaigns", value: "\(store.campaigns.count)")
            verticalRule
            MetricCell(label: "Takes", value: "\(totalTakes)")
            verticalRule
            MetricCell(label: "Posted", value: "\(posted)")
            verticalRule
            MetricCell(label: "Target", value: "\(target)")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private var verticalRule: some View {
        Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 32)
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(CampaignFilter.allCases) { f in
                        FilterChip(label: f.label, selected: filter == f) { filter = f }
                    }
                    Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 18).padding(.horizontal, 4)
                    ForEach(CampaignSort.allCases) { s in
                        FilterChip(
                            label: "↓ \(s.label)",
                            selected: sort == s,
                            color: Palette.signalAmber
                        ) { sort = s }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Palette.textSecondary)
            Text("No campaigns yet")
                .font(TypeScale.title(15))
                .foregroundStyle(Palette.textPrimary)
            Text("Tap + to add your first brand campaign.")
                .font(TypeScale.body(12))
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let label: String
    let selected: Bool
    var color: Color = Palette.signalBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(TypeScale.caps(10))
                .tracking(1.2)
                .foregroundStyle(selected ? .black : Palette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? color : Palette.surface)
                .overlay(Rectangle().stroke(selected ? .clear : Palette.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Campaign card

struct CampaignCard: View {
    let campaign: Campaign

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top, spacing: 10) {
                StatusDot(color: campaign.status.color)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(campaign.brand.isEmpty ? "Untitled brand" : campaign.brand)
                        .font(TypeScale.title(16))
                        .foregroundStyle(Palette.textPrimary)
                    Text(campaign.title.isEmpty ? "(no campaign title)" : campaign.title)
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                MonoChip(text: campaign.status.code, color: campaign.status.color, bg: campaign.status.color.opacity(0.12))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Hairline()

            // Metrics row
            HStack(spacing: 0) {
                MetricCell(label: "Takes", value: "\(campaign.videos.count)/\(campaign.targetVideoCount)")
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 30)
                MetricCell(label: "Platforms", value: platformsLabel)
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 30)
                MetricCell(label: "Due", value: campaign.schedule.shortLabel)
                Rectangle().fill(Palette.hairline).frame(width: 0.5, height: 30)
                MetricCell(label: "Progress", value: percentLabel, valueColor: campaign.status.color)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)

            // Edge progress
            EdgeProgress(value: campaign.videoProgress, color: campaign.status.color)
        }
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private var platformsLabel: String {
        let codes = campaign.allPlatforms.map { PlatformName.code($0) }
        return codes.isEmpty ? "—" : codes.joined(separator: "·")
    }

    private var percentLabel: String {
        let pct = Int((campaign.videoProgress * 100).rounded())
        return "\(pct)%"
    }
}
