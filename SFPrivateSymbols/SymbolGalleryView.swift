//
//  SymbolGalleryView.swift
//  SFPrivateSymbols
//

import SwiftUI

/// Large preview of the selected symbol across weights, with a scrolling strip of all symbols below.
struct SymbolGalleryView: View {
	@Environment(AppModel.self) private var model
	let symbols: [PrivateSymbol]

	@FocusState private var focused: Bool

	var body: some View {
		let current = model.selectedSymbol ?? symbols.first

		VStack(spacing: 0) {
			if let current {
				VStack(spacing: 24) {
					Spacer(minLength: 0)
					SymbolImage(name: current.name, style: model.style, pointSize: 160)
						.frame(maxWidth: .infinity, minHeight: 220)
					Text(current.name)
						.font(.title2.weight(.semibold))
						.textSelection(.enabled)
					weightStrip(current)
					Spacer(minLength: 0)
				}
				.padding()
			}

			Divider()

			ScrollViewReader { proxy in
				ScrollView(.horizontal) {
					LazyHStack(spacing: 8) {
						ForEach(symbols) { symbol in
							let selected = symbol.name == current?.name
							SymbolImage(name: symbol.name, style: model.style, pointSize: 22)
								.symbolBackgroundAppearance(model.style)
								.frame(width: 56, height: 56)
								.background(
									RoundedRectangle(cornerRadius: 10, style: .continuous)
										.fill(model.style.backgroundColor)
								)
								.overlay(
									RoundedRectangle(cornerRadius: 10, style: .continuous)
										.strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: selected ? 3 : 1)
								)
								.id(symbol.name)
								.onTapGesture {
									model.selectedSymbolName = symbol.name
									focused = true
								}
								.symbolContextMenu(for: symbol)
								.help(symbol.name)
						}
					}
					.padding(12)
				}
				.frame(height: 80)
				.focusable()
				.onCopyCommand { SymbolExport.copyProviders(model.selectedSymbolName, style: model.style) }
				.focused($focused)
				.focusEffectDisabled()
				.onMoveCommand { direction in
					guard let index = symbols.firstIndex(where: { $0.name == current?.name }) else { return }
					switch direction {
					case .left: model.selectedSymbolName = symbols[max(index - 1, 0)].name
					case .right: model.selectedSymbolName = symbols[min(index + 1, symbols.count - 1)].name
					default: break
					}
				}
				.onChange(of: model.selectedSymbolName) { _, name in
					if let name { withAnimation { proxy.scrollTo(name, anchor: .center) } }
				}
				.onAppear {
					if model.selectedSymbolName == nil { model.selectedSymbolName = symbols.first?.name }
					// The lazy stack has no layout yet on appear; scroll on the next run loop pass.
					let name = model.selectedSymbolName
					Task { @MainActor in
						if let name { proxy.scrollTo(name, anchor: .center) }
					}
				}
			}
		}
	}

	private func weightStrip(_ symbol: PrivateSymbol) -> some View {
		HStack(spacing: 18) {
			ForEach(SymbolWeightOption.allCases) { weight in
				VStack(spacing: 6) {
					SymbolImage(name: symbol.name, style: model.style.with(weight: weight), pointSize: 28)
						.frame(height: 40)
					Text(weight.title)
						.font(.caption)
						.foregroundStyle(weight == model.style.weight ? Color.accentColor : Color.secondary)
				}
				.onTapGesture { model.style.weight = weight }
			}
		}
	}
}
