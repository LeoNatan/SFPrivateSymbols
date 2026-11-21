//
//  SymbolStyle.swift
//  SFPrivateSymbols
//

import SwiftUI

/// Rendering modes, in the order of SF Symbols' “Rendering Mode” menu.
enum SymbolRenderingStyle: String, CaseIterable, Identifiable, Codable {
	case automatic
	case monochrome
	case hierarchical
	case palette
	case multicolor

	var id: Self { self }

	var title: String {
		switch self {
		case .automatic: "Automatic"
		case .monochrome: "Monochrome"
		case .hierarchical: "Hierarchical"
		case .palette: "Palette"
		case .multicolor: "Multicolor"
		}
	}

	/// The four concrete modes shown in the inspector's preview strip.
	static let concrete: [SymbolRenderingStyle] = [.monochrome, .hierarchical, .palette, .multicolor]

	var symbolRenderingMode: SymbolRenderingMode? {
		switch self {
		case .automatic: nil
		case .monochrome: .monochrome
		case .hierarchical: .hierarchical
		case .palette: .palette
		case .multicolor: .multicolor
		}
	}
}

/// Colors offered by SF Symbols' color menus (`ColorNamePickerSelection`).
enum NamedColor: String, CaseIterable, Identifiable, Codable {
	case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown, white, gray, black
	case primary, secondary, tertiary, quaternary, accent
	case none
	case custom

	var id: Self { self }

	static let system: [NamedColor] = [.red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .white, .gray, .black]
	static let hierarchy: [NamedColor] = [.primary, .secondary, .tertiary, .quaternary, .accent]

	var title: String {
		rawValue.capitalized
	}

	var color: Color {
		switch self {
		case .red: .red
		case .orange: .orange
		case .yellow: .yellow
		case .green: .green
		case .mint: .mint
		case .teal: .teal
		case .cyan: .cyan
		case .blue: .blue
		case .indigo: .indigo
		case .purple: .purple
		case .pink: .pink
		case .brown: .brown
		case .white: .white
		case .gray: .gray
		case .black: .black
		case .primary: Color(nsColor: .labelColor)
		case .secondary: Color(nsColor: .secondaryLabelColor)
		case .tertiary: Color(nsColor: .tertiaryLabelColor)
		case .quaternary: Color(nsColor: .quaternaryLabelColor)
		case .accent: .accentColor
		case .none: .white
		case .custom: .gray
		}
	}
}

/// One color slot in the rendering inspector: a named color (or custom) plus opacity.
struct LayerColor: Equatable {
	var name: NamedColor
	var custom: Color = .gray
	var opacity: Double = 1

	var resolved: Color {
		let base = name == .custom ? custom : name.color
		return base.opacity(name == .none ? 0 : opacity)
	}
}

enum SymbolBackground: String, CaseIterable, Identifiable, Codable {
	case `default`, light, dark, custom

	var id: Self { self }

	var title: String { rawValue.capitalized }
}

/// Variable value rendering, as in SF Symbols' variable row (`default`, `color`, `draw`).
enum VariableMode: String, CaseIterable, Identifiable, Codable {
	case `default`, color, draw

	var id: Self { self }

	var title: String { rawValue.capitalized }

	var symbolVariableValueMode: SymbolVariableValueMode? {
		switch self {
		case .default: nil
		case .color: .color
		case .draw: .draw
		}
	}
}

/// Rendering parameters applied to every symbol on screen, as in SF Symbols' rendering inspector.
struct SymbolStyle: Equatable {
	var weight: SymbolWeightOption = .regular
	var scale: SymbolScaleOption = .medium
	var rendering: SymbolRenderingStyle = .automatic
	/// Palette uses all three; the other modes use the first.
	var layers: [LayerColor] = [LayerColor(name: .primary), LayerColor(name: .accent), LayerColor(name: .none)]
	var usesVariableValue = false
	var variableValue: Double = 1
	var variableMode: VariableMode = .default
	var gradient = false
	var background: SymbolBackground = .default
	var customBackground: Color = Color(white: 0.5)

	var primary: Color {
		get { layers[0].resolved }
		set { layers[0] = LayerColor(name: .custom, custom: newValue) }
	}
	var secondary: Color { layers[1].resolved }
	var tertiary: Color { layers[2].resolved }

	/// Fill of symbol tiles and previews. `Default` matches the grid background (white, or #1E1E1E in Dark Mode).
	var backgroundColor: Color {
		switch background {
		case .default: Color(nsColor: .textBackgroundColor)
		case .light: .white
		case .dark: Color(white: 0.12)
		case .custom: customBackground
		}
	}

	/// The appearance symbols are drawn in on top of the background, so label colors such as Primary
	/// resolve to black on Light and white on Dark. `nil` follows the window.
	var backgroundColorScheme: ColorScheme? {
		switch background {
		case .default: nil
		case .light: .light
		case .dark: .dark
		case .custom:
			// Relative (linear) luminance, so mid gray counts as dark, as in SF Symbols.
			NSColor(customBackground).usingColorSpace(.sRGB).map { color in
				func linear(_ c: CGFloat) -> CGFloat { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
				let luminance = 0.2126 * linear(color.redComponent) + 0.7152 * linear(color.greenComponent) + 0.0722 * linear(color.blueComponent)
				return luminance > 0.5 ? ColorScheme.light : .dark
			} ?? .dark
		}
	}

	func with(weight: SymbolWeightOption) -> SymbolStyle {
		var style = self
		style.weight = weight
		return style
	}

	func with(rendering: SymbolRenderingStyle) -> SymbolStyle {
		var style = self
		style.rendering = rendering
		return style
	}
}
