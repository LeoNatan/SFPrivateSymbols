//
//  ExportSheets.swift
//  SFPrivateSymbols
//
//  SF Symbols' export proof sheet (Export Template / Export Symbol) and Copy Image As sheet.
//

import SwiftUI
import UniformTypeIdentifiers

enum ExportKind: String, Identifiable {
	/// Editable template for designers (File > Export Template…).
	case template
	/// Template for Xcode asset catalogs (File > Export Symbol…).
	case symbol

	var id: Self { self }
}

/// The proof sheet shown before exporting: all 27 weight/scale variants, masters emphasized.
struct ExportProofSheet: View {
	@Environment(AppModel.self) private var model
	@Environment(\.dismiss) private var dismiss
	let kind: ExportKind
	let name: String

	@AppStorage("ExportTemplateSetup") private var setup: TemplateSetup = .variable
	@AppStorage("ExportTemplateVersion") private var templateVersion: Int = TemplateVersion.v7.rawValue
	@AppStorage("ExportSymbolVersion") private var symbolVersion: Int = TemplateVersion.v7.rawValue

	private var version: TemplateVersion {
		TemplateVersion(rawValue: kind == .template ? templateVersion : symbolVersion) ?? .v7
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 8) {
				ControlGroup {
					Button {} label: { Image(systemName: "chevron.left") }
					Button {} label: { Image(systemName: "chevron.right") }
				}
				.disabled(true)
				.fixedSize()
				Text(name)
					.font(.headline)
			}

			ProofGrid(name: name, kind: kind, highlighted: highlighted)
				.background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
				.overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))

			HStack(spacing: 8) {
				switch kind {
				case .template:
					Text("Template Setup:")
					Picker("Template Setup", selection: $setup) {
						ForEach(TemplateSetup.allCases) { Text($0.title).tag($0) }
					}
					.labelsHidden()
					.fixedSize()
					.disabled(version == .v2)

					Text("Compatibility:")
						.padding(.leading, 8)
					Picker("Compatibility", selection: $templateVersion) {
						ForEach(TemplateVersion.allCases.reversed()) { Text($0.sfSymbolsTitle).tag($0.rawValue) }
					}
					.labelsHidden()
					.fixedSize()
				case .symbol:
					Text("Export for:")
					Picker("Export for", selection: $symbolVersion) {
						ForEach(TemplateVersion.allCases.reversed()) { Text($0.xcodeTitle).tag($0.rawValue) }
					}
					.labelsHidden()
					.fixedSize()
					compatibilityNote
				}

				Spacer()

				Button("Cancel", role: .cancel) { dismiss() }
					.keyboardShortcut(.cancelAction)
				Button("Export") { export() }
					.keyboardShortcut(.defaultAction)
					.disabled(!isSupported)
			}
		}
		.padding(14)
		.frame(width: 1096, height: 469)
	}

	/// Export Symbol always writes the variable masters; template 2.0 always needs every variant.
	private var effectiveSetup: TemplateSetup {
		if version == .v2 { return .static }
		return kind == .symbol ? .variable : setup
	}

	/// Variants that go into the exported file.
	private var highlighted: Set<String> {
		Set(SymbolTemplate.variants(for: effectiveSetup).map { "\($0.0.rawValue)-\($0.1.rawValue)" })
	}

	private var minimumVersion: TemplateVersion {
		SymbolTemplate.minimumVersion(for: name)
	}

	private var isSupported: Bool {
		version.rawValue >= minimumVersion.rawValue || version == .v2
	}

	@ViewBuilder
	private var compatibilityNote: some View {
		if version.rawValue >= minimumVersion.rawValue {
			Label("This symbol is compatible with SF Symbols \(minimumVersion.rawValue) and greater.", systemImage: "checkmark.circle.fill")
				.foregroundStyle(.secondary)
				.padding(.leading, 8)
		} else {
			Label("This symbol uses layers, which require SF Symbols \(minimumVersion.rawValue) and greater; it will be exported as a single layer.", systemImage: "exclamationmark.triangle.fill")
				.foregroundStyle(.secondary)
				.padding(.leading, 8)
		}
	}

	private func export() {
		guard let svg = SymbolTemplate.svg(for: name, version: version, setup: effectiveSetup) else {
			NSSound.beep()
			return
		}
		let panel = NSSavePanel()
		panel.nameFieldStringValue = "\(name).svg"
		panel.allowedContentTypes = [.svg]
		panel.isExtensionHidden = false
		dismiss()
		guard panel.runModal() == .OK, let url = panel.url else { return }
		try? svg.write(to: url, atomically: true, encoding: .utf8)
	}
}

