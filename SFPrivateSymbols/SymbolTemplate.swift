//
//  SymbolTemplate.swift
//  SFPrivateSymbols
//
//  Writes SF Symbols SVG templates (the format Xcode imports into `.symbolset`s) and plain SVGs.
//

import AppKit
import SwiftUI

/// Template format versions, as offered by SF Symbols' export sheets.
enum TemplateVersion: Int, CaseIterable, Identifiable {
	case v2 = 2, v3, v4, v5, v6, v7

	var id: Self { self }

	/// “Compatibility” menu of Export Template.
	var sfSymbolsTitle: String { "SF Symbols \(rawValue)" }

	/// “Export for” menu of Export Symbol.
	var xcodeTitle: String {
		self == .v7 ? "Xcode 26 and newer" : "Xcode \(xcodeVersion)"
	}

	var xcodeVersion: Int {
		switch self {
		case .v2: 12
		case .v3: 13
		case .v4: 14
		case .v5: 15
		case .v6: 16
		case .v7: 26
		}
	}

	/// Layer annotations (hierarchical, multicolor) exist from template 3.0 on.
	var supportsLayerAnnotations: Bool { rawValue >= 3 }
}

enum TemplateSetup: String, CaseIterable, Identifiable {
	/// Ultralight, Regular and Black at small scale; Xcode interpolates the rest.
	case variable
	/// All 27 weight and scale combinations.
	case `static`

	var id: Self { self }
	var title: String { rawValue.capitalized }
}

enum SymbolTemplate {
	static let masters: [(SymbolWeightOption, SymbolScaleOption)] = [(.ultraLight, .small), (.regular, .small), (.black, .small)]

	/// Column centers of the weights in the 3300 × 2200 template artboard.
	private static let columnCenters: [SymbolWeightOption: CGFloat] = [
		.ultraLight: 559.711, .thin: 856.422, .light: 1153.13, .regular: 1449.84, .medium: 1746.56,
		.semibold: 2043.27, .bold: 2339.98, .heavy: 2636.69, .black: 2933.4,
	]
	private static let baselines: [SymbolScaleOption: CGFloat] = [.small: 696, .medium: 1126, .large: 1556]
	private static let capHeight: CGFloat = 70.459

	/// The “A” drawn at the start of each guide row for size reference.
	private static let referenceGlyph = "M0.993654 0L3.63775 0L29.3281-67.1323L30.0303-67.1323L30.0303-70.459L28.1226-70.459ZM11.6885-24.4799L46.9815-24.4799L46.2315-26.7285L12.4385-26.7285ZM55.1196 0L57.7637 0L30.6382-70.459L29.4326-70.459L29.4326-67.1323Z"

	static func variants(for setup: TemplateSetup) -> [(SymbolWeightOption, SymbolScaleOption)] {
		switch setup {
		case .variable:
			masters
		case .static:
			SymbolScaleOption.allCases.flatMap { scale in SymbolWeightOption.allCases.map { ($0, scale) } }
		}
	}

	/// Oldest template version that can express the symbol: layered symbols need 3.0.
	static func minimumVersion(for name: String) -> TemplateVersion {
		guard let outline = GlyphOutline.load(name, weight: .regular, scale: .small) else { return .v2 }
		return outline.layers.count > 1 && !outline.hasEraserLayers ? .v3 : .v2
	}

