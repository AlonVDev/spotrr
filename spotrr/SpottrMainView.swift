//
//  SpottrMainView.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SpottrMainView: View {
    @EnvironmentObject var store: SpottrStore
    @State private var selectedTab: Tab = .today

    enum Tab: Int {
        case today
        case split
        case friends
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
                .tag(Tab.today)

            MySplitView()
                .tabItem {
                    Label("My Split", systemImage: "rectangle.grid.1x2.fill")
                }
                .tag(Tab.split)

            FriendsView()
                .tabItem {
                    Label("Friends", systemImage: "person.2.fill")
                }
                .tag(Tab.friends)
        }
        .tint(SpottrTheme.accent)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SpottrMainView()
        .environmentObject(SpottrStore())
}
