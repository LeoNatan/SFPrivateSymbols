//
//  SymbolListView.swift
//  SFPrivateSymbols
//

import SwiftUI

struct SymbolListView: View {
	@Environment(AppModel.self) private var model
	let symbols: [PrivateSymbol]

	var body: some View {
		@Bindable var model = model

		Table(symbols, selection: $model.selectedSymbolName) {
			TableColumn("") { symbol in
				SymbolImage(name: symbol.name, style: model.style, pointSize: 17)
					.frame(maxWidth: .infinity)
			}
			.width(44)

			TableColumn("Name") { symbol in
				Text(symbol.name)
					.lineLimit(1)
					.truncationMode(.middle)
					.draggable(symbol.name)
			}
			.width(min: 180, ideal: 320)

			TableColumn("Categories") { symbol in
				Text(symbol.categories.map(SymbolCatalog.label(forCategory:)).joined(separator: ", "))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			.width(min: 120, ideal: 200)

			TableColumn("Availability") { symbol in
				Text(availability(symbol))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			.width(min: 80, ideal: 110)

			TableColumn("Search Terms") { symbol in
				Text(symbol.keywords.joined(separator: ", "))
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
		}
		.onCopyCommand { SymbolExport.copyProviders(model.selectedSymbolName, style: model.style) }
		.contextMenu(forSelectionType: String.self) { names in
			if let name = names.first, let symbol = model.symbol(named: name) {
				Button("Copy Symbol") { SymbolExport.copySymbol(symbol.name, style: model.style) }
				Button("Copy Name") { SymbolExport.copyName(Array(names)) }
				Button("Copy Image") { SymbolExport.copyImage(symbol.name, style: model.style) }
				Button("Copy Image As…") {
					model.selectedSymbolName = symbol.name
					model.showsCopyImageAs = true
				}
				Button("Copy SwiftUI Code") { SymbolExport.copyString(SymbolExport.swiftUICode(symbol.name)) }
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

	private func availability(_ symbol: PrivateSymbol) -> String {
		guard let macOS = model.catalog.platformReleases(for: symbol).first(where: { $0.platform == "macOS" }) else {
			return symbol.releaseYear ?? "—"
		}
		return "macOS \(macOS.version)"
	}
}