	static func svg(for name: String, version: TemplateVersion, setup requestedSetup: TemplateSetup) -> String? {
		// Template 2.0 has no interpolation between masters; Xcode requires every weight and scale.
		let setup = version == .v2 ? .static : requestedSetup
		var guides: [String] = []
		var symbols: [String] = []
		var styles: [String] = []

		for scale in SymbolScaleOption.allCases {
			let baseline = baselines[scale]!
			guides.append("""
				  <g id="H-reference" style="fill:#27AAE1;stroke:none;" transform="matrix(1 0 0 1 339 \(n(baseline)))">
				   <path d="\(referenceGlyph)"/>
				  </g>
				  <line id="Baseline-\(scale.templateSuffix)" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="\(n(baseline))" y2="\(n(baseline))"/>
				  <line id="Capline-\(scale.templateSuffix)" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="\(n(baseline - capHeight))" y2="\(n(baseline - capHeight))"/>
				""")
		}

		for (weight, scale) in variants(for: setup).reversed() {
			guard let outline = GlyphOutline.load(name, weight: weight, scale: scale) else { return nil }
			let baseline = baselines[scale]!
			let left = columnCenters[weight]! - outline.contentBounds.width / 2
			let right = left + outline.contentBounds.width
			let id = "\(weight.templateName)-\(scale.templateSuffix)"

			guides.append("""
				  <line id="right-margin-\(id)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(n(right))" x2="\(n(right))" y1="\(n(baseline - 95.215))" y2="\(n(baseline + 24.121))"/>
				  <line id="left-margin-\(id)" style="fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;" x1="\(n(left))" x2="\(n(left))" y1="\(n(baseline - 95.215))" y2="\(n(baseline + 24.121))"/>
				""")

			// Group space: x from the left margin, y down from the baseline. CoreUI outlines are y-down
			// from the top of the alignment rect, whose bottom sits `baselineOffset` below the baseline.
			let originX = outline.alignmentRect.minX - outline.contentBounds.minX
			let top = outline.baselineOffset - outline.alignmentRect.height
			let toGroup: (CGPoint) -> CGPoint = { CGPoint(x: originX + $0.x, y: top + $0.y) }

			var paths: [String] = []
			if version.supportsLayerAnnotations && !outline.hasEraserLayers && !outline.layers.isEmpty {
				for layer in outline.layers {
					let classes = [
						"monochrome-\(layer.index)",
						"multicolor-\(layer.index):\(layer.multicolorName)",
						"hierarchical-\(layer.index):\(layer.hierarchicalLevelName)",
					]
					paths.append("   <path class=\"\(classes.joined(separator: " "))\" d=\"\(layer.path.svgPathData(toGroup))\"/>")
					if weight == .regular && scale == .small {
						styles.append(".monochrome-\(layer.index) {-sfsymbols-motion-group:\(layer.index)}")
						if let fill = layer.multicolorFill, let hex = hex(fill) {
							styles.append(".multicolor-\(layer.index):\(layer.multicolorName) {fill:\(hex);opacity:\(n(layer.opacity))}")
						}
						styles.append(".hierarchical-\(layer.index):\(layer.hierarchicalLevelName) {fill:#000000}")
					}
				}
			} else {
				let monochromeClass = version.supportsLayerAnnotations ? " class=\"monochrome-0 multicolor-0:tintColor hierarchical-0:primary\"" : ""
				paths.append("   <path\(monochromeClass) d=\"\(outline.path.svgPathData(toGroup))\"/>")
			}

			symbols.append("""
				  <g id="\(id)" transform="matrix(1 0 0 1 \(n(left)) \(n(baseline)))">
				\(paths.joined(separator: "\n"))
				  </g>
				""")
		}

		let weightLabels = SymbolWeightOption.allCases.map { weight in
			"  <text style=\"stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:middle;\" transform=\"matrix(1 0 0 1 \(n(columnCenters[weight]!)) 322)\">\(weight.title)</text>"
		}

		return """
			<?xml version="1.0" encoding="UTF-8"?>
			<!DOCTYPE svg
			PUBLIC "-//W3C//DTD SVG 1.1//EN"
			       "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
			<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 3300 2200">
			 <!--glyph: "\(name)", point size: 100.0, generated by SF Private Symbols-->
			 <style>.SFSymbolsPreviewWireframe {fill:none;opacity:1.0;stroke:black;stroke-width:0.5}
			\(styles.joined(separator: "\n"))
			</style>
			 <g id="Notes">
			  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
			  <line style="fill:none;stroke:black;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="292" y2="292"/>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Weight/Scale Variations</text>
			\(weightLabels.joined(separator: "\n"))
			  <line style="fill:none;stroke:black;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1903" y2="1903"/>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;font-weight:bold;" transform="matrix(1 0 0 1 263 1953)">Design Variations</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1971)">Symbols are supported in up to nine weights and three scales.</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1989)">For optimal layout with text and other symbols, vertically align</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 2007)">symbols with the adjacent text.</text>
			  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.\(version.rawValue).0</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1951)">Requires Xcode \(version.xcodeVersion) or greater</text>
			  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1969)">Generated from \(name)</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1987)">Typeset at 100.0 points</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 726)">Small</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1156)">Medium</text>
			  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1586)">Large</text>
			 </g>
			 <g id="Guides">
			\(guides.joined(separator: "\n"))
			 </g>
			 <g id="Symbols">
			\(symbols.joined(separator: "\n"))
			 </g>
			</svg>

			"""
	}

