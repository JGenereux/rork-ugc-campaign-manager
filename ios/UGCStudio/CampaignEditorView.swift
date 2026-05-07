import SwiftUI

struct CampaignEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var campaign: Campaign
    @State private var scheduleType: ScheduleType
    @State private var scheduleDate: Date
    @State private var scheduleDay: Int
    @State private var targetText: String
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
        _targetText = State(initialValue: "\(c.targetVideoCount)")
        self.onSave = onSave
        self.isNew = initial == nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section(title: "Campaign") {
                            VStack(spacing: 0) {
                                fieldRow(label: "Brand") {
                                    TextField("Brand name", text: $campaign.brand)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(Palette.textPrimary)
                                }
                                fieldRow(label: "Title") {
                                    TextField("Campaign title", text: $campaign.title)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(Palette.textPrimary)
                                }
                                fieldRow(label: "Status") {
                                    Picker("", selection: $campaign.status) {
                                        ForEach(CampaignStatus.allCases) { s in
                                            Text(s.label).tag(s)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .tint(campaign.status.color)
                                }
                                fieldRow(label: "Target videos") {
                                    HStack(spacing: 6) {
                                        TextField("e.g. 30", text: $targetText)
                                            .textFieldStyle(.plain)
                                            .foregroundStyle(Palette.textPrimary)
                                            .font(TypeScale.mono(15, weight: .medium))
                                            .keyboardType(.numberPad)
                                            .onChange(of: targetText) { _, new in
                                                let digits = new.filter(\.isNumber)
                                                if digits != new { targetText = digits }
                                                if let n = Int(digits) { campaign.targetVideoCount = max(1, min(999, n)) }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        StepperButton(symbol: "minus") {
                                            let n = max(1, (Int(targetText) ?? 1) - 1)
                                            targetText = "\(n)"
                                            campaign.targetVideoCount = n
                                        }
                                        StepperButton(symbol: "plus") {
                                            let n = min(999, (Int(targetText) ?? 1) + 1)
                                            targetText = "\(n)"
                                            campaign.targetVideoCount = n
                                        }
                                    }
                                }
                                fieldRow(label: "Accent", isLast: true) {
                                    HStack(spacing: 8) {
                                        ForEach(AccentPalette.allCases) { p in
                                            Button {
                                                campaign.accent = p
                                            } label: {
                                                Circle()
                                                    .fill(p.color)
                                                    .frame(width: 22, height: 22)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(campaign.accent == p ? Palette.textPrimary : .clear, lineWidth: 1.5)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        section(title: "Schedule") {
                            VStack(spacing: 0) {
                                fieldRow(label: "Type") {
                                    Picker("", selection: $scheduleType) {
                                        ForEach(ScheduleType.allCases) { Text($0.rawValue).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                switch scheduleType {
                                case .oneTime:
                                    fieldRow(label: "Due date", isLast: true) {
                                        DatePicker("", selection: $scheduleDate, displayedComponents: .date)
                                            .labelsHidden()
                                            .colorScheme(.dark)
                                    }
                                case .monthly:
                                    fieldRow(label: "Day of month", isLast: true) {
                                        HStack(spacing: 6) {
                                            Text("\(scheduleDay)")
                                                .font(TypeScale.mono(15, weight: .medium))
                                                .foregroundStyle(Palette.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            StepperButton(symbol: "minus") {
                                                scheduleDay = max(1, scheduleDay - 1)
                                            }
                                            StepperButton(symbol: "plus") {
                                                scheduleDay = min(28, scheduleDay + 1)
                                            }
                                        }
                                    }
                                case .ongoing:
                                    fieldRow(label: "", isLast: true) {
                                        Text("No fixed deadline. Record continuously.")
                                            .font(TypeScale.body(12))
                                            .foregroundStyle(Palette.textTertiary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        handleSection(
                            title: "Instagram",
                            accent: Palette.pInstagram,
                            handles: $campaign.instagramHandles,
                            new: $newIG,
                            placeholder: "@brand"
                        )

                        handleSection(
                            title: "TikTok",
                            accent: Palette.pTikTok,
                            handles: $campaign.tiktokHandles,
                            new: $newTT,
                            placeholder: "@brand.co"
                        )

                        handleSection(
                            title: "YouTube",
                            accent: Palette.pYouTube,
                            handles: $campaign.youtubeHandles,
                            new: $newYT,
                            placeholder: "@brand"
                        )
                    }
                    .padding(14)
                }
            }
            .navigationTitle(isNew ? "New Campaign" : "Edit Campaign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        applySchedule()
                        if let n = Int(targetText) { campaign.targetVideoCount = max(1, n) }
                        onSave(campaign)
                        dismiss()
                    } label: { Text("Save").bold() }
                    .foregroundStyle(Palette.signalBlue)
                    .disabled(campaign.brand.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            CapsLabel(text: title)
            Hairline()
            content()
        }
    }

    @ViewBuilder
    private func fieldRow<C: View>(label: String, isLast: Bool = false, @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label.uppercased())
                .font(TypeScale.caps(9))
                .tracking(1.4)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 110, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Palette.surface)
        .overlay(
            VStack(spacing: 0) {
                Spacer()
                if !isLast { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
            }
        )
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
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
        accent: Color,
        handles: Binding<[String]>,
        new: Binding<String>,
        placeholder: String
    ) -> some View {
        section(title: "\(title) Accounts") {
            VStack(spacing: 0) {
                if handles.wrappedValue.isEmpty {
                    fieldRow(label: title) {
                        Text("None connected")
                            .font(TypeScale.body(12))
                            .foregroundStyle(Palette.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(handles.wrappedValue.indices, id: \.self) { i in
                        fieldRow(label: "@\(i+1)") {
                            HStack(spacing: 6) {
                                TextField(placeholder, text: Binding(
                                    get: { handles.wrappedValue[i] },
                                    set: { handles.wrappedValue[i] = $0 }
                                ))
                                .textFieldStyle(.plain)
                                .foregroundStyle(Palette.textPrimary)
                                .font(TypeScale.mono(13))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                Button {
                                    handles.wrappedValue.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Palette.signalRed)
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                fieldRow(label: "Add", isLast: true) {
                    HStack(spacing: 6) {
                        TextField(placeholder, text: new)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Palette.textPrimary)
                            .font(TypeScale.mono(13))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { addHandle(handles: handles, new: new) }
                        Button {
                            addHandle(handles: handles, new: new)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 28, height: 28)
                                .background(accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(new.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(new.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                    }
                }
            }
        }
    }

    private func addHandle(handles: Binding<[String]>, new: Binding<String>) {
        let trimmed = new.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        handles.wrappedValue.append(trimmed)
        new.wrappedValue = ""
    }
}

struct StepperButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 28, height: 28)
                .background(Palette.surfaceHi)
                .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
