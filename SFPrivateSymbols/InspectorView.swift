//
//  InspectorView.swift
//  SFPrivateSymbols
//
//  Layout mirrors SF Symbols' RightSidebarView: a fixed header (tab picker, preview) above a grouped Form.
//

import SwiftUI

enum InspectorTab: String, CaseIterable, Identifiable {
	case info
	case rendering
	case animation

	var id: Self { self }

	var title: String {
		switch self {
		case .info: "Info"
		case .rendering: "Rendering"
		case .animation: "Animation"
		}
	}

	/// Same symbols as SF Symbols' inspector. `animation` is a custom symbol in SF Symbols.app's
	/// embedded SFSymbolsShared.framework, so it's loaded from there when installed.
	var icon: Image {
		switch self {
		case .info:
			Image(systemName: "info")
		case .rendering:
			Image(systemName: "paintbrush")
		case .animation:
			Self.animationIcon
		}
	}

	static var animationIcon: Image {
		if let bundle = sfSymbolsSharedBundle, NSImage(symbolName: "animation", bundle: bundle, variableValue: 1) != nil {
			Image("animation", bundle: bundle)
		} else {
			Image(systemName: "dot.radiowaves.left.and.right")
		}
	}

	private static let sfSymbolsSharedBundle: Bundle? = {
		let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.SFSymbols")
			?? URL(fileURLWithPath: "/Applications/SF Symbols.app")
		return Bundle(url: app.appending(path: "Contents/Frameworks/SFSymbolsShared.framework"))
	}()
}

struct InspectorView: View {
	@Environment(AppModel.self) private var model
	@State private var tab: InspectorTab = {
		#if DEBUG
		if let tab = UserDefaults.standard.string(forKey: "DebugInspectorTab").flatMap(InspectorTab.init(rawValue:)) {
			return tab
		}
		#endif
		return .info
	}()
	@State private var animation = AnimationSettings()
	@State private var player = AnimationPlayer()

	var body: some View {
		VStack(spacing: 0) {
			header
				.padding(.horizontal, 12)
				.padding(.top, 16)
				.padding(.bottom, 8)

			if tab == .info {
				Divider()
			}

			// As in SF Symbols, only Info needs a selection; Rendering and Animation always show their settings.
			switch tab {
			case .info:
				if let symbol = model.selectedSymbol {
					SymbolInfoForm(symbol: symbol)
				} else {
					Text("No Selection")
						.font(.title3)
						.foregroundStyle(.tertiary)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			case .rendering:
				RenderingForm()
			case .animation:
				AnimationForm(symbol: model.selectedSymbol, settings: $animation, player: player)
			}
		}
		#if DEBUG
		.task {
			// e.g. `-DebugAnimation wiggle` plays that effect continuously.
			if let effect = UserDefaults.standard.string(forKey: "DebugAnimation").flatMap(SymbolAnimation.init(rawValue:)) {
				animation.effect = effect
				animation.repeatMode = .continuously
				try? await Task.sleep(for: .milliseconds(500))
				player.togglePlayback(animation)
			}
		}
		#endif
		.onChange(of: model.selectedSymbolName) { player.reset(for: animation) }
		.onChange(of: animation.effect) { player.reset(for: animation) }
		.onChange(of: tab) { player.reset(for: animation) }
	}

	private var header: some View {
		VStack(spacing: 8) {
			Picker("Inspector", selection: $tab) {
				ForEach(InspectorTab.allCases) { tab in
					tab.icon
						.help("Show the \(tab.title) Inspector")
						.tag(tab)
				}
			}
			.pickerStyle(.segmented)
			.labelsHidden()
			.buttonSizing(.flexible)

			if let symbol = model.selectedSymbol {
				switch tab {
				case .info:
					PreviewBox(height: 130) {
						SymbolImage(name: symbol.name, style: model.style, pointSize: 64)
					}
					Text(symbol.name)
						.font(.headline)
						.textSelection(.enabled)
						.lineLimit(2)
						.multilineTextAlignment(.center)
				case .rendering:
					RenderingModeStrip(symbol: symbol, animation: nil, player: nil)
				case .animation:
					RenderingModeStrip(symbol: symbol, animation: animation, player: player)
				}
			}
		}
	}
}

/// Rounded, stroked box with the user-selected symbol background, as in SF Symbols' preview header.
struct PreviewBox<Content: View>: View {
	@Environment(AppModel.self) private var model
	let height: CGFloat
	@ViewBuilder var content: Content

