//
//  ContentView.swift
//  spotrr
//
//  Created by Alon Max Vaknin on 26/08/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = SpottrStore()

    var body: some View {
        SpottrMainView()
            .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
