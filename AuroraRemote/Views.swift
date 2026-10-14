import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AuroraStore

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let state = store.state {
                ControlView(state: state)
            } else {
                ConnectView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Conexion

struct ConnectView: View {
    @EnvironmentObject var store: AuroraStore
    @State private var manualHost = ""

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AngularGradient(colors: [.pink, .orange, .yellow, .green, .cyan, .blue, .purple, .pink],
                                          center: .center))
                    .frame(width: 120, height: 120)
                    .blur(radius: 28)
                    .opacity(0.8)
                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: 54, weight: .semibold))
            }
            VStack(spacing: 8) {
                Text("Aurora").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Controla la iluminación de tu PC")
                    .font(.system(size: 16)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 14) {
                Button {
                    Task { await store.discover() }
                } label: {
                    HStack(spacing: 10) {
                        if store.searching { ProgressView().tint(.black) } else { Image(systemName: "wifi") }
                        Text(store.searching ? "Buscando en tu WiFi…" : "Buscar mi PC")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
                }
                .disabled(store.searching)

                HStack(spacing: 10) {
                    TextField("IP del PC, p. ej. 192.168.1.20", text: $manualHost)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 50)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                    Button {
                        store.host = manualHost.trimmingCharacters(in: .whitespaces)
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .disabled(manualHost.isEmpty)
                }
                if !store.host.isEmpty && !store.connected && !store.searching {
                    Text("No responde \(store.host). ¿Está Aurora abierta en el PC y en la misma WiFi?")
                        .font(.system(size: 13)).foregroundStyle(.orange).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            Spacer()
            Text("La IP aparece arriba a la derecha en la ventana de Aurora.")
                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                .padding(.bottom, 12)
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Control

struct ControlView: View {
    @EnvironmentObject var store: AuroraStore
    let state: RemoteState
    @State private var showSettings = false
    @State private var custom = Color.white

    private var tint: Color { Color(hex: state.color) }
    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack(alignment: .top) {
            RadialGradient(colors: [tint.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: state.color)
            ScrollView {
                VStack(spacing: 16) {
                    header
                    LEDRing(state: state)
                    colorCard
                    effectsCard
                    adjustCard
                    if !state.scenes.isEmpty { scenesCard }
                    if let gpu = state.gpu { gpuCard(gpu) }
                    devicesCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showSettings) {
            SettingsSheet().environmentObject(store).presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aurora").font(.system(size: 32, weight: .bold, design: .rounded))
                HStack(spacing: 6) {
                    Circle().fill(store.connected ? Color.green : Color.orange).frame(width: 8, height: 8)
                    Text(store.connected ? "PC conectado · \(state.devices.count) dispositivos" : "Reconectando…")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
        .padding(.top, 8)
    }

    private var colorCard: some View {
        GlassCard(title: "Color") {
            HueSlider(hue: tint.hue) { h in
                store.change(["color": Color(hue: h, saturation: 1, brightness: 1).hex])
            }
            HStack(spacing: 0) {
                ForEach(Theme.swatches, id: \.self) { hex in
                    Button { store.change(["color": hex]) } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white, lineWidth: state.color == hex ? 2.5 : 0))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            ColorPicker(selection: Binding(get: { tint }, set: { store.change(["color": $0.hex]) }),
                        supportsOpacity: false) {
                Text("Color personalizado").font(.system(size: 15, weight: .medium))
            }
        }
    }

    private var effectsCard: some View {
        GlassCard(title: "Efecto") {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(state.effects, id: \.self) { name in
                    EffectCard(name: name, selected: state.effect == name, tint: tint) {
                        withAnimation(.snappy) { store.change(["effect": name]) }
                    }
                }
            }
            // estilos de Concierto: solo con Concierto elegido, como en el PC
            if state.effect == "Concierto", let styles = state.concert_styles, !styles.isEmpty {
                Text("ESTILO DE CONCIERTO")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(styles, id: \.self) { name in
                        EffectCard(name: name, selected: state.concert_style == name, tint: tint) {
                            withAnimation(.snappy) { store.change(["concert_style": name]) }
                        }
                    }
                }
            }
        }
    }

    private var adjustCard: some View {
        GlassCard(title: "Ajustes") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Brillo").font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(state.brightness)%").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.muted)
                }
                IconSlider(low: "sun.min", high: "sun.max.fill", value: Double(state.brightness), range: 0...100,
                           tint: tint) { store.change(["brightness": Int($0)]) }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Velocidad").font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(state.speed)").font(.system(size: 14, design: .monospaced)).foregroundStyle(Theme.muted)
                }
                IconSlider(low: "tortoise.fill", high: "hare.fill", value: Double(state.speed), range: 1...10,
                           tint: tint) { store.change(["speed": Int($0)]) }
            }
        }
    }

    private var scenesCard: some View {
        GlassCard(title: "Escenas") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(state.scenes.keys.sorted(), id: \.self) { name in
                        let sc = state.scenes[name]!
                        Button { store.applyScene(name) } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(sc.effect == "Arcoíris"
                                          ? AnyShapeStyle(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
                                          : AnyShapeStyle(Color(hex: sc.color)))
                                    .frame(width: 14, height: 14)
                                Text(name).font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(Capsule().fill(Color.white.opacity(0.07)))
                            .overlay(Capsule().stroke(Theme.stroke))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func gpuCard(_ gpu: RemoteState.GPU) -> some View {
        GlassCard(title: "Tarjeta gráfica") {
            Text(gpu.name).font(.system(size: 15, weight: .semibold))
            HStack(spacing: 8) {
                StatTile(label: "Temp", value: gpu.temp.map { "\(Int($0))°" } ?? "–",
                         tint: tempTint(gpu.temp))
                StatTile(label: "Uso", value: gpu.util.map { "\(Int($0))%" } ?? "–")
                StatTile(label: "Consumo", value: gpu.power.map { "\(Int($0)) W" } ?? "–")
            }
            if state.gpu_rgb {
                Toggle(isOn: Binding(get: { state.gpu_sync }, set: { store.change(["gpu_sync": $0]) })) {
                    Text("Sincronizar luces de la GPU").font(.system(size: 15, weight: .medium))
                }
                .tint(tint)
            }
        }
    }

    private func tempTint(_ t: Double?) -> Color {
        guard let t else { return .white }
        let f = min(max((t - 35) / 50, 0), 1)
        return Color(hue: 0.62 * (1 - f), saturation: 0.8, brightness: 1)
    }

    private var devicesCard: some View {
        GlassCard(title: "Dispositivos") {
            if let live = state.ram_live {
                Toggle(isOn: Binding(get: { live }, set: { store.change(["ram_live": $0]) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RAM en tiempo real").font(.system(size: 15, weight: .medium))
                        Text("Sigue las animaciones como los ventiladores").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }
                .tint(tint)
            }
            ForEach(state.devices) { d in
                HStack(spacing: 14) {
                    Image(systemName: deviceIcon(d.name))
                        .font(.system(size: 17))
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                        Text("\(d.leds) LEDs").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { d.on }, set: { store.setDevice(d.name, on: $0) }))
                        .labelsHidden()
                        .tint(tint)
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @EnvironmentObject var store: AuroraStore
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("PC") {
                    TextField("IP del PC", text: $host).keyboardType(.decimalPad)
                    Button("Guardar") {
                        store.host = host.trimmingCharacters(in: .whitespaces)
                        Task { await store.refresh() }
                        dismiss()
                    }
                    Button {
                        Task { await store.discover(); host = store.host }
                    } label: {
                        HStack {
                            Text(store.searching ? "Buscando…" : "Buscar de nuevo")
                            if store.searching { Spacer(); ProgressView() }
                        }
                    }
                }
                Section {
                    Button("Olvidar este PC", role: .destructive) {
                        store.host = ""
                        store.state = nil
                        dismiss()
                    }
                }
            }
            .navigationTitle("Conexión")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { host = store.host }
        }
        .preferredColorScheme(.dark)
    }
}
