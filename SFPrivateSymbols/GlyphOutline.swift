//
//  GlyphOutline.swift
//  SFPrivateSymbols
//
//  Vector outlines of private symbols, read from CoreGlyphsPrivate's asset catalog through CoreUI.
//

import AppKit
import ObjectiveC

/// One drawable layer of a symbol, with the template annotations CoreUI stores for it.
struct GlyphLayer {
	let path: CGPath
	let index: Int
	/// e.g. `primary`, `secondary`, `tertiary`
	let hierarchicalLevelName: String
	let hierarchyLevel: Int
	/// e.g. `custom`, `systemRedColor`
	let multicolorName: String
	let multicolorFill: CGColor?
	let opacity: CGFloat
}

/// Outline and metrics of a symbol at one weight and scale. Coordinates are in points, y-down,
/// origin at the top-left of the alignment rect.
struct GlyphOutline {
	let path: CGPath
	let layers: [GlyphLayer]
	/// Alignment rect within the content bounds (the margins are its insets).
	let alignmentRect: CGRect
	let contentBounds: CGRect
	/// How far the outline extends below the baseline.
	let baselineOffset: CGFloat
	/// True when some layers erase others; those can't be exported as independent annotated layers.
	let hasEraserLayers: Bool

	static func load(_ name: String, weight: SymbolWeightOption, scale: SymbolScaleOption, pointSize: CGFloat = 100) -> GlyphOutline? {
		GlyphCatalog.shared?.outline(name, weight: weight, scale: scale, pointSize: pointSize)
	}
}

private final class GlyphCatalog {
	static let shared = GlyphCatalog()

	private let catalog: NSObject
	private let lookup: Selector = NSSelectorFromString(
		"namedVectorGlyphWithName:scaleFactor:deviceIdiom:layoutDirection:glyphSize:glyphWeight:glyphPointSize:appearanceName:"
	)

	private typealias LookupFunction = @convention(c) (
		NSObject, Selector, NSString, CGFloat, Int, Int, Int, Int, CGFloat, NSString?
	) -> Unmanaged<NSObject>?
	private typealias PathFunction = @convention(c) (NSObject, Selector) -> Unmanaged<CGPath>?

