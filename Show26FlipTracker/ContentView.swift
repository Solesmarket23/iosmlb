import SwiftUI

struct ContentView: View {
    @State private var presetManager = PresetManager()
    @State private var notificationManager = NotificationManager.shared
    @State private var model: ListingsViewModel
    @State private var selectedTab = 0

    init() {
        let pm = PresetManager()
        let nm = NotificationManager.shared
        _presetManager = State(initialValue: pm)
        _notificationManager = State(initialValue: nm)
        _model = State(initialValue: ListingsViewModel(presetManager: pm, notificationManager: nm))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FlipsView(model: model)
                .tabItem { Label("Flips", systemImage: "flame.fill") }
                .tag(0)
            PlayerFinderView(model: model)
                .tabItem { Label("Players", systemImage: "person.2.fill") }
                .tag(1)
            MarketView(model: model, presetManager: presetManager)
                .tabItem { Label("Market", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .tint(.appAccent)
        .preferredColorScheme(.dark)
        .task {
            await notificationManager.requestAuthorization()
            await model.loadAll()
        }
        .onDisappear {
            model.stopAutoRefresh()
        }
    }
}

#Preview {
    ContentView()
}
