import SwiftUI

@main
struct AuroraRemoteApp: App {
    @StateObject private var store = AuroraStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onChange(of: phase) { _, now in
                    // solo consulta el PC con la app en pantalla
                    if now == .active { store.startPolling() } else { store.stopPolling() }
                }
                .onAppear { store.startPolling() }
        }
    }
}
