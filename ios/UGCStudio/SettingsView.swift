import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apifyToken: String = TokenStore.apifyToken
    @State private var openAIToken: String = TokenStore.openAIToken
    @State private var savedFlash: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro

                        DataSection(
                            title: "Apify · social scraping",
                            trailing: AnyView(envBadge(isBundled: !Config.EXPO_PUBLIC_APIFY_TOKEN.isEmpty))
                        ) {
                            tokenField(
                                placeholder: "apify_api_...",
                                value: $apifyToken,
                                helper: "If `EXPO_PUBLIC_APIFY_TOKEN` is set on Rork, the app uses that automatically. The field below overrides it on this device only.",
                                masked: false
                            )
                        }

                        DataSection(
                            title: "OpenAI · script generation",
                            trailing: AnyView(envBadge(isBundled: !Config.EXPO_PUBLIC_OPENAI_API_KEY.isEmpty))
                        ) {
                            tokenField(
                                placeholder: "sk-...",
                                value: $openAIToken,
                                helper: "If `EXPO_PUBLIC_OPENAI_API_KEY` is set on Rork, the app uses that automatically. Generates UGC scripts via gpt-4o-mini (~$0.0001 per script). The field below overrides it on this device only.",
                                masked: true
                            )
                        }

                        DataSection(title: "Storage") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Campaigns are stored locally on this device. Recorded takes live in the app's Documents folder. Apify responses are cached on disk to avoid re-billing.")
                                    .font(TypeScale.body(12))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .padding(12)
                            .background(Palette.surface)
                            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
                        }

                        Spacer().frame(height: 12)
                    }
                    .padding(14)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        TokenStore.setApifyToken(apifyToken)
                        TokenStore.setOpenAIToken(openAIToken)
                        withAnimation(.easeOut(duration: 0.2)) { savedFlash = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation { savedFlash = false }
                            dismiss()
                        }
                    } label: {
                        Text(savedFlash ? "Saved ✓" : "Save").bold()
                    }
                    .foregroundStyle(savedFlash ? Palette.signalGreen : Palette.signalBlue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            CapsLabel(text: "API access")
            Text("Connect your services")
                .font(TypeScale.display(28))
                .foregroundStyle(Palette.textPrimary)
            Text("Both keys are optional — the app works fully offline without them. Apify enables live social data; OpenAI enables script generation.")
                .font(TypeScale.body(13))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func envBadge(isBundled: Bool) -> some View {
        MonoChip(
            text: isBundled ? "Env: bundled" : "Settings only",
            color: isBundled ? Palette.signalGreen : Palette.textTertiary,
            bg: Palette.surface
        )
    }

    private func tokenField(placeholder: String, value: Binding<String>, helper: String, masked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if masked {
                    SecureField(placeholder, text: value)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: value)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .textFieldStyle(.plain)
            .font(TypeScale.mono(13))
            .foregroundStyle(Palette.textPrimary)
            .padding(12)
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))

            Text(helper)
                .font(TypeScale.body(11))
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
