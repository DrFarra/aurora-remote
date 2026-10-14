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
        case "Música":  // en el iPhone no hay audio del PC: vista previa con un nivel simulado
            let lvl = 0.25 + 0.55 * abs(sin(t * 2.3)) + 0.2 * abs(sin(t * 7.1))
            return Double(i) < lvl * Double(n) ? scaled(base, 0.15 + 0.85 * lvl) : scaled(base, 0.04)
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
