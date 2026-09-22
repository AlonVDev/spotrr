//
//  Theme.swift
//  spotrr
//
//  Created by Spottr on 28/08/2026.
//

import SwiftUI

struct SpottrTheme {
    // Clean, high-contrast neon accent
    static let accent = Color.blue //(hex: "#38E08C") // Mint Green
    static let accentMuted = Color.blue.opacity(0.15) //(hex: "#38E08C").opacity(0.15)
    static let restColor = Color.white //(hex: "#009DFF") // Rest Day Blue

    // Backgrounds & Cards (Ultra-clean dark mode)
    static let background = Color.black //(hex: "#0F0F14")
    static let card = Color(white: 0.06) //(hex: "#1C1C24")
    static let cardSubtle = Color(white: 0.03) //(hex: "#26262E")
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
