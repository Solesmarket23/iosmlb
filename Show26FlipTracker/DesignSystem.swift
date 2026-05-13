import SwiftUI
import UIKit

// MARK: - Color Palette

extension Color {
    static let appBG         = Color(red: 0.039, green: 0.043, blue: 0.055)
    static let appSurface    = Color(red: 0.074, green: 0.082, blue: 0.102)
    static let appSurfaceHi  = Color(red: 0.114, green: 0.122, blue: 0.153)
    static let appAccent     = Color(red: 0.0,   green: 0.831, blue: 0.667)
    static let spreadGreen   = Color(red: 0.133, green: 0.773, blue: 0.345)
    static let priceAmber    = Color(red: 0.957, green: 0.620, blue: 0.043)
    static let textSecondary = Color(white: 0.55)
    static let textTertiary  = Color(white: 0.35)
}

// MARK: - Rarity

enum RarityStyle {
    case diamond, gold, silver, bronze, common, unknown

    static func from(_ string: String?) -> RarityStyle {
        switch string?.lowercased() {
        case "diamond": return .diamond
        case "gold":    return .gold
        case "silver":  return .silver
        case "bronze":  return .bronze
        case "common":  return .common
        default:        return .unknown
        }
    }

    var primaryColor: Color {
        switch self {
        case .diamond: return Color(red: 0.404, green: 0.910, blue: 0.973)
        case .gold:    return Color(red: 0.957, green: 0.620, blue: 0.043)
        case .silver:  return Color(red: 0.757, green: 0.812, blue: 0.882)
        case .bronze:  return Color(red: 0.804, green: 0.498, blue: 0.196)
        case .common:  return Color(white: 0.5)
        case .unknown: return Color(white: 0.38)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .diamond:
            return LinearGradient(
                colors: [Color(red: 0.404, green: 0.910, blue: 0.973),
                         Color(red: 0.655, green: 0.545, blue: 0.984)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(
                colors: [Color(red: 0.957, green: 0.620, blue: 0.043),
                         Color(red: 0.980, green: 0.376, blue: 0.235)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .silver:
            return LinearGradient(
                colors: [Color(red: 0.898, green: 0.922, blue: 0.961),
                         Color(red: 0.580, green: 0.631, blue: 0.729)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bronze:
            return LinearGradient(
                colors: [Color(red: 0.804, green: 0.498, blue: 0.196),
                         Color(red: 0.573, green: 0.251, blue: 0.055)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .common:
            return LinearGradient(
                colors: [Color(white: 0.48), Color(white: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unknown:
            return LinearGradient(
                colors: [Color(white: 0.32), Color(white: 0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var label: String {
        switch self {
        case .diamond: return "◆ Diamond"
        case .gold:    return "● Gold"
        case .silver:  return "● Silver"
        case .bronze:  return "● Bronze"
        case .common:  return "● Common"
        case .unknown: return "—"
        }
    }

    var glowColor: Color { primaryColor.opacity(0.18) }
}

// MARK: - Haptics

struct Haptics {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func rigid()     { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()     { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Number Formatting

extension Int {
    var stubsFormatted: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Press Scale Effect

struct PressScaleEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.3),
                            .init(color: Color.white.opacity(0.06), location: 0.5),
                            .init(color: .clear, location: 0.7)
                        ],
                        startPoint: .init(x: phase, y: 0),
                        endPoint: .init(x: phase + 0.5, y: 0)
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
