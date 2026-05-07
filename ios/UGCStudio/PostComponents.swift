import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Top live post row

struct TopPostRow: View {
    let post: SocialPost
    let rank: Int

    var body: some View {
        Button {
            if let s = post.postURL, let url = URL(string: s) {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(String(format: "%02d", rank))
                    .font(TypeScale.mono(11, weight: .medium))
                    .foregroundStyle(rank <= 3 ? Palette.signalAmber : Palette.textTertiary)
                    .frame(width: 28, alignment: .trailing)

                ZStack {
                    Rectangle().fill(Palette.surfaceLow).frame(width: 44, height: 60)
                    if let s = post.thumbnailURL, let url = URL(string: s) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 44, height: 60)
                        .clipped()
                    } else {
                        Image(systemName: PlatformName.icon(post.platform))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        MonoChip(
                            text: PlatformName.code(post.platform),
                            color: PlatformName.color(post.platform),
                            bg: Palette.surfaceHi
                        )
                        Text("@\(post.handle)")
                            .font(TypeScale.mono(11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    Text(post.caption.isEmpty ? "—" : post.caption)
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        miniMetric(value: Fmt.compact(post.likes), icon: "heart.fill", color: Palette.signalGreen)
                        miniMetric(value: Fmt.compact(post.comments), icon: "bubble.right.fill", color: Palette.signalViolet)
                        Text(post.dateLabel)
                            .font(TypeScale.mono(10))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.compact(post.views))
                        .font(TypeScale.mono(15, weight: .semibold))
                        .foregroundStyle(Palette.signalBlue)
                    Text("VIEWS")
                        .font(TypeScale.caps(8))
                        .tracking(1.2)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(Palette.surface)
        .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
    }

    private func miniMetric(value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(TypeScale.mono(10, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