	var body: some View {
		content
			.symbolBackgroundAppearance(model.style)
			.frame(maxWidth: .infinity)
			.frame(height: height)
			.background(previewBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
			.overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
	}

	/// The inspector preview is darker than tiles by default, as in SF Symbols.
	private var previewBackground: Color {
		model.style.background == .default ? Color(nsColor: .textBackgroundColor) : model.style.backgroundColor
	}
}

/// The four rendering modes side by side; the current one is marked with a dot, tapping one selects it.
struct RenderingModeStrip: View {
	@Environment(AppModel.self) private var model
	let symbol: PrivateSymbol
	let animation: AnimationSettings?
	let player: AnimationPlayer?

	var body: some View {
		PreviewBox(height: 90) {
			HStack(spacing: 0) {
				ForEach(SymbolRenderingStyle.concrete) { mode in
					Spacer().frame(width: 8)
					VStack(spacing: 0) {
						symbolView(mode)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
							.padding(4)
						Circle()
							.fill(isCurrent(mode) ? Color.accentColor : .clear)
							.frame(width: 8, height: 8)
							.padding(4)
					}
					.contentShape(Rectangle())
					.onTapGesture { model.style.rendering = mode }
					.help(mode.title)
				}
				Spacer().frame(width: 8)
			}
		}
	}

	@ViewBuilder
	private func symbolView(_ mode: SymbolRenderingStyle) -> some View {
		let image = SymbolImage(
			name: player?.replaced == true ? (symbol.fillVariant ?? symbol.outlineVariant ?? symbol.name) : symbol.name,
			style: model.style.with(rendering: mode),
			pointSize: 30
		)
		if let animation, let player {
			image.modifier(SymbolAnimationModifier(settings: animation, player: player))
		} else {
			image
		}
	}

	private func isCurrent(_ mode: SymbolRenderingStyle) -> Bool {
		model.style.rendering == mode || (model.style.rendering == .automatic && mode == (symbol.isMulticolor ? .multicolor : .monochrome))
	}
}

// MARK: - Info

struct SymbolInfoForm: View {
	@Environment(AppModel.self) private var model
	let symbol: PrivateSymbol

	var body: some View {
		Form {
			if !symbol.localizedVariants.isEmpty {
				Section("Localization") {
					LocalizationRow(name: symbol.name, title: "Latin")
					ForEach(symbol.localizedVariants.sorted { $0.scriptName < $1.scriptName }, id: \.name) { variant in
						LocalizationRow(name: variant.name, title: variant.scriptName)
					}
				}
			}

			Section("Availability") {
				ForEach([symbol.name] + symbol.aliases, id: \.self) { name in
					AvailabilityGroup(symbol: symbol, name: name, isExpanded: name == symbol.name)
				}
			}

			if let restriction = symbol.restriction {
				Section("Usage Restrictions") {
					Text(restriction)
						.foregroundStyle(.secondary)
				}
			}

			if !symbol.categories.isEmpty {
				Section("Categories") {
					FlowLayout(spacing: 6) {
						ForEach(symbol.categories, id: \.self) { key in
							Button(SymbolCatalog.label(forCategory: key)) {
								let name = symbol.name
								model.sidebarSelection = .category(key)
								model.selectedSymbolName = name
							}
							.buttonStyle(TagButtonStyle())
						}
					}
				}
			}

			if !symbol.keywords.isEmpty {
				Section("Search Terms") {
					FlowLayout(spacing: 6) {
						ForEach(symbol.keywords, id: \.self) { keyword in
							Button(keyword) { model.searchText = keyword }
								.buttonStyle(TagButtonStyle())
						}
					}
				}
			}

			let variants = [("Fill", symbol.fillVariant), ("Outline", symbol.outlineVariant)].compactMap { title, name in name.map { (title, $0) } }
			if !variants.isEmpty {
				Section("Variants") {
					ForEach(variants, id: \.1) { title, name in
						Button {
							model.selectedSymbolName = name
						} label: {
							LabeledContent {
								Text(title).foregroundStyle(.secondary)
							} label: {
								Label {
									Text(name)
								} icon: {
									SymbolImage(name: name, style: model.style, pointSize: 15)
								}
							}
						}
						.buttonStyle(.plain)
					}
				}
			}

			Section("Code") {
				CodeRow(title: "SwiftUI", code: SymbolExport.swiftUICode(symbol.name))
				CodeRow(title: "AppKit", code: SymbolExport.appKitCode(symbol.name))
				CodeRow(title: "UIKit", code: SymbolExport.uiKitCode(symbol.name))
			}
		}
		.formStyle(.grouped)
	}
}

private struct LocalizationRow: View {
	@Environment(AppModel.self) private var model
	let name: String
	let title: String

