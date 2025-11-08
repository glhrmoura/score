import AppKit
import CoreText
import SwiftUI

enum Palette {
    static let canvas = dynamic(light: 0xF4F1EA, dark: 0x151516)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let raised = dynamic(light: 0xE9E4D7, dark: 0x262628)
    static let ink = dynamic(light: 0x1B1F3B, dark: 0xEDEDEF)
    static let inkSoft = dynamic(light: 0x585C75, dark: 0xA3A3A8)
    static let inkFaint = dynamic(light: 0x8F8E9C, dark: 0x6C6C72)
    static let rule = dynamic(light: 0xDDD6C6, dark: 0x2B2B2E)
    static let frame = dynamic(light: 0x1B1F3B, dark: 0x3A3A3E)
    static let spine = dynamic(light: 0x1B1F3B, dark: 0x0D0D0E)
    static let spineInk = dynamic(light: 0xF4F1EA, dark: 0xEDEDEF)
    static let pitch = dynamic(light: 0x1F8A7E, dark: 0x3CC2B1)
    static let live = dynamic(light: 0xE63946, dark: 0xFF5A66)
    static let gold = dynamic(light: 0xD9A520, dark: 0xF1C453)
    static let champions = dynamic(light: 0x2F5BD3, dark: 0x7C9BFF)
    static let europa = dynamic(light: 0xDB7410, dark: 0xFFA54A)
    static let conference = dynamic(light: 0x1F8A7E, dark: 0x3CC2B1)
    static let draw = dynamic(light: 0xB4AFA2, dark: 0x5A5A5F)

    static func zone(_ zone: ZoneKind) -> Color {
        switch zone {
        case .champions, .libertadores: champions
        case .libertadoresQualifying: dynamic(light: 0x6C8BEA, dark: 0x9DB4FF)
        case .europa, .sudamericana: europa
        case .conference: conference
        case .relegationPlayoff: dynamic(light: 0xE8A0A8, dark: 0x9C4A55)
        case .relegation: live
        }
    }

    static func outcome(_ outcome: Outcome) -> Color {
        switch outcome {
        case .win: pitch
        case .draw: draw
        case .loss: live
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

enum Typeface {
    static let family = "Score"
    private static let weightAxis = 0x7767_6874
    private static let widthAxis = 0x7764_7468

    static func register() {
        guard let url = Bundle.main.url(forResource: "Score", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "Score", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(_ size: CGFloat, weight: CGFloat, width: CGFloat) -> Font {
        let base = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let varied = CTFontDescriptorCreateCopyWithAttributes(base, [
            kCTFontVariationAttribute: [weightAxis: weight, widthAxis: width],
        ] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(varied, size, nil)
        if (CTFontCopyFamilyName(font) as String) != family {
            return .system(size: size, weight: .bold)
        }
        return Font(font)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: CGFloat = 800) -> Font {
        Typeface.font(size, weight: max(400, weight), width: 100)
    }

    static func ui(_ size: CGFloat, _ weight: CGFloat = 400) -> Font {
        Typeface.font(size, weight: max(400, weight), width: 100)
    }

    static func band(_ size: CGFloat, _ weight: CGFloat = 700) -> Font {
        Typeface.font(size, weight: max(400, weight), width: 100)
    }
}

struct Eyebrow: View {
    let text: String
    var color = Palette.inkFaint

    var body: some View {
        Text(text.uppercased())
            .font(.ui(11, 600))
            .tracking(1.3)
            .foregroundStyle(color)
    }
}

struct LiveDot: View {
    var size: CGFloat = 7
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Palette.live)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Palette.live.opacity(0.35))
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
            }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.rule, lineWidth: 1))
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Palette.rule).frame(height: 1)
    }
}

struct PointingHand: ViewModifier {
    @State private var pushed = false

    func body(content: Content) -> some View {
        content
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    if !pushed {
                        NSCursor.pointingHand.push()
                        pushed = true
                    } else {
                        NSCursor.pointingHand.set()
                    }
                case .ended:
                    if pushed {
                        NSCursor.pop()
                        pushed = false
                    }
                }
            }
            .onDisappear {
                if pushed {
                    NSCursor.pop()
                    pushed = false
                }
            }
    }
}

extension View {
    func pointingHand() -> some View {
        modifier(PointingHand())
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.display(18, weight: 760))
            .foregroundStyle(Palette.ink)
    }
}

struct Skeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var radius: CGFloat = 4
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Palette.raised)
            .frame(width: width, height: height)
            .opacity(dim ? 0.45 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
    }
}

struct SkeletonList: View {
    var rows = 8
    var rowHeight: CGFloat = 52
    var band = true

    var body: some View {
        Color.clear
            .overlay(alignment: .top) { placeholder }
            .clipped()
            .allowsHitTesting(false)
    }

    private var placeholder: some View {
        VStack(spacing: 0) {
            if band {
                HStack {
                    Skeleton(width: 160, height: 10)
                    Spacer()
                }
                .padding(.horizontal, 40)
                .frame(height: 32)
                .background(Palette.raised.opacity(0.5))
            }
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: 14) {
                    Skeleton(width: 24, height: 24, radius: 6)
                    VStack(alignment: .leading, spacing: 6) {
                        Skeleton(width: [220, 170, 260, 140, 200][index % 5], height: 11)
                        Skeleton(width: 70, height: 8)
                    }
                    Spacer()
                    Skeleton(width: 22, height: 14)
                }
                .padding(.horizontal, 40)
                .frame(height: rowHeight)
                Hairline()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

final class DragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.performZoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}
}

extension View {
    func windowDraggable() -> some View {
        background(WindowDragArea())
    }
}
