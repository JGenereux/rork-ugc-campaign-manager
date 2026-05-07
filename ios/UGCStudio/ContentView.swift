import SwiftUI
import UIKit

nonisolated enum AppTab: Hashable { case campaigns, record, insights }

enum EditorRoute: Identifiable {
    case new
    case edit(Campaign)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let c): return c.id.uuidString
        }
    }

    var initial: Campaign? {
        switch self {
        case .new: return nil
        case .edit(let c): return c
        }
    }
}

struct ContentView: View {
    @State private var store = CampaignStore.shared
    @State private var selectedTab: AppTab = .campaigns
    @State private var editorRoute: EditorRoute?
    @State private var showingSettings: Bool = false

    init() {
        configureAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CampaignsListView(
                    store: store,
                    editorRoute: $editorRoute,
                    showingSettings: $showingSettings
                )
            }
            .tabItem { Label("Campaigns", systemImage: "rectangle.stack") }
            .tag(AppTab.campaigns)

            NavigationStack {
                RecorderView(store: store)
            }
            .tabItem { Label("Record", systemImage: "record.circle") }
            .tag(AppTab.record)

            NavigationStack {
                InsightsView(store: store)
            }
            .tabItem { Label("Insights", systemImage: "chart.bar.xaxis") }
            .tag(AppTab.insights)
        }
        .tint(Palette.signalBlue)
        .preferredColorScheme(.dark)
        .sheet(item: $editorRoute) { route in
            CampaignEditorView(initial: route.initial) { saved in
                store.upsert(saved)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private func configureAppearance() {
        // Tab bar — flat dark with hairline top border
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Palette.bg)
        tabAppearance.shadowColor = UIColor(Palette.hairline)

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Nav bar — flat dark with hairline bottom border
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Palette.bg)
        navAppearance.shadowColor = UIColor(Palette.hairline)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Palette.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Palette.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

#Preview { ContentView() }
