import SwiftUI
import AppKit

typealias ViewState<Value> = SwiftUI.State<Value>

enum Palette {
    static let background = Color(hex: 0x0C1014)
    static let surface = Color(hex: 0x151B21)
    static let muted = Color(hex: 0x919DA9)
    static let coral = Color(hex: 0xB8A4FF)
    static let mint = Color(hex: 0xA2ECD5)
    static let line = Color.white.opacity(0.075)
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
}

struct Tactile: ButtonStyle {
    var primary = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        TactileBody(configuration: configuration, primary: primary, reduceMotion: reduceMotion)
    }
    private struct TactileBody: View {
        let configuration: ButtonStyleConfiguration
        let primary: Bool
        let reduceMotion: Bool
        @ViewState private var hover = false
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label.font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).frame(minWidth:32,minHeight:32)
                .foregroundStyle(primary ? Color(hex: 0x251B15) : .white.opacity(0.88))
                .background(primary ? Palette.coral.opacity(configuration.isPressed ? 0.82 : 1) : .white.opacity(configuration.isPressed ? 0.16 : hover ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(primary ? .white.opacity(0.2) : Palette.line))
                .contentShape(RoundedRectangle(cornerRadius:11))
                .shadow(color: primary ? Palette.coral.opacity(hover ? 0.21 : 0.09) : .black.opacity(0.12), radius: configuration.isPressed ? 3:12, y: configuration.isPressed ? 1:4)
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
                .opacity(enabled ? 1 : 0.38)
                .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.58), value: configuration.isPressed)
                .onHover { hover = $0 }
                .onChange(of:configuration.isPressed) {_,pressed in if pressed && enabled {NSHapticFeedbackManager.defaultPerformer.perform(.alignment,performanceTime:.now)}}
        }
    }
}

// For compact actions: a proper hit area, visible depression and a spring release.
// The card itself stays still, so hovering never moves a target away from the pointer.
struct SoftPress:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label.frame(minWidth:32,minHeight:32).contentShape(Rectangle())
            .background(.white.opacity(configuration.isPressed ? 0.09:0),in:RoundedRectangle(cornerRadius:9))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94:1)
            .animation(reduceMotion ? nil:.spring(response:0.20,dampingFraction:0.58),value:configuration.isPressed)
            .onChange(of:configuration.isPressed) {_,pressed in if pressed {NSHapticFeedbackManager.defaultPerformer.perform(.alignment,performanceTime:.now)}}
    }
}

struct GlassPanel<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26.0, *) {
            content.frame(maxWidth:.infinity,alignment:.leading).padding(padding)
                .glassEffect(.regular.tint(Palette.surface.opacity(0.25)), in: RoundedRectangle(cornerRadius: 21))
        } else {
            content.frame(maxWidth:.infinity,alignment:.leading).padding(padding).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21))
                .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(Palette.line))
        }
    }
}

struct Tag: View {
    var text: String
    var color: Color = Palette.muted
    var dot = false
    var body: some View {
        HStack(spacing: 6) {
            if dot { Circle().fill(color).frame(width: 5, height: 5) }
            Text(text).font(.system(size: 11, weight: .semibold)).tracking(0.45)
        }.foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.08), in: Capsule()).overlay(Capsule().strokeBorder(color.opacity(0.13)))
    }
}

struct NEXARCMark: View {
    var body: some View {
        GeometryReader {g in
            ZStack {
                portal([(0.48,0.06),(0.09,0.285),(0.09,0.715),(0.48,0.94),(0.48,0.745),(0.26,0.615),(0.26,0.385),(0.48,0.255)],g.size)
                    .fill(LinearGradient(colors:[Color(hex:0xA0FFE1),Color(hex:0x46D5B8)],startPoint:.topLeading,endPoint:.bottomTrailing))
                portal([(0.52,0.06),(0.91,0.285),(0.91,0.715),(0.52,0.94),(0.52,0.745),(0.74,0.615),(0.74,0.385),(0.52,0.255)],g.size)
                    .fill(LinearGradient(colors:[Color(hex:0xBAA1FF),Color(hex:0x7764E8)],startPoint:.topLeading,endPoint:.bottomTrailing))
                portal([(0.50,0.35),(0.63,0.50),(0.50,0.65),(0.37,0.50)],g.size).fill(LinearGradient(colors:[.white,Color(hex:0xCEFFF2)],startPoint:.top,endPoint:.bottom))
            }
        }.aspectRatio(1,contentMode:.fit).accessibilityLabel("NEXARC Warp emblem")
    }
    private func portal(_ points:[(CGFloat,CGFloat)],_ size:CGSize)->Path {
        Path {p in for (i,v) in points.enumerated(){let point=CGPoint(x:v.0*size.width,y:v.1*size.height);if i==0{p.move(to:point)}else{p.addLine(to:point)}};p.closeSubpath()}
    }
}

struct DiagnosticArt: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x4D282A), Color(hex: 0xA35A44), Color(hex: 0xEBAA7E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                ForEach(0..<7) { i in
                    Circle().stroke(.white.opacity(0.07 + Double(i)*0.015), lineWidth: 1)
                        .frame(width: CGFloat(70+i*40), height: CGFloat(70+i*40))
                        .position(x: g.size.width*0.75, y: g.size.height*0.46)
                }
                Circle().fill(LinearGradient(colors: [Color(hex: 0xFFF3CF), Color(hex: 0xECAC7E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 76, height: 76).shadow(color: .orange.opacity(0.3), radius: 35).position(x: g.size.width*0.75, y: g.size.height*0.46)
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEXARC ORIGINAL").font(.system(size: 10, weight: .bold)).tracking(2)
                    Spacer(minLength: 4)
                    Text("first\nlight").font(.system(size: 35, weight: .light, design: .serif)).tracking(-1.5).lineSpacing(-8).fixedSize(horizontal: false, vertical: true)
                    Text("A SMALL PROGRAM. A REAL BEGINNING.").font(.system(size: 8, weight: .semibold)).tracking(1)
                }.foregroundStyle(.white.opacity(0.88)).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.clipped()
    }
}
