//
//  SymbolCatalog.swift
//  SFPrivateSymbols
//

import AppKit
import ObjectiveC

/// A single private SF Symbol, with all the metadata the system bundles provide.
nonisolated struct PrivateSymbol: Identifiable, Hashable, Sendable {
	let name: String
	var id: String { name }

	/// Category keys (e.g. `devices`, `multicolor`) from `symbol_categories.plist`.
	var categories: [String] = []
	/// Search terms from `symbol_search.plist`.
	var keywords: [String] = []
	/// Release key (e.g. `2024.1`) from `name_availability.plist`.
	var releaseYear: String?
	/// Previous names of this symbol that still resolve to it (`name_aliases.strings`).
	var aliases: [String] = []
	/// The `.fill` counterpart, when one exists (`nofill_to_fill.strings`).
	var fillVariant: String?
	/// The outline counterpart, when this is a `.fill` variant.
	var outlineVariant: String?
	/// Descriptive name this semantic symbol maps to (`semantic_to_descriptive_name.strings`).
	var descriptiveName: String?
	/// Usage restriction text, if any.
	var restriction: String?
	/// Whether the symbol has a container recipe (`container_recipes.plist`).
	var containerShapes: [String] = []
	/// Localized variants of this symbol, as (locale suffix, full name).
	var localizedVariants: [LocalizedVariant] = []
	/// The symbol this one is a localized variant of (`foo` for `foo.ar`).
	var localizedBase: String?
	/// The base symbol this one is a variant of (`foo` for `foo.fill`, `foo.circle`, `foo.badge.plus`…).
	var familyBase: String?
	/// Variants of this base symbol, in symbol order. SF Symbols stacks a card behind such symbols
	/// and shows only the base while browsing.
	var familyVariants: [String] = []
	/// Index in `symbol_order.plist`; symbols missing from it sort last.
	var order: Int = .max

	var isMulticolor: Bool { categories.contains("multicolor") }
	var isVariable: Bool { categories.contains("variable") }
	var isNew: Bool { categories.contains("whatsnew") }

	/// Lowercased string searched by the search field.
	var searchText: String = ""

	/// Opaque, hash-like names that Apple uses for unannounced products.
	var isObfuscated: Bool {
		let head = name.split(separator: ".", maxSplits: 1).first ?? ""
		return head.count == 32 && head.allSatisfy { $0.isHexDigit && !$0.isLowercase }
	}
}

nonisolated struct SymbolCategory: Identifiable, Hashable, Sendable {
	let key: String
	let label: String
	let icon: String
	var id: String { key }
}

nonisolated struct LocalizedVariant: Hashable, Sendable {
	let locale: String
	let name: String

	var displayName: String { scriptName }

	/// Names as SF Symbols' Localization section shows them.
	var scriptName: String {
		switch locale {
		case "rtl": "Right-to-Left"
		case "mni": "Meitei"
		case "sat": "Ol Chiki"
		case "or": "Oriya"
		case "zh": "Chinese"
		default: Locale(identifier: "en").localizedString(forLanguageCode: locale) ?? locale
		}
	}
}

nonisolated struct PlatformRelease: Hashable, Sendable {
	let platform: String
	let version: String
}

