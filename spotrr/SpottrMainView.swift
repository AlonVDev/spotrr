//
//  SpottrMainView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SpottrMainView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var selectedTab: Tab = .split

    enum Tab: Int {
        case split
        case buddies
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SplitView()
                .tabItem {
                    Label("Split", systemImage: "dumbbell.fill")
                }
                .tag(Tab.split)

            BuddiesView()
                .tabItem {
                    Label("Buddies", systemImage: "person.2.fill")
                }
                .tag(Tab.buddies)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(SpottrTheme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SpottrMainView()
        .environmentObject(SpottrStore())
}
