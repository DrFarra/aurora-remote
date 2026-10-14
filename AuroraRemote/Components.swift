import SwiftUI

/// Anillo de 16 LEDs (como un ventilador) que se anima con el efecto actual.
struct LEDRing: View {
    let state: RemoteState
    private let count = 16

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let base = Color(hex: state.color)
            let colors = (0..<count).map {
                EffectPreview.color(effect: state.effect == "Concierto" && state.concert_style == "Escenario"
                                    ? "Escenario" : state.effect, base: base, t: t, i: $0, n: count, speed: state.speed,
                                    brightness: max(state.brightness, 15), gpuTemp: state.gpu?.temp)
            }
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [colors[0].opacity(0.55), .clear], center: .center,
                                         startRadius: 10, endRadius: 170))
                    .blur(radius: 30)
                ForEach(0..<count, id: \.self) { i in
                    let a = Double(i) / Double(count) * 2 * .pi - .pi / 2
                    Circle()
                        .fill(colors[i])
                        .frame(width: 18, height: 18)
                        .shadow(color: colors[i], radius: 10)
                        .offset(x: cos(a) * 92, y: sin(a) * 92)
                }
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 150, height: 150)
                VStack(spacing: 4) {
                    Image(systemName: EffectPreview.icon(state.effect))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(state.effect)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(state.color.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 250)
        }
    }
}

/// Barra de tono arrastrable.
struct HueSlider: View {
    let hue: Double
    var onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: stride(from: 0.0, through: 1.0, by: 0.1).map {
                        Color(hue: $0, saturation: 1, brightness: 1)
                    }, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 30)
                Circle()
                    .fill(Color(hue: hue, saturation: 1, brightness: 1))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .frame(width: 34, height: 34)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .offset(x: min(max(hue * w - 17, -2), w - 32))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                onChange(min(max(v.location.x / w, 0), 0.999))
            })
        }
        .frame(height: 34)
    }
}

struct IconSlider: View {
    let low: String
    let high: String
    let value: Double
    let range: ClosedRange<Double>
    let tint: Color
    var onChange: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: low).foregroundStyle(Theme.muted).frame(width: 22)
            Slider(value: Binding(get: { value }, set: { onChange($0) }), in: range, step: 1)
                .tint(tint)
            Image(systemName: high).foregroundStyle(Theme.muted).frame(width: 22)
        }
    }
}

struct EffectCard: View {
    let name: String
    let selected: Bool
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: EffectPreview.icon(name))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? tint : .white.opacity(0.85))
                Spacer(minLength: 0)
                Text(name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(EffectPreview.subtitle(name))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? tint.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? tint.opacity(0.9) : Theme.stroke, lineWidth: selected ? 1.5 : 1)
            )
            .shadow(color: selected ? tint.opacity(0.35) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

func deviceIcon(_ name: String) -> String {
    let n = name.lowercased()
    if n.contains("keyboard") { return "keyboard" }
    if n.contains("mouse") { return "computermouse" }
    if n.contains("dram") { return "memorychip" }
    if n.contains("mystic") || n.contains("msi") { return "fan" }
    return "lightbulb"
}
