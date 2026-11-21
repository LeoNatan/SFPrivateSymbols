//
//  SymbolImage.swift
//  SFPrivateSymbols
//

import SwiftUI
import UniformTypeIdentifiers

/// Renders a private system symbol with the current `SymbolStyle`.
struct SymbolImage: View {
	let name: String
	var style: SymbolStyle
	var pointSize: CGFloat

	var body: some View {
		image
			.symbolRenderingMode(style.rendering.symbolRenderingMode)
			.symbolColorRenderingMode(style.gradient ? .gradient : .flat)
			.symbolVariableValueMode(style.variableMode.symbolVariableValueMode)
			.font(.system(size: pointSize, weight: style.weight.weight))
			.imageScale(style.scale.scale)
			.modifier(SymbolForegroundModifier(style: style))
	}

	private var image: Image {
		if style.usesVariableValue {
			Image(_internalSystemName: name, variableValue: style.variableValue)
		} else {
			Image(_internalSystemName: name)
		}
	}
}

extension View {
	/// Draws in the appearance implied by the symbol background (Light → light, Dark → dark).
	@ViewBuilder
	func symbolBackgroundAppearance(_ style: SymbolStyle) -> some View {
		if let scheme = style.backgroundColorScheme {
			environment(\.colorScheme, scheme)
		} else {
			self
		}
	}
}

private struct SymbolForegroundModifier: ViewModifier {
	let style: SymbolStyle

	func body(content: Content) -> some View {
		if style.rendering == .palette {
			content.foregroundStyle(style.primary, style.secondary, style.tertiary)
		} else {
			content.foregroundStyle(style.primary)
		}
	}
}

/// Pasteboard and file export of symbols.
enum SymbolExport {
	static func copyName(_ names: [String]) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(names.joined(separator: "\n"), forType: .string)
	}

	static func swiftUICode(_ name: String) -> String {
		"Image(_internalSystemName: \"\(name)\")"
	}

	static func appKitCode(_ name: String) -> String {
		"NSImage.perform(NSSelectorFromString(\"imageWithPrivateSystemSymbolName:\"), with: \"\(name)\")?.takeUnretainedValue() as? NSImage"
	}

	static func uiKitCode(_ name: String) -> String {
		"UIImage.perform(NSSelectorFromString(\"_systemImageNamed:\"), with: \"\(name)\")?.takeUnretainedValue() as? UIImage"
	}

	static func copyString(_ string: String) {
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setString(string, forType: .string)
	}

	/// The appearance exports are drawn in: the symbol background's, or the window's.
	static func appearance(for style: SymbolStyle) -> NSAppearance {
		switch style.backgroundColorScheme {
		case .light: NSAppearance(named: .aqua)!
		case .dark: NSAppearance(named: .darkAqua)!
		default: NSApp.effectiveAppearance
		}
	}

	private static func colorScheme(for style: SymbolStyle) -> ColorScheme {
		appearance(for: style).bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
	}

	/// Edit > Copy (Copy Symbol): an SVG of the symbol as currently styled, at 100 pt.
	static func symbolSVG(_ name: String, style: SymbolStyle) -> Data? {
		SymbolTemplate.plainSVG(for: name, style: style, pointSize: 100, appearance: appearance(for: style))?.data(using: .utf8)
	}

	/// ⌘C on a symbol view: SVG, like SF Symbols' Copy Symbol.
	static func copyProviders(_ name: String?, style: SymbolStyle) -> [NSItemProvider] {
		guard let name, let svg = symbolSVG(name, style: style) else { return [] }
		return [NSItemProvider(item: svg as NSData, typeIdentifier: UTType.svg.identifier)]
	}

	static func copySymbol(_ name: String, style: SymbolStyle) {
		guard let svg = symbolSVG(name, style: style) else { return }
		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		pasteboard.setData(svg, forType: NSPasteboard.PasteboardType(UTType.svg.identifier))
	}

	static func pngData(_ name: String, style: SymbolStyle, pointSize: CGFloat, pixelScale: CGFloat) -> Data? {
		let content = SymbolImage(name: name, style: style, pointSize: pointSize)
			.environment(\.colorScheme, colorScheme(for: style))
		let renderer = ImageRenderer(content: content)
		renderer.scale = pixelScale
		guard let image = renderer.cgImage else { return nil }
		return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
	}

	/// Edit > Copy Image: PNG or SVG per the Copy Image settings, plus a file of the same, as SF Symbols does.
	static func copyImage(_ name: String, style: SymbolStyle) {
		let settings = CopyImageSettings()
		var style = style
		style.scale = settings.scale

		let data: Data?
		let type: UTType
		switch settings.format {
		case .png:
			data = pngData(name, style: style, pointSize: settings.pointSize, pixelScale: settings.pixelScale)
			type = .png
		case .svg:
			data = SymbolTemplate.plainSVG(for: name, style: style, pointSize: settings.pointSize, appearance: appearance(for: style))?
				.data(using: .utf8)
			type = .svg
		}
		guard let data else { return }

		let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
		let file = directory.appending(path: "\(name).\(type.preferredFilenameExtension ?? "png")")
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try? data.write(to: file)

		let pasteboard = NSPasteboard.general
		pasteboard.clearContents()
		let item = NSPasteboardItem()
		item.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
		item.setString(file.absoluteString, forType: .fileURL)
		pasteboard.writeObjects([item])
	}
}