/// 9 weights × 3 scales. Templates are drawn as outlines, symbols filled; non-exported variants are dimmed.
private struct ProofGrid: View {
	@Environment(AppModel.self) private var model
	let name: String
	let kind: ExportKind
	let highlighted: Set<String>

	var body: some View {
		Grid(horizontalSpacing: 0, verticalSpacing: 0) {
			GridRow {
				Text("")
				ForEach(SymbolWeightOption.allCases) { weight in
					Text(weight.title)
						.font(.callout)
						.frame(maxWidth: .infinity)
				}
			}
			.frame(height: 36)

			ForEach(SymbolScaleOption.allCases) { scale in
				GridRow {
					Text(scale.title)
						.font(.callout)
						.frame(width: 72, alignment: .trailing)
						.padding(.trailing, 8)
					ForEach(SymbolWeightOption.allCases) { weight in
						cell(weight: weight, scale: scale)
							.frame(maxWidth: .infinity, maxHeight: .infinity)
					}
				}
				.frame(maxHeight: .infinity)
			}
		}
		.padding(.vertical, 6)
		.padding(.trailing, 10)
	}

	@ViewBuilder
	private func cell(weight: SymbolWeightOption, scale: SymbolScaleOption) -> some View {
		let isMaster = highlighted.contains("\(weight.rawValue)-\(scale.rawValue)")
		Group {
			if kind == .template, let outline = GlyphOutline.load(name, weight: weight, scale: scale, pointSize: 32) {
				OutlineShape(outline: Path(outline.path))
					.stroke(Color.primary, lineWidth: isMaster ? 1.2 : 0.8)
					.frame(width: outline.alignmentRect.width, height: outline.alignmentRect.height)
			} else {
				SymbolImage(name: name, style: proofStyle(weight: weight, scale: scale), pointSize: 32)
			}
		}
		.opacity(isMaster ? 1 : 0.3)
		.padding(6)
		.background {
			if isMaster {
				Circle().fill(Color.primary.opacity(0.08))
			}
		}
	}
}

private extension ProofGrid {
	func proofStyle(weight: SymbolWeightOption, scale: SymbolScaleOption) -> SymbolStyle {
		var style = SymbolStyle()
		style.weight = weight
		style.scale = scale
		style.rendering = .monochrome
		return style
	}
}

nonisolated private struct OutlineShape: Shape {
	let outline: Path

	func path(in rect: CGRect) -> Path {
		outline
	}
}

// MARK: - Copy Image As

/// Copy Image settings, stored under the same keys SF Symbols uses.
struct CopyImageSettings {
	enum Format: String, CaseIterable, Identifiable {
		case png, svg
		var id: Self { self }
		var title: String { rawValue.uppercased() }
	}

	@AppStorage("CopyImageFileFormat") var format: Format = .png
	@AppStorage("CopyImagePointSize") var pointSize: Double = 550
	@AppStorage("CopyImagePixelScale") var pixelScale: Double = 1
	@AppStorage("CopyImageSFScale") var scale: SymbolScaleOption = .medium
}

struct CopyImageAsSheet: View {
	@Environment(AppModel.self) private var model
	@Environment(\.dismiss) private var dismiss
	let name: String
	@State private var settings = CopyImageSettings()

	var body: some View {
		VStack(alignment: .trailing, spacing: 18) {
			Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
				GridRow {
					Text("Copy As:").gridColumnAlignment(.trailing)
					Picker("Copy As", selection: settings.$format) {
						ForEach(CopyImageSettings.Format.allCases) { Text($0.title).tag($0) }
					}
					.labelsHidden()
					.fixedSize()
				}
				GridRow {
					Text("Point Size:")
					TextField("Point Size", value: settings.$pointSize, format: .number)
						.labelsHidden()
				}
				GridRow {
					Text("Pixel Scale:")
					TextField("Pixel Scale", value: settings.$pixelScale, format: .number)
						.labelsHidden()
						.disabled(settings.format == .svg)
				}
				GridRow {
					Text("Symbol Scale:")
					Picker("Symbol Scale", selection: settings.$scale) {
						ForEach(SymbolScaleOption.allCases) { Text($0.title).tag($0) }
					}
					.labelsHidden()
					.fixedSize()
				}
			}

			HStack {
				Button("Cancel", role: .cancel) { dismiss() }
					.keyboardShortcut(.cancelAction)
				Button("Copy Image") {
					SymbolExport.copyImage(name, style: model.style)
					dismiss()
				}
				.keyboardShortcut(.defaultAction)
			}
		}
		.padding(20)
		.frame(width: 320)
	}
}
