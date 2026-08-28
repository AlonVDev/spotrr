//
//  spotrrApp.swift
//  spotrr
//
//  Created by Alon Max Vaknin on 26/08/2026.
//

import SwiftUI

@main
struct spotrrApp: App {
    @StateObject private var store = SpottrStore()

    var body: some Scene {
        WindowGroup {
            SpottrMainView()
                .environmentObject(store)
        }
    }
}
