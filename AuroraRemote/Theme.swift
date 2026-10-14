import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(red: 0.035, green: 0.04, blue: 0.055)
    static let card = Color.white.opacity(0.055)
    static let stroke = Color.white.opacity(0.08)
    static let muted = Color.white.opacity(0.55)
    static let swatches = ["#ff2d55", "#ff6b00", "#ffd60a", "#32d74b", "#00e5ff", "#0a84ff", "#7d5cff", "#ff4fd8", "#ffffff"]
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
    }

    var hue: Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }
}

/// Mismas formulas que EFFECTS/render de aurora_rgb.py, para que la vista previa se mueva como el PC.
enum EffectPreview {
    static func color(effect: String, base: Color, t: Double, i: Int, n: Int, speed: Int, brightness: Int,
                      gpuTemp: Double?) -> Color {
        let sp = 1.5 + Double(speed)
        let k = Double(brightness) / 100
        func scaled(_ c: Color, _ f: Double) -> Color { c.opacity(max(0.04, min(1, f * k))) }
        switch effect {
        case "Respirar":
            return scaled(base, 0.08 + 0.92 * (0.5 - 0.5 * cos(t * sp * 1.2)))
        case "Arcoíris":
            return scaled(Color(hue: (t * sp * 0.08 + Double(i) / Double(max(n, 1))).truncatingRemainder(dividingBy: 1),
                                saturation: 1, brightness: 1), 1)
        case "Ciclo":
            return scaled(Color(hue: (t * sp * 0.05).truncatingRemainder(dividingBy: 1), saturation: 1, brightness: 1), 1)
        case "Ola":
            let w = 0.5 + 0.5 * sin(t * sp * 2 - Double(i) * 0.6)
            return scaled(base, 0.03 + 0.97 * w * w)
        case "Estrellas":
            return scaled(base, 0.06 + 0.94 * pow(max(0, sin(t * sp * 0.7 + Double(i) * 24.7)), 12))
        case "Fuego":
            let h = min(max(0.55 + 0.25 * sin(t * sp * 1.9 + Double(i) * 1.3) + 0.2 * sin(t * sp * 4.7 + Double(i) * 2.9 + 1), 0), 1)
            return scaled(Color(red: min(1, h * 1.5), green: max(0, h - 0.35) * 1.4, blue: max(0, h - 0.85) * 3), 1)
        case "Boreal":
            let hue = 0.42 + 0.2 * sin(t * sp * 0.21 + Double(i) * 0.33) + 0.08 * sin(t * sp * 0.53 - Double(i) * 0.7)
            let v = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * sp * 0.6 - Double(i) * 0.45))
            return scaled(Color(hue: hue, saturation: 0.9, brightness: v), 1)
        case "Visor":
            let pos = (0.5 + 0.5 * sin(t * sp * 1.1)) * Double(n - 1)
            let d = abs(Double(i) - pos) / max(2.5, Double(n) / 6)
            return scaled(base, 0.03 + 0.97 * max(0, 1 - d * d))
        case "Música":  // el iPhone no oye el PC: misma animacion que Aurora con un ritmo simulado de 120 bpm
            let beat = (t * 2).truncatingRemainder(dividingBy: 1) / 2          // segundos desde el ultimo golpe
            let bass = 0.15 + 0.85 * exp(-beat * 7), mid = 0.5 + 0.5 * sin(t * 0.9)
            let hue0 = base.hue + 0.07 * Double(Int(t * 2) % 5) - 0.14 + 1   // paleta que avanza en cada golpe
            let d = Double(min(i, n - i)) / (Double(n) / 2)                   // vumetro en espejo
            var c = d <= bass * 1.05 ? Color(hue: (hue0 + 0.2 * mid * d).truncatingRemainder(dividingBy: 1),
                                              saturation: 1, brightness: 0.3 + 0.7 * bass * (0.6 + 0.4 * d))
                                     : Color.black
            if beat < 0.6, max(0, 1 - abs(d - beat / 0.6) * 3) * (1 - beat / 0.6) > 0.3 {  // onda complementaria
                c = Color(hue: (hue0 + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 1)
            }
            if (i * 7 + Int(t * 18)) % 23 == 0 { c = .white }               // chispas
            return scaled(c, 1)
        case "Concierto":  // misma idea que en el PC con un ritmo simulado de 120 bpm
            let beat = (t * 2).truncatingRemainder(dividingBy: 1) / 2
            let bass = 0.15 + 0.85 * exp(-beat * 7)
            let base0 = t * 0.12 + 0.27 * Double(Int(t * 2))               // gira y salta 1/3 en cada golpe
            let d = Double(min(i, n - i)) / (Double(n) / 2)
            let h = (base0 + Double(i) / Double(n)).truncatingRemainder(dividingBy: 1)
            var c = Color(hue: h, saturation: 1, brightness: d <= bass * 1.05 ? 0.45 + 0.55 * bass : 0.12)
            if beat < 0.6, max(0, 1 - abs(d - beat / 0.6) * 3) * (1 - beat / 0.6) > 0.3 {
                c = Color(hue: (h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 1)
            }
            if (i * 7 + Int(t * 18)) % 23 == 0 { c = Color(hue: Double((i * 37) % 100) / 100, saturation: 0.35, brightness: 1) }
            return scaled(c, 1)
        case "Temp. GPU":
            guard let temp = gpuTemp else { return scaled(base, 1) }
            let f = min(max((temp - 35) / 50, 0), 1)
            return scaled(Color(hue: 0.62 * (1 - f), saturation: 1, brightness: 1), 1)
        case "Apagado":
            return Color.white.opacity(0.04)
        default:
            return scaled(base, 1)
        }
    }

    static func icon(_ effect: String) -> String {
        switch effect {
        case "Estático": return "circle.fill"
        case "Respirar": return "wind"
        case "Arcoíris": return "rainbow"
        case "Ciclo": return "arrow.triangle.2.circlepath"
        case "Ola": return "water.waves"
        case "Estrellas": return "sparkles"
        case "Temp. GPU": return "thermometer.medium"
        case "Apagado": return "power"
        case "Fuego": return "flame.fill"
        case "Boreal": return "moon.stars.fill"
        case "Visor": return "arrow.left.and.right"
        case "Ambiente": return "display"
        case "Música": return "music.note"
        case "Concierto": return "party.popper.fill"
        default: return "lightbulb.fill"
        }
    }

    static func subtitle(_ effect: String) -> String {
        switch effect {
        case "Estático": return "Color fijo"
        case "Respirar": return "Pulso suave"
        case "Arcoíris": return "Espectro móvil"
        case "Ciclo": return "Todos los colores"
        case "Ola": return "Onda de brillo"
        case "Estrellas": return "Destellos"
        case "Temp. GPU": return "Según la temperatura"
        case "Apagado": return "Todo apagado"
        case "Fuego": return "Llamas vivas"
        case "Boreal": return "Aurora boreal"
        case "Visor": return "Barrido de luz"
        case "Ambiente": return "Color de la pantalla"
        case "Música": return "Sigue el sonido"
        case "Concierto": return "Música a todo color"
        default: return ""
        }
    }
}

struct GlassCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.card))
        )
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}
