//
//  SFPrivateSymbolsApp.swift
//  SFPrivateSymbols
//

import SwiftUI

@main
struct SFPrivateSymbolsApp: App {
	@State private var model = AppModel(catalog: SymbolCatalog())

	var body: some Scene {
		Window("SF Private Symbols", id: "main") {
			ContentView()
				.environment(model)
		}
		.defaultSize(width: 1400, height: 900)
		.commands {
			SymbolCommands(model: model)
		}
	}
}

struct SymbolCommands: Commands {
	let model: AppModel

	var body: some Commands {
		CommandGroup(after: .newItem) {
			Button("Export Template…") {
				model.exportRequest = .template
			}
			.keyboardShortcut("e", modifiers: .command)
			.disabled(model.selectedSymbolName == nil)

			Button("Export Symbol…") {
				model.exportRequest = .symbol
			}
			.keyboardShortcut("e", modifiers: [.command, .shift])
			.disabled(model.selectedSymbolName == nil)
		}

		// Edit > Copy (⌘C) copies the symbol as SVG through `onCopyCommand` on the symbol views.
		CommandGroup(after: .pasteboard) {
			Divider()
			Button("Copy Name") {
				if let name = model.selectedSymbolName {
					SymbolExport.copyName([name])
				}
			}
			.keyboardShortcut("c", modifiers: [.command, .shift])
			.disabled(model.selectedSymbolName == nil)

			Button("Copy Image") {
				if let name = model.selectedSymbolName {
					SymbolExport.copyImage(name, style: model.style)
				}
			}
			.keyboardShortcut("c", modifiers: [.command, .option])
			.disabled(model.selectedSymbolName == nil)

			Button("Copy Image As…") {
				model.showsCopyImageAs = true
			}
			.disabled(model.selectedSymbolName == nil)

			Button("Copy SwiftUI Code") {
				if let name = model.selectedSymbolName {
					SymbolExport.copyString(SymbolExport.swiftUICode(name))
				}
			}
			.disabled(model.selectedSymbolName == nil)
		}

		CommandGroup(before: .toolbar) {
			Picker("View", selection: Binding(get: { model.viewMode }, set: { model.viewMode = $0 })) {
				ForEach(ViewMode.allCases) { mode in
					Text("as \(mode.title)").tag(mode)
				}
			}
			.pickerStyle(.inline)
			.labelsHidden()

			Divider()

			Button("Zoom In") {
				model.tileSize = min(model.tileSize + 20, 200)
			}
			.keyboardShortcut("+", modifiers: .command)

			Button("Zoom Out") {
				model.tileSize = max(model.tileSize - 20, 60)
			}
			.keyboardShortcut("-", modifiers: .command)

			Button("Actual Size") {
				model.tileSize = 100
			}
			.keyboardShortcut("0", modifiers: .command)

			Divider()

			Button("Show Symbol Variants") {
				model.showSymbolVariants()
			}
			.keyboardShortcut("o", modifiers: .command)
			.disabled(model.selectionVariantsBase == nil)

			Button("Show All Symbols") {
				model.showAllSymbols()
			}
			.disabled(model.variantsBase == nil)

			Divider()

			Toggle("Show Obfuscated Names", isOn: Binding(get: { model.showsObfuscatedNames }, set: { model.showsObfuscatedNames = $0 }))

			Divider()
		}
	}
}
