//
//  AppModel.swift
//  SFPrivateSymbols
//

import SwiftUI
import Observation

enum SidebarItem: Hashable, Codable {
	case category(String)
}

enum ViewMode: String, CaseIterable, Identifiable {
	case grid
	case list
	case gallery

	var id: Self { self }

	var title: String {
		switch self {
		case .grid: "Grid"
		case .list: "List"
		case .gallery: "Gallery"
		}
	}

	var icon: String {
		switch self {
		case .grid: "square.grid.2x2"
		case .list: "list.bullet"
		case .gallery: "squares.below.rectangle"
		}
	}
}

enum SymbolWeightOption: String, CaseIterable, Identifiable, Codable {
	case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black

	var id: Self { self }

	var title: String {
		switch self {
		case .ultraLight: "Ultralight"
		case .thin: "Thin"
		case .light: "Light"
		case .regular: "Regular"
		case .medium: "Medium"
		case .semibold: "Semibold"
		case .bold: "Bold"
		case .heavy: "Heavy"
		case .black: "Black"
		}
	}

	var weight: Font.Weight {
		switch self {
		case .ultraLight: .ultraLight
		case .thin: .thin
		case .light: .light
		case .regular: .regular
		case .medium: .medium
		case .semibold: .semibold
		case .bold: .bold
		case .heavy: .heavy
		case .black: .black
		}
	}
}

enum SymbolScaleOption: String, CaseIterable, Identifiable, Codable {
	case small, medium, large

	var id: Self { self }

	var title: String { rawValue.capitalized }

	var scale: Image.Scale {
		switch self {
		case .small: .small
		case .medium: .medium
		case .large: .large
		}
	}
}

@Observable
final class AppModel {
	let catalog: SymbolCatalog
	private let symbolsByName: [String: PrivateSymbol]

	var sidebarSelection: SidebarItem? = .category("all") {
		didSet { selectedSymbolName = nil }
	}
	var searchText = ""
	var selectedSymbolName: String?
	var viewMode: ViewMode = .grid
	var style = SymbolStyle()
	/// Grid item width; SF Symbols uses 100 × 140 items with 100 × 80 tiles.
	var tileSize: Double = 100
	var showsInspector = true
	var showsObfuscatedNames = true
	/// Presents the export proof sheet.
	var exportRequest: ExportKind?
	var showsCopyImageAs = false

	init(catalog: SymbolCatalog) {
		self.catalog = catalog
		self.symbolsByName = Dictionary(catalog.symbols.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
		#if DEBUG
		applyDebugLaunchArguments()
		#endif
	}

	#if DEBUG
	/// e.g. `-DebugSymbol apple.logo.shield.fill -DebugInspectorTab rendering -DebugViewMode list -DebugSearch airpods`
	private func applyDebugLaunchArguments() {
		let defaults = UserDefaults.standard
		if let category = defaults.string(forKey: "DebugCategory") {
			sidebarSelection = .category(category)
		}
		if let mode = defaults.string(forKey: "DebugViewMode").flatMap(ViewMode.init(rawValue:)) {
			viewMode = mode
		}
		if let search = defaults.string(forKey: "DebugSearch") {
			searchText = search
		}
		if let rendering = defaults.string(forKey: "DebugRendering").flatMap(SymbolRenderingStyle.init(rawValue:)) {
			style.rendering = rendering
		}
		if let background = defaults.string(forKey: "DebugBackground").flatMap(SymbolBackground.init(rawValue:)) {
			style.background = background
		}
		if let symbol = defaults.string(forKey: "DebugSymbol") {
			selectedSymbolName = symbol
		}
	}
	#endif

	func symbol(named name: String) -> PrivateSymbol? {
		symbolsByName[name]
	}

	var selectedSymbol: PrivateSymbol? {
		selectedSymbolName.flatMap { symbolsByName[$0] }
	}

	var title: String {
		switch sidebarSelection {
		case .category(let key):
			return SymbolCatalog.label(forCategory: key)
		case nil:
			return "All"
		}
	}

	/// Symbols for the current sidebar item, before search is applied.
	var scopeSymbols: [PrivateSymbol] {
		var result: [PrivateSymbol]
		switch sidebarSelection {
		case .category(let key) where key != "all":
			result = catalog.symbols.filter { $0.categories.contains(key) }
		default:
			result = catalog.symbols
		}
		if !showsObfuscatedNames {
			result.removeAll { $0.isObfuscated }
		}
		return result
	}

	/// The symbols currently displayed.
	var visibleSymbols: [PrivateSymbol] {
		let tokens = searchText
			.lowercased()
			.split(whereSeparator: { $0.isWhitespace })
			.map(String.init)
		let scope = scopeSymbols
		guard !tokens.isEmpty else { return scope }

		let matches = scope.filter { symbol in
			tokens.allSatisfy { symbol.searchText.contains($0) }
		}
		// Rank like SF Symbols: exact name, then name prefix, then name contains, then keyword-only matches.
		let query = tokens.joined(separator: ".")
		func rank(_ symbol: PrivateSymbol) -> Int {
			let name = symbol.name.lowercased()
			if name == query { return 0 }
			if name.hasPrefix(tokens[0]) { return 1 }
			if tokens.allSatisfy({ name.contains($0) }) { return 2 }
			return 3
		}
		return matches
			.map { (rank($0), $0) }
			.sorted { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.order < $1.1.order }
			.map(\.1)
	}
}
