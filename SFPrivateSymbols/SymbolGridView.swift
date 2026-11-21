//
//  SymbolGridView.swift
//  SFPrivateSymbols
//

import SwiftUI

struct SymbolGridView: View {
	@Environment(AppModel.self) private var model
	let symbols: [PrivateSymbol]

	@FocusState private var focused: Bool

	/// SF Symbols' flow layout: 20 pt side insets and a 20 pt minimum gap, with the leftover width spread between columns.
	private let inset: CGFloat = 20
	private let minimumSpacing: CGFloat = 20

	var body: some View {
		GeometryReader { geometry in
			let itemWidth = model.tileSize
			let available = geometry.size.width - 2 * inset
			let columnCount = max(1, Int((available + minimumSpacing) / (itemWidth + minimumSpacing)))
			let spacing = columnCount > 1 ? (available - CGFloat(columnCount) * itemWidth) / CGFloat(columnCount - 1) : 0
			let columns = Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing, alignment: .top), count: columnCount)

			ScrollViewReader { proxy in
				ScrollView {
					LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
						ForEach(symbols) { symbol in
							SymbolTile(symbol: symbol, isSelected: model.selectedSymbolName == symbol.name, itemWidth: itemWidth)
								.id(symbol.name)
								.onTapGesture {
									model.selectedSymbolName = symbol.name
									focused = true
								}
								.symbolContextMenu(for: symbol)
								.draggable(symbol.name)
						}
					}
					.padding(.horizontal, inset)
					.padding(.bottom, inset)
				}
				.focusable()
				.onCopyCommand { SymbolExport.copyProviders(model.selectedSymbolName, style: model.style) }
				.focused($focused)
				.focusEffectDisabled()
				.onMoveCommand { direction in
					move(direction, columns: columnCount, proxy: proxy)
				}
				.onKeyPress(.escape) {
					model.selectedSymbolName = nil
					return .handled
				}
				.onChange(of: model.selectedSymbolName) { _, name in
					if let name {
						withAnimation { proxy.scrollTo(name) }
					}
				}
				.background {
					// Grid background, as in SF Symbols. Click on empty space clears the selection.
					Color(nsColor: .textBackgroundColor)
						.ignoresSafeArea()
						.onTapGesture {
							model.selectedSymbolName = nil
							focused = true
						}
				}
			}
		}
	}

	private func move(_ direction: MoveCommandDirection, columns: Int, proxy: ScrollViewProxy) {
		guard !symbols.isEmpty else { return }
		guard let name = model.selectedSymbolName, let index = symbols.firstIndex(where: { $0.name == name }) else {
			model.selectedSymbolName = symbols.first?.name
			return
		}
		var next = index
		switch direction {
		case .left: next -= 1
		case .right: next += 1
		case .up: next -= columns
		case .down: next += columns
		@unknown default: break
		}
		next = min(max(next, 0), symbols.count - 1)
		model.selectedSymbolName = symbols[next].name
	}
}

struct SymbolTile: View {
	@Environment(AppModel.self) private var model
	let symbol: PrivateSymbol
	let isSelected: Bool
	/// Item width; the tile is `itemWidth × 0.8` and the item `itemWidth × 1.4`, as in SF Symbols (100 × 80 in 100 × 140).
	let itemWidth: CGFloat

	var body: some View {
		let scale = itemWidth / 100
		let shape = RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
		let stroke = isSelected ? Color.accentColor : Color(nsColor: .separatorColor)
		let lineWidth: CGFloat = isSelected ? 2 : 1

		VStack(spacing: 4 * scale) {
			ZStack {
				shape.fill(model.style.backgroundColor)
				SymbolImage(name: symbol.name, style: model.style, pointSize: 32 * scale)
					.symbolBackgroundAppearance(model.style)
			}
			.frame(width: itemWidth, height: 80 * scale)
			.overlay { shape.strokeBorder(stroke, lineWidth: lineWidth) }
			.background {
				// A card stacked behind marks symbols that have variants.
				if hasVariants {
					shape
						.fill(model.style.backgroundColor.opacity(0.6))
						.overlay { shape.strokeBorder(stroke, lineWidth: lineWidth) }
						.scaleEffect(x: 0.9, y: 1)
						.offset(y: -4 * scale)
				}
			}
			.overlay(alignment: .topTrailing) {
				if symbol.isNew {
					Circle()
						.fill(.blue)
						.frame(width: 6, height: 6)
						.padding(9 * scale)
						.help("New")
				}
			}
			.padding(.top, 8 * scale)

			Text(displayName)
				.font(.system(size: 13))
				.multilineTextAlignment(.center)
				.lineLimit(2)
				.truncationMode(.middle)
				.frame(width: itemWidth + 4)
		}
		.frame(width: itemWidth, height: 140 * scale, alignment: .top)
		.contentShape(Rectangle())
		.help(symbol.name)
	}

	private var hasVariants: Bool {
		!symbol.familyVariants.isEmpty
	}

	/// Break names at dots so they wrap like in SF Symbols.
	private var displayName: String {
		symbol.name.replacingOccurrences(of: ".", with: ".\u{200B}")
	}
}

extension View {
	func symbolContextMenu(for symbol: PrivateSymbol) -> some View {
		modifier(SymbolContextMenu(symbol: symbol))
	}
}

private struct SymbolContextMenu: ViewModifier {
	@Environment(AppModel.self) private var model
	let symbol: PrivateSymbol

	func body(content: Content) -> some View {
		content.contextMenu {
			Button("Copy Symbol") { SymbolExport.copySymbol(symbol.name, style: model.style) }
			Button("Copy Name") { SymbolExport.copyName([symbol.name]) }
			Button("Copy Image") { SymbolExport.copyImage(symbol.name, style: model.style) }
			Button("Copy Image As…") {
				model.selectedSymbolName = symbol.name
				model.showsCopyImageAs = true
			}
			Menu("Copy Code") {
				Button("SwiftUI") { SymbolExport.copyString(SymbolExport.swiftUICode(symbol.name)) }
				Button("AppKit") { SymbolExport.copyString(SymbolExport.appKitCode(symbol.name)) }
				Button("UIKit") { SymbolExport.copyString(SymbolExport.uiKitCode(symbol.name)) }
			}
			Divider()
			Button("Export Template…") {
				model.selectedSymbolName = symbol.name
				model.exportRequest = .template
			}
			Button("Export Symbol…") {
				model.selectedSymbolName = symbol.name
				model.exportRequest = .symbol
			}
		}
	}
}