	var body: some View {
		Button {
			model.selectedSymbolName = name
		} label: {
			HStack(spacing: 12) {
				SymbolImage(name: name, style: model.style, pointSize: 20)
					.frame(width: 28, height: 41)
				Text(title)
				Spacer()
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.help(name)
	}
}

/// Name → rendering mode → platform, like SF Symbols' availability outline.
private struct AvailabilityGroup: View {
	@Environment(AppModel.self) private var model
	let symbol: PrivateSymbol
	let name: String
	@State var isExpanded: Bool

	var body: some View {
		if let key = model.catalog.releaseKey(forName: name) ?? (name == symbol.name ? symbol.releaseYear : nil) {
			DisclosureGroup(isExpanded: $isExpanded) {
				ForEach(modes(from: key), id: \.0) { mode, release in
					ModeAvailabilityRow(title: mode, release: release)
						.padding(.leading, 13)
				}
			} label: {
				Text(name)
					.textSelection(.enabled)
			}
		} else {
			LabeledContent(name) {
				Text("Unknown").foregroundStyle(.secondary)
			}
		}
	}

	/// The private bundle has no per-mode (layerset) availability, so layered modes are dated from
	/// the later of the symbol's release and the release that introduced the mode.
	private func modes(from key: String) -> [(String, String)] {
		func atLeast(_ minimum: String) -> String {
			(Double(key) ?? 0) >= (Double(minimum) ?? 0) ? key : minimum
		}
		var modes = [("Monochrome", key), ("Hierarchical", atLeast("2021")), ("Palette", atLeast("2021"))]
		if symbol.isMulticolor {
			modes.append(("Multicolor", atLeast("2021")))
		}
		return modes
	}
}

private struct ModeAvailabilityRow: View {
	@Environment(AppModel.self) private var model
	let title: String
	let release: String
	@State private var isExpanded = false

	var body: some View {
		DisclosureGroup(isExpanded: $isExpanded) {
			ForEach(model.catalog.platformReleases(forRelease: release), id: \.platform) { platform in
				LabeledContent(platform.platform) {
					Text(platform.version).foregroundStyle(.secondary)
				}
				.padding(.leading, 13)
			}
		} label: {
			LabeledContent(title) {
				Text(SymbolCatalog.sfSymbolsVersion(forRelease: release))
					.foregroundStyle(.secondary)
					.monospacedDigit()
			}
		}
	}
}

private struct CodeRow: View {
	let title: String
	let code: String

	var body: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 2) {
				Text(title).font(.caption).foregroundStyle(.secondary)
				Text(code)
					.font(.system(.caption, design: .monospaced))
					.textSelection(.enabled)
					.fixedSize(horizontal: false, vertical: true)
			}
			Spacer(minLength: 4)
			Button {
				SymbolExport.copyString(code)
			} label: {
				Image(systemName: "doc.on.doc")
			}
			.buttonStyle(.borderless)
			.help("Copy \(title) Code")
		}
	}
}

struct TagButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.callout)
			.padding(.horizontal, 8)
			.padding(.vertical, 3)
			.background(
				Capsule().fill(Color(nsColor: .quaternarySystemFill).opacity(configuration.isPressed ? 2 : 1))
			)
			.overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor)))
	}
}

/// Left-to-right wrapping layout for tags.
struct FlowLayout: Layout {
	var spacing: CGFloat = 6

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
		let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
		let height = rows.last.map { $0.y + $0.height } ?? 0
		let width = rows.map(\.width).max() ?? 0
		return CGSize(width: proposal.width ?? width, height: height)
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
		let rows = arrange(width: bounds.width, subviews: subviews)
		for row in rows {
			var x = bounds.minX
			for index in row.indices {
				let size = subviews[index].sizeThatFits(.unspecified)
				subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
				x += size.width + spacing
			}
		}
	}

	private struct Row {
		var indices: [Int] = []
		var y: CGFloat = 0
		var width: CGFloat = 0
		var height: CGFloat = 0
	}

	private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
		var rows: [Row] = []
		var current = Row()
		for (index, subview) in subviews.enumerated() {
			let size = subview.sizeThatFits(.unspecified)
			if !current.indices.isEmpty && current.width + spacing + size.width > width {
				rows.append(current)
				current = Row(y: current.y + current.height + spacing)
			}
			current.width += (current.indices.isEmpty ? 0 : spacing) + size.width
			current.height = max(current.height, size.height)
			current.indices.append(index)
		}
		if !current.indices.isEmpty {
			rows.append(current)
		}
		return rows
	}
}

// MARK: - Rendering

struct RenderingForm: View {
	@Environment(AppModel.self) private var model

