//
//  Theme.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SpottrTheme {
    // Clean, high-contrast neon accent
    static let accent = Color(red: 0, green: 0.77, blue: 1) // Electric Lime #D4FB34
    static let accentMuted = Color(red: 0.83, green: 0.98, blue: 0.20).opacity(0.15)
    static let green = Color(red: 0.22, green: 0.88, blue: 0.55)  // Rest Day Green

    // Backgrounds & Cards (Ultra-clean dark mode)
    static let background = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.14)
    static let cardSubtle = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let border = Color.white.opacity(0.08)

    // Typography Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textMuted = Color.white.opacity(0.35)
}

struct SpottrCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(SpottrTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(SpottrTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func spottrCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(SpottrCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
