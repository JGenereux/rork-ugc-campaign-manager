import SwiftUI

// MARK: - Palette

enum Palette {
    // Surface
    static let bg          = Color(red: 0.039, green: 0.043, blue: 0.051)   // #0A0B0D
    static let surface     = Color(red: 0.067, green: 0.075, blue: 0.102)   // #11131A
    static let surfaceHi   = Color(red: 0.086, green: 0.098, blue: 0.133)   // #161922
    static let surfaceLow  = Color(red: 0.051, green: 0.059, blue: 0.078)   // #0D0F14

    // Lines
    static let hairline    = Color(red: 0.133, green: 0.145, blue: 0.173)   // #22252C
    static let hairlineHi  = Color(red: 0.20,  green: 0.22,  blue: 0.26)    // ~#333944

    // Type
    static let textPrimary   = Color(red: 0.910, green: 0.918, blue: 0.937) // #E8EAEF
    static let textSecondary = Color(red: 0.478, green: 0.510, blue: 0.561) // #7A828F
    static let textTertiary  = Color(red: 0.290, green: 0.322, blue: 0.376) // #4A5260

    // Signals
    static let signalBlue   = Color(red: 0.282, green: 0.686, blue: 0.941) // #48AFF0
    static let signalAmber  = Color(red: 1.000, green: 0.710, blue: 0.278) // #FFB547
    static let signalRed    = Color(red: 0.961, green: 0.337, blue: 0.337) // #F55656
    static let signalGreen  = Color(red: 0.478, green: 0.761, blue: 0.353) // #7AC25A
    static let signalViolet = Color(red: 0.671, green: 0.498, blue: 0.961) // #AB7FF5
    static let signalCyan   = Color(red: 0.290, green: 0.812, blue: 0.831) // #4ACFD4

    // Platforms (demoted, used only for small marks)
    static let pInstagram = Color(red: 0.91, green: 0.36, blue: 0.55)
    static let pTikTok    = Color(red: 0.29, green: 0.81, blue: 0.83)
    static let pYouTube   = Color(red: 0.93, green: 0.30, blue: 0.30)
}

// MARK: - Typography

enum TypeScale {
    static func display(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func title(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    static func body(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func caps(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Reusable atoms

struct AppBackground: View {
    var body: some View {
        Palette.bg.ignoresSafeArea()
    }
}

struct Hairline: View {
    var color: Color = Palette.hairline
    var body: some View {
        Rectangle().fill(color).frame(height: 0.5).frame(maxWidth: .infinity)
    }
}

struct CapsLabel: View {
    let text: String
    var color: Color = Palette.textSecondary
    var size: CGFloat = 10
    var body: some View {
        Text(text.uppercased())
            .font(TypeScale.caps(size))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 8
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 2).blur(radius: 2))
    }
}

/// Section block: small caps header + hairline rule + content. No card background.
struct DataSection<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                CapsLabel(text: title)
                Spacer()
                trailing
            }
            Hairline()
            content
        }
    }
}

/// Flat dark surface with a hairline border. Sharp corners.
struct Panel<Content: View>: View {
    var padding: CGFloat = 14
    var corner: CGFloat = 4
    var fill: Color = Palette.surface
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(fill)
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Palette.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: corner))
    }
}

/// Two-column metric cell: small caps label over a mono value.
struct MetricCell: View {
    let label: String
    let value: String
    var valueColor: Color = Palette.textPrimary
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            CapsLabel(text: label, color: Palette.textTertiary, size: 9)
            Text(value)
                .font(TypeScale.mono(15, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center))
    }
}

/// Small uppercase mono pill — used for status, platform marks.
struct MonoChip: View {
    let text: String
    var color: Color = Palette.textSecondary
    var bg: Color = Palette.surfaceHi

    var body: some View {
        Text(text.uppercased())
            .font(TypeScale.caps(9))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 2).stroke(color.opacity(0.35), lineWidth: 0.5)
            )
    }
}

/// Bracketed mono number — like "[ 12 ]". Use sparingly for IDs.
struct IndexBadge: View {
    let n: Int
    var body: some View {
        Text(String(format: "%02d", n))
            .font(TypeScale.mono(11, weight: .medium))
            .foregroundStyle(Palette.textTertiary)
            .frame(width: 28, alignment: .trailing)
    }
}

/// Thin progress bar (1pt) for the bottom edge of cards.
struct EdgeProgress: View {
    let value: Double          // 0...1
    var color: Color = Palette.signalBlue

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.hairline)
                Rectangle().fill(color)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 2)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Palette.signalBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased()).tracking(1.2)
            }
            .font(TypeScale.caps(11))
            .foregroundStyle(.black)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(color)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title.uppercased()).tracking(1.2)
            }
            .font(TypeScale.caps(11))
            .foregroundStyle(color)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().stroke(color.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared formatting

enum Fmt {
    static func compact(_ n: Int) -> String {
        n.formatted(.number.notation(.compactName))
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM-dd"
        return f.string(from: d).uppercased()
    }
    static func dateLong(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM dd, yyyy"
        return f.string(from: d)
    }
    static func duration(_ s: Double) -> String {
        let total = Int(s.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Platform helpers

enum PlatformName {
    static let instagram = "Instagram"
    static let tiktok    = "TikTok"
    static let youtube   = "YouTube"
    static let all = [instagram, tiktok, youtube]

    static func code(_ name: String) -> String {
        switch name.lowercased() {
        case "instagram": return "IG"
        case "tiktok":    return "TT"
        case "youtube":   return "YT"
        default:          return name.prefix(2).uppercased()
        }
    }

    static func color(_ name: String) -> Color {
        switch name.lowercased() {
        case "instagram": return Palette.pInstagram
        case "tiktok":    return Palette.pTikTok
        case "youtube":   return Palette.pYouTube
        default:          return Palette.textSecondary
        }
    }

    static func icon(_ name: String) -> String {
        switch name.lowercased() {
        case "instagram": return "camera.aperture"
        case "tiktok":    return "music.note"
        case "youtube":   return "play.rectangle.fill"
        default:          return "person.crop.circle"
        }
    }
}

extension Color {
    static let appBg          = Palette.bg
    static let appSurface     = Palette.surface
    static let appHairline    = Palette.hairline
    static let appText        = Palette.textPrimary
    static let appTextDim     = Palette.textSecondary
    static let appAccent      = Palette.signalBlue
}
