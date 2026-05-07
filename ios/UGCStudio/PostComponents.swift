import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Post card (compact, thumbnail + metrics)

struct PostCard: View {
    let post: SocialPost

    var body: some View {
        Button {
            if let s = post.postURL, let url = URL(string: s) {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Palette.surfaceLow)
                        .aspectRatio(9.0/16.0, contentMode: .fit)
                    if let s = post.thumbnailURL, let url = URL(string: s) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                ProgressView().tint(Palette.signalBlue)
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Palette.textTertiary)
                            @unknown default:
                                Color.clear
                            }
                        }
                        .aspectRatio(9.0/16.0, contentMode: .fit)
                        .clipped()
                    } else {
                        Image(systemName: PlatformName.icon(post.platform))
                            .font(.system(size: 28))
                            .foregroundStyle(Palette.textTertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    HStack {
                        MonoChip(
                            text: PlatformName.code(post.platform),
                            color: PlatformName.color(post.platform),
                            bg: .black.opacity(0.65)
                        )
                        Spacer()
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(post.caption.isEmpty ? "—" : post.caption)
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        MetricCell(label: "Views", value: Fmt.compact(post.views))
                        MetricCell(label: "Likes", value: Fmt.compact(post.likes))
                        MetricCell(label: "Date", value: post.dateLabel)
                    }
                }
                .padding(10)
            }
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Horizontal feed of posts

struct PostsFeed: View {
    let posts: [SocialPost]

    var body: some View {
        if posts.isEmpty {
            HStack {
                Text("No posts cached yet. Pull to refresh.")
                    .font(TypeScale.body(12))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 12)
            }
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(posts) { post in
                        PostCard(post: post).frame(width: 180)
                    }
                }
            }
        }
    }
}

// MARK: - Top posts tile (insights)

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
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 28, alignment: .trailing)

                ZStack {
                    Rectangle().fill(Palette.surfaceLow).frame(width: 44, height: 56)
                    if let s = post.thumbnailURL, let url = URL(string: s) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase { img.resizable().scaledToFill() }
                            else { Color.clear }
                        }
                        .frame(width: 44, height: 56)
                        .clipped()
                    } else {
                        Image(systemName: PlatformName.icon(post.platform))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .overlay(Rectangle().stroke(Palette.hairline, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        MonoChip(text: PlatformName.code(post.platform), color: PlatformName.color(post.platform), bg: Palette.surfaceHi)
                        Text("@\(post.handle)")
                            .font(TypeScale.mono(11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Text(post.caption.isEmpty ? "—" : post.caption)
                        .font(TypeScale.body(12))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.compact(post.views))
                        .font(TypeScale.mono(13, weight: .semibold))
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
}