	/// A tight SVG of the symbol as currently styled, like SF Symbols' Copy Symbol.
	static func plainSVG(for name: String, style: SymbolStyle, pointSize: CGFloat, appearance: NSAppearance) -> String? {
		guard let outline = GlyphOutline.load(name, weight: style.weight, scale: style.scale, pointSize: pointSize) else { return nil }
		let width = outline.contentBounds.width
		let height = outline.contentBounds.height
		let originX = outline.alignmentRect.minX - outline.contentBounds.minX
		let originY = outline.alignmentRect.minY - outline.contentBounds.minY
		// CoreUI outlines are already y-down, like SVG.
		let transform: (CGPoint) -> CGPoint = { CGPoint(x: originX + $0.x, y: originY + $0.y) }

		var paths: [String] = []
		let layers = outline.hasEraserLayers || outline.layers.isEmpty ? [] : outline.layers
		if layers.isEmpty {
			let (fill, opacity) = resolve(style.layers[0].resolved, appearance)
			paths.append("  <path d=\"\(outline.path.svgPathData(transform))\" fill=\"\(fill)\" fill-opacity=\"\(n(opacity))\"/>")
		} else {
			for layer in layers {
				let (fill, opacity) = layerFill(layer, style: style, appearance: appearance)
				paths.append("  <path d=\"\(layer.path.svgPathData(transform))\" fill=\"\(fill)\" fill-opacity=\"\(n(opacity))\"/>")
			}
		}

		return """
			<?xml version="1.0" encoding="UTF-8"?>
			<svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(n(width)) \(n(height))">
			 <g>
			  <rect height="\(n(height))" opacity="0" width="\(n(width))" x="0" y="0"/>
			\(paths.joined(separator: "\n"))
			 </g>
			</svg>

			"""
	}

	private static func layerFill(_ layer: GlyphLayer, style: SymbolStyle, appearance: NSAppearance) -> (String, CGFloat) {
		let rendering = style.rendering == .automatic ? SymbolRenderingStyle.monochrome : style.rendering
		switch rendering {
		case .multicolor:
			if let fill = layer.multicolorFill, let hex = hex(fill) {
				return (hex, fill.alpha * layer.opacity)
			}
			return resolve(style.layers[0].resolved, appearance)
		case .palette:
			let slot = min(layer.hierarchyLevel, style.layers.count - 1)
			return resolve(style.layers[slot].resolved, appearance)
		case .hierarchical:
			let (fill, opacity) = resolve(style.layers[0].resolved, appearance)
			let factors: [CGFloat] = [1, 0.5, 0.25, 0.125]
			return (fill, opacity * factors[min(layer.hierarchyLevel, factors.count - 1)])
		case .monochrome, .automatic:
			return resolve(style.layers[0].resolved, appearance)
		}
	}

	/// Hex and alpha of a (possibly dynamic) color as it appears in `appearance`.
	private static func resolve(_ color: Color, _ appearance: NSAppearance) -> (String, CGFloat) {
		var resolved = NSColor(color)
		appearance.performAsCurrentDrawingAppearance {
			resolved = NSColor(cgColor: NSColor(color).cgColor) ?? resolved
		}
		guard let srgb = resolved.usingColorSpace(.sRGB) else { return ("#000000", 1) }
		return (String(format: "#%02X%02X%02X", Int(srgb.redComponent * 255), Int(srgb.greenComponent * 255), Int(srgb.blueComponent * 255)), srgb.alphaComponent)
	}

	private static func hex(_ color: CGColor) -> String? {
		guard let srgb = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return nil }
		return String(format: "#%02X%02X%02X", Int(srgb.redComponent * 255), Int(srgb.greenComponent * 255), Int(srgb.blueComponent * 255))
	}

	private static func n(_ value: CGFloat) -> String {
		var text = String(format: "%.3f", value)
		while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
			text.removeLast()
		}
		return text
	}
}