/// Loads the private symbol catalog out of `CoreGlyphsPrivate.bundle`.
nonisolated final class SymbolCatalog: Sendable {
	static let privateBundleURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphsPrivate.bundle")
	static let publicBundleURL = URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle")

	let symbols: [PrivateSymbol]
	let categories: [SymbolCategory]
	/// Release key → platform → version, from `year_to_release`.
	let releases: [String: [String: String]]
	/// Symbol or alias name → release key, from `name_availability.plist`.
	let nameAvailability: [String: String]

	/// Name suffixes Apple uses for localized symbol variants.
	static let localeSuffixes: Set<String> = [
		"rtl", "ar", "he", "hi", "th", "ko", "zh", "ja", "el", "ru", "it", "es", "mr", "ml", "or",
		"gu", "mni", "sat", "ta", "te", "kn", "si", "bn", "pa", "ur", "km", "my", "zh.traditional",
	]

	static let platformOrder = ["iOS", "macOS", "tvOS", "watchOS", "visionOS"]

	/// English labels, as shown by Apple's SF Symbols app.
	private static let categoryLabels: [String: String] = [
		"all": "All",
		"whatsnew": "What’s New",
		"draw": "Draw",
		"variable": "Variable",
		"multicolor": "Multicolor",
		"communication": "Communication",
		"weather": "Weather",
		"maps": "Maps",
		"objectsandtools": "Objects & Tools",
		"devices": "Devices",
		"cameraandphotos": "Camera & Photos",
		"gaming": "Gaming",
		"connectivity": "Connectivity",
		"transportation": "Transportation",
		"automotive": "Automotive",
		"accessibility": "Accessibility",
		"privacyandsecurity": "Privacy & Security",
		"human": "Human",
		"home": "Home",
		"fitness": "Fitness",
		"nature": "Nature",
		"editing": "Editing",
		"textformatting": "Text Formatting",
		"media": "Media",
		"keyboard": "Keyboard",
		"commerce": "Commerce",
		"time": "Time",
		"health": "Health",
		"shapes": "Shapes",
		"arrows": "Arrows",
		"indices": "Indices",
		"math": "Math",
	]

	static func label(forCategory key: String) -> String {
		categoryLabels[key] ?? key.capitalized
	}

	init() {
		let resources = Self.privateBundleURL.appending(path: "Contents/Resources")
		let publicResources = Self.publicBundleURL.appending(path: "Contents/Resources")

		func plist<T>(_ name: String, in dir: URL = resources, as: T.Type = T.self) -> T? {
			guard let data = try? Data(contentsOf: dir.appending(path: name)) else { return nil }
			return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? T
		}

		let order = plist("symbol_order.plist", as: [String].self) ?? []
		let categoryMap = plist("symbol_categories.plist", as: [String: [String]].self) ?? [:]
		let search = plist("symbol_search.plist", as: [String: [String]].self) ?? [:]
		let availability = plist("name_availability.plist", as: [String: Any].self) ?? [:]
		let availabilitySymbols = availability["symbols"] as? [String: String] ?? [:]
		let aliases = plist("name_aliases.strings", as: [String: String].self) ?? [:]
		let fills = plist("nofill_to_fill.strings", as: [String: String].self) ?? [:]
		let semantic = plist("semantic_to_descriptive_name.strings", as: [String: String].self) ?? [:]
		let restrictions = plist("symbol_restrictions.strings", as: [String: String].self) ?? [:]
		let containers = (plist("container_recipes.plist", as: [String: Any].self)?["symbols"] as? [String: Any]) ?? [:]

		var releases = availability["year_to_release"] as? [String: [String: String]] ?? [:]
		if releases.isEmpty {
			let publicAvailability = plist("name_availability.plist", in: publicResources, as: [String: Any].self) ?? [:]
			releases = publicAvailability["year_to_release"] as? [String: [String: String]] ?? [:]
		}
		self.releases = releases
		self.nameAvailability = availabilitySymbols

		// The asset catalog is the ground truth; metadata lists can lag behind it.
		var names = order
		var known = Set(order)
		for name in Self.catalogGlyphNames() where !known.contains(name) {
			names.append(name)
			known.insert(name)
		}

		var aliasesByTarget: [String: [String]] = [:]
		for (old, new) in aliases {
			aliasesByTarget[new, default: []].append(old)
		}
		let outlineByFill = Dictionary(fills.map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
		let orderIndex = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })

		// `foo.ar`, `foo.rtl`, … are localized variants of `foo`.
		let nameSet = Set(names)
		var variantsByBase: [String: [LocalizedVariant]] = [:]
		var localizedBases: [String: String] = [:]
		for name in names {
			guard let dot = name.lastIndex(of: ".") else { continue }
			let base = String(name[..<dot])
			let suffix = String(name[name.index(after: dot)...])
			if Self.localeSuffixes.contains(suffix) && nameSet.contains(base) {
				variantsByBase[base, default: []].append(LocalizedVariant(locale: suffix, name: name))
				localizedBases[name] = base
			}
		}

		// Families: `base.<suffix>` is a variant of `base` when the suffix is one SF Symbols uses for
		// variants. The shortest existing base wins, so `foo.circle.fill` belongs to `foo`, not `foo.circle`.
		// (Checked against SF Symbols' own map for public symbols: 97% precision, 99% recall.)
		var familyBases: [String: String] = [:]
		var familyVariants: [String: [String]] = [:]
		for name in names where localizedBases[name] == nil {
			let parts = name.split(separator: ".", omittingEmptySubsequences: false)
			for split in parts.indices.dropFirst() {
				let base = parts[..<split].joined(separator: ".")
				guard nameSet.contains(base), localizedBases[base] == nil,
					  Self.familySuffixes.contains(parts[split...].joined(separator: ".")) else { continue }
				familyBases[name] = base
				familyVariants[base, default: []].append(name)
				break
			}
		}

		self.symbols = names.map { name in
			var symbol = PrivateSymbol(name: name)
			symbol.categories = categoryMap[name] ?? []
			symbol.keywords = search[name] ?? []
			symbol.releaseYear = availabilitySymbols[name]
			symbol.aliases = (aliasesByTarget[name] ?? []).sorted()
			symbol.fillVariant = fills[name]
			symbol.outlineVariant = outlineByFill[name]
			symbol.descriptiveName = semantic[name]
			symbol.restriction = restrictions[name]
			symbol.order = orderIndex[name] ?? .max
			symbol.localizedVariants = variantsByBase[name] ?? []
			symbol.localizedBase = localizedBases[name]
			symbol.familyBase = familyBases[name]
			symbol.familyVariants = (familyVariants[name] ?? []).sorted { (orderIndex[$0] ?? .max) < (orderIndex[$1] ?? .max) }
			if let recipe = containers[name] as? [String: Any], let shapes = recipe["shapes"] as? [String: Any] {
				symbol.containerShapes = shapes.keys.sorted()
			}
			symbol.searchText = ([name] + symbol.keywords + symbol.aliases + [symbol.descriptiveName ?? ""])
				.joined(separator: " ")
				.lowercased()
			return symbol
		}

		// Category definitions (key + icon) come from the public bundle, which defines the canonical order.
		let publicCategories = plist("categories.plist", in: publicResources, as: [[String: String]].self) ?? []
		let used = Set(categoryMap.values.joined())
		var categories: [SymbolCategory] = publicCategories.compactMap { entry in
			guard let key = entry["key"], key == "all" || used.contains(key) else { return nil }
			return SymbolCategory(key: key, label: Self.label(forCategory: key), icon: entry["icon"] ?? "square.grid.2x2")
		}
		// Any private-only category keys the public list doesn't know about.
		let listed = Set(categories.map(\.key))
		for key in used.subtracting(listed).sorted() {
			categories.append(SymbolCategory(key: key, label: Self.label(forCategory: key), icon: "questionmark.square.dashed"))
		}
		if categories.first?.key != "all" {
			categories.insert(SymbolCategory(key: "all", label: "All", icon: "square.grid.2x2"), at: 0)
		}
		self.categories = categories
	}

	/// SF Symbols version for a release key: `2019` → 1.0 … `2025` → 7.0, then year-based (`2026` → 27.0).
	static func sfSymbolsVersion(forRelease key: String) -> String {
		let parts = key.split(separator: ".")
		guard let year = parts.first.flatMap({ Int($0) }) else { return key }
		let major = year <= 2025 ? year - 2018 : year - 1999
		let minor = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
		return "\(major).\(minor)"
	}

	/// The release key of `name` itself (aliases carry their own availability).
	func releaseKey(forName name: String) -> String? {
		nameAvailability[name]
	}

	func platformReleases(forRelease key: String) -> [PlatformRelease] {
		guard let map = releases[key] else { return [] }
		return Self.platformOrder.compactMap { platform in
			map[platform].map { PlatformRelease(platform: platform, version: $0) }
		}
	}

	func platformReleases(for symbol: PrivateSymbol) -> [PlatformRelease] {
		guard let year = symbol.releaseYear, let map = releases[year] else { return [] }
		return Self.platformOrder.compactMap { platform in
			map[platform].map { PlatformRelease(platform: platform, version: $0) }
		}
	}

	/// Enumerates the vector glyph names in the private `Assets.car` through CoreUI.
	private static func catalogGlyphNames() -> [String] {
		let selector = NSSelectorFromString("defaultUICatalogForBundle:")
		guard dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW) != nil,
			  let catalogClass = NSClassFromString("CUICatalog") as? NSObject.Type,
			  catalogClass.responds(to: selector),
			  let bundle = Bundle(url: privateBundleURL),
			  let catalog = catalogClass.perform(selector, with: bundle)?.takeUnretainedValue() as? NSObject,
			  let names = catalog.value(forKey: "allImageNames") as? [String] else {
			return []
		}

		// Skip internal assets such as `_gradient.highlegibility` and packed-asset atlases.
		return names
			.filter { !$0.hasPrefix("_") && !$0.hasPrefix("ZZZZPackedAsset") }
			.sorted()
	}
}
