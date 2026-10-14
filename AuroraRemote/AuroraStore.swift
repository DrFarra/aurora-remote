import Foundation
import SwiftUI

// Estado que expone Aurora en GET /api/state (ver aurora_rgb.py -> App.snapshot)
struct RemoteState: Codable, Equatable {
    var color: String
    var effect: String
    var brightness: Int
    var speed: Int
    var effects: [String]
    var scenes: [String: Scene]
    var gpu_sync: Bool
    var ram_live: Bool?  // opcional: Aurora antigua no lo envia
    var devices: [Device]
    var gpu: GPU?
    var gpu_rgb: Bool

    struct Scene: Codable, Equatable {
        var color: String
        var effect: String
        var brightness: Int
        var speed: Int
    }

    struct Device: Codable, Equatable, Identifiable {
        var name: String
        var leds: Int
        var on: Bool
        var id: String { name }
    }

    struct GPU: Codable, Equatable {
        var name: String
        var temp: Double?
        var util: Double?
        var power: Double?
        var fan: Double?
    }
}

@MainActor
final class AuroraStore: ObservableObject {
    static let port = 6750

    @Published var host: String = UserDefaults.standard.string(forKey: "host") ?? "" {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    @Published var state: RemoteState?
    @Published var connected = false
    @Published var searching = false

    private var pollTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    private var pending: [String: Any] = [:]
    private var lastEdit = Date.distantPast
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 2.5
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    // MARK: lectura periodica

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard !host.isEmpty, let url = URL(string: "http://\(host):\(Self.port)/api/state") else {
            connected = false
            return
        }
        do {
            let (data, resp) = try await session.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            let fresh = try JSONDecoder().decode(RemoteState.self, from: data)
            connected = true
            // mientras el usuario arrastra un control, no pisar su valor con el del PC
            if Date().timeIntervalSince(lastEdit) > 1.5 || state == nil {
                state = fresh
            } else {
                state?.devices = fresh.devices
                state?.gpu = fresh.gpu
            }
        } catch {
            connected = false
        }
    }

    // MARK: cambios (optimistas y agrupados: un arrastre de color no manda 60 peticiones por segundo)

    func change(_ changes: [String: Any]) {
        lastEdit = Date()
        if var s = state {
            if let v = changes["color"] as? String { s.color = v }
            if let v = changes["effect"] as? String { s.effect = v }
            if let v = changes["brightness"] as? Int { s.brightness = v }
            if let v = changes["speed"] as? Int { s.speed = v }
            if let v = changes["gpu_sync"] as? Bool { s.gpu_sync = v }
            if let v = changes["ram_live"] as? Bool { s.ram_live = v }
            state = s
        }
        pending.merge(changes) { $1 }
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            await self?.flush()
        }
    }

    private func flush() async {
        let body = pending
        pending = [:]
        flushTask = nil
        if !body.isEmpty { await post("/api/state", body) }
    }

    func applyScene(_ name: String) {
        lastEdit = Date()
        if let sc = state?.scenes[name] {
            state?.color = sc.color
            state?.effect = sc.effect
            state?.brightness = sc.brightness
            state?.speed = sc.speed
        }
        Task { await post("/api/scene", ["name": name]) }
    }

    func setDevice(_ name: String, on: Bool) {
        if let i = state?.devices.firstIndex(where: { $0.name == name }) { state?.devices[i].on = on }
        Task { await post("/api/device", ["name": name, "on": on]) }
    }

    private func post(_ path: String, _ body: [String: Any]) async {
        guard let url = URL(string: "http://\(host):\(Self.port)\(path)"),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        do {
            let (_, resp) = try await session.data(for: req)
            connected = (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            connected = false
        }
    }

    // MARK: busqueda del PC en la WiFi (prueba el puerto de Aurora en toda la subred /24)

    func discover() async {
        searching = true
        defer { searching = false }
        guard let net = Self.localSubnet() else { return }
        let found: String? = await withTaskGroup(of: String?.self) { group in
            for i in 1...254 {
                let ip = "\(net.base).\(i)"
                if ip == net.own { continue }
                group.addTask { await Self.probe(ip) ? ip : nil }
            }
            for await result in group {
                if let result {
                    group.cancelAll()
                    return result
                }
            }
            return nil
        }
        if let found {
            host = found
            await refresh()
        }
    }

    nonisolated static func probe(_ ip: String) async -> Bool {
        guard let url = URL(string: "http://\(ip):\(port)/api/state") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return (try? JSONDecoder().decode(RemoteState.self, from: data)) != nil
    }

    nonisolated static func localSubnet() -> (base: String, own: String)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: ifa.ifa_name) == "en0" else { continue }  // en0 = WiFi en iPhone
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &buf, socklen_t(buf.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: buf)
            let parts = ip.split(separator: ".")
            guard parts.count == 4 else { continue }
            return (parts[0..<3].joined(separator: "."), ip)
        }
        return nil
    }
}