	private init?() {
		let selector = NSSelectorFromString("defaultUICatalogForBundle:")
		guard dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_NOW) != nil,
			  let catalogClass = NSClassFromString("CUICatalog") as? NSObject.Type,
			  let bundle = Bundle(url: SymbolCatalog.privateBundleURL),
			  let catalog = catalogClass.perform(selector, with: bundle)?.takeUnretainedValue() as? NSObject else {
			return nil
		}
		self.catalog = catalog
	}

	func outline(_ name: String, weight: SymbolWeightOption, scale: SymbolScaleOption, pointSize: CGFloat) -> GlyphOutline? {
		guard let implementation = catalog.method(for: lookup) else { return nil }
		let function = unsafeBitCast(implementation, to: LookupFunction.self)
		guard let glyph = function(catalog, lookup, name as NSString, 1, 0, 0, scale.glyphSize, weight.glyphWeight, pointSize, nil)?
			.takeUnretainedValue(),
			  let path = Self.path(glyph, "CGPath") else {
			return nil
		}

		let alignment = (glyph.value(forKey: "alignmentRectUnrounded") as? NSValue)?.rectValue ?? path.boundingBoxOfPath
		let content = (glyph.value(forKey: "contentBoundsUnrounded") as? NSValue)?.rectValue ?? alignment
		let baseline = (glyph.value(forKey: "baselineOffsetUnrounded") as? NSNumber)?.doubleValue ?? 0

		let monochrome = glyph.value(forKey: "monochromeLayers") as? [NSObject] ?? []
		let hierarchical = glyph.value(forKey: "hierarchicalLayers") as? [NSObject] ?? []
		let multicolor = glyph.value(forKey: "multicolorLayers") as? [NSObject] ?? []

		var layers: [GlyphLayer] = []
		var hasEraser = false
		for (index, layer) in monochrome.enumerated() {
			if (layer.value(forKey: "isEraserLayer") as? Bool) == true {
				hasEraser = true
				continue
			}
			guard let shape = Self.path(layer, "shape") else { continue }
			let hierarchy = index < hierarchical.count ? hierarchical[index] : nil
			let color = index < multicolor.count ? multicolor[index] : nil
			layers.append(GlyphLayer(
				path: shape,
				index: index,
				hierarchicalLevelName: Self.annotation(hierarchy, fallback: "primary"),
				hierarchyLevel: (hierarchy?.value(forKey: "hierarchyLevel") as? Int) ?? 0,
				multicolorName: Self.annotation(color, fallback: "custom"),
				multicolorFill: color.flatMap { Self.cgColor($0.value(forKey: "fillColor")) },
				opacity: CGFloat((layer.value(forKey: "opacity") as? Double) ?? 1)
			))
		}

		return GlyphOutline(
			path: path,
			layers: layers,
			alignmentRect: alignment,
			contentBounds: content,
			baselineOffset: CGFloat(baseline),
			hasEraserLayers: hasEraser
		)
	}

	private static func path(_ object: NSObject, _ selectorName: String) -> CGPath? {
		let selector = NSSelectorFromString(selectorName)
		guard object.responds(to: selector), let implementation = object.method(for: selector) else { return nil }
		let function = unsafeBitCast(implementation, to: PathFunction.self)
		return function(object, selector)?.takeUnretainedValue().copy()
	}

	/// `hierarchical-1:secondary` → `secondary`
	private static func annotation(_ layer: NSObject?, fallback: String) -> String {
		guard let name = layer?.value(forKey: "name") as? String, let colon = name.firstIndex(of: ":") else { return fallback }
		return String(name[name.index(after: colon)...])
	}

	private static func cgColor(_ value: Any?) -> CGColor? {
		guard let value else { return nil }
		let object = value as AnyObject
		guard CFGetTypeID(object) == CGColor.typeID else { return nil }
		return (object as! CGColor)
	}
}

extension SymbolWeightOption {
	/// CoreUI glyph weight: 1 (ultralight) … 9 (black).
	var glyphWeight: Int {
		(Self.allCases.firstIndex(of: self) ?? 3) + 1
	}

	/// Template group name, e.g. `Ultralight`.
	var templateName: String { title }
}

extension SymbolScaleOption {
	/// CoreUI glyph size: 1 (small) … 3 (large).
	var glyphSize: Int {
		switch self {
		case .small: 1
		case .medium: 2
		case .large: 3
		}
	}

	var templateSuffix: String {
		switch self {
		case .small: "S"
		case .medium: "M"
		case .large: "L"
		}
	}
}

extension CGPath {
	/// SVG path data, mapping each point through `transform`.
	func svgPathData(_ transform: (CGPoint) -> CGPoint) -> String {
		var data = ""
		func f(_ value: CGFloat) -> String {
			var text = String(format: "%.4f", value)
			while text.contains(".") && (text.hasSuffix("0") || text.hasSuffix(".")) {
				text.removeLast()
			}
			return text == "-0" ? "0" : text
		}
		func p(_ point: CGPoint) -> String {
			let mapped = transform(point)
			return "\(f(mapped.x)) \(f(mapped.y))"
		}
		applyWithBlock { element in
			let points = element.pointee.points
			switch element.pointee.type {
			case .moveToPoint: data += "M\(p(points[0]))"
			case .addLineToPoint: data += "L\(p(points[0]))"
			case .addQuadCurveToPoint: data += "Q\(p(points[0])) \(p(points[1]))"
			case .addCurveToPoint: data += "C\(p(points[0])) \(p(points[1])) \(p(points[2]))"
			case .closeSubpath: data += "Z"
			@unknown default: break
			}
		}
		return data
	}
}