	var body: some View {
		@Bindable var model = model

		Form {
			Section {
				Picker(selection: $model.style.rendering) {
					Text(SymbolRenderingStyle.automatic.title).tag(SymbolRenderingStyle.automatic)
					Divider()
					ForEach(SymbolRenderingStyle.concrete) { mode in
						Text(mode.title).tag(mode)
					}
				} label: {
					Label("Rendering Mode", systemImage: "paintpalette")
				}

				Toggle(isOn: $model.style.gradient) {
					Label {
						Text("Gradients")
					} icon: {
						Image(systemName: "circle.fill")
							.foregroundStyle(Color.accentColor.gradient)
					}
				}

				Toggle(isOn: $model.style.usesVariableValue) {
					Label("Variable", systemImage: "slider.horizontal.below.square.and.square.filled")
				}

				if model.style.usesVariableValue {
					HStack {
						Picker("Variable Mode", selection: $model.style.variableMode) {
							ForEach(VariableMode.allCases) { Text($0.title).tag($0) }
						}
						.labelsHidden()
						.fixedSize()
						Slider(value: $model.style.variableValue, in: 0...1)
						PercentField(value: $model.style.variableValue)
					}
				}
			}

			Section {
				if model.style.rendering == .palette {
					LabeledContent("Colors") {
						VStack(alignment: .trailing) {
							ForEach(0..<3, id: \.self) { index in
								LayerColorRow(layer: $model.style.layers[index], allowsNone: index > 0, scheme: model.style.backgroundColorScheme)
							}
						}
					}
				} else {
					LabeledContent("Color") {
						LayerColorRow(layer: $model.style.layers[0], allowsNone: false, scheme: model.style.backgroundColorScheme)
					}
				}
			}

			Section {
				LabeledContent("Background") {
					HStack {
						Picker("Background", selection: $model.style.background) {
							ForEach(SymbolBackground.allCases) { background in
								Label {
									Text(background.title)
								} icon: {
									swatch(backgroundSwatch(background))
								}
								.tag(background)
							}
						}
						.labelsHidden()
						.fixedSize()

						if model.style.background == .custom {
							ColorPicker("Custom Background", selection: $model.style.customBackground)
								.labelsHidden()
								.frame(width: 62, height: 26)
						}
					}
				}
			}
		}
		.formStyle(.grouped)
	}

	private func backgroundSwatch(_ background: SymbolBackground) -> Color {
		switch background {
		case .default: Color(nsColor: .textBackgroundColor)
		case .light: .white
		case .dark: Color(white: 0.12)
		case .custom: .gray
		}
	}
}

/// Named color menu plus opacity field, as in SF Symbols' color rows.
private struct LayerColorRow: View {
	@Binding var layer: LayerColor
	let allowsNone: Bool
	/// Label colors (Primary…) are shown as they resolve on the current symbol background.
	let scheme: ColorScheme?

	var body: some View {
		HStack {
			if layer.name == .custom {
				ColorPicker("Custom Color", selection: $layer.custom)
					.labelsHidden()
			}
			Picker("Color", selection: $layer.name) {
				ForEach(NamedColor.system) { item($0) }
				Divider()
				ForEach(NamedColor.hierarchy) { item($0) }
				if allowsNone {
					item(.none)
				}
				Divider()
				item(.custom)
			}
			.labelsHidden()
			.fixedSize()

			PercentField(value: $layer.opacity)
				.disabled(layer.name == .none)
		}
	}

	private func item(_ color: NamedColor) -> some View {
		Label {
			Text(color.title)
		} icon: {
			swatch(color == .none ? .white : color == .custom ? layer.custom : color.color, scheme: scheme)
		}
		.tag(color)
	}
}

/// A colored dot usable inside menus, where SwiftUI drops foreground styles on symbol images.
func swatch(_ color: Color, scheme: ColorScheme? = nil) -> Image {
	let size = NSSize(width: 12, height: 12)
	let appearance = scheme.flatMap { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua) }
	var fill = NSColor(color)
	appearance?.performAsCurrentDrawingAppearance {
		fill = NSColor(cgColor: fill.cgColor) ?? fill
	}
	let image = NSImage(size: size, flipped: false) { rect in
		fill.setFill()
		NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
		NSColor.separatorColor.setStroke()
		NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).stroke()
		return true
	}
	return Image(nsImage: image)
}

/// 60 pt wide percentage field, as next to SF Symbols' sliders and color menus.
struct PercentField: View {
	@Binding var value: Double

	var body: some View {
		TextField("Percent", value: $value, format: .percent.precision(.fractionLength(0)))
			.labelsHidden()
			.textFieldStyle(.roundedBorder)
			.multilineTextAlignment(.center)
			.frame(width: 60)
	}
}
