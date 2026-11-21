//
//  ContentView.swift
//  SFPrivateSymbols
//

import SwiftUI

struct ContentView: View {
	@Environment(AppModel.self) private var model

	var body: some View {
		@Bindable var model = model

		NavigationSplitView {
			SidebarView()
				.navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
		} detail: {
			DetailView()
				.navigationTitle(model.title)
				.navigationSubtitle(subtitle)
		}
		.searchable(text: $model.searchText, placement: .toolbar, prompt: "Search")
		#if DEBUG
		.task {
			// e.g. `-DebugExport template`, `-DebugCopyImageAs YES`, `-DebugCopy symbol|image`
			let defaults = UserDefaults.standard
			try? await Task.sleep(for: .milliseconds(500))
			if let kind = defaults.string(forKey: "DebugExport").flatMap(ExportKind.init(rawValue:)) {
				model.exportRequest = kind
			}
			if defaults.bool(forKey: "DebugCopyImageAs") {
				model.showsCopyImageAs = true
			}
			if let name = model.selectedSymbolName {
				switch defaults.string(forKey: "DebugCopy") {
				case "symbol": SymbolExport.copySymbol(name, style: model.style)
				case "image": SymbolExport.copyImage(name, style: model.style)
				default: break
				}
			}
		}
		#endif
		.sheet(item: $model.exportRequest) { kind in
			if let name = model.selectedSymbolName {
				ExportProofSheet(kind: kind, name: name)
			}
		}
		.sheet(isPresented: $model.showsCopyImageAs) {
			if let name = model.selectedSymbolName {
				CopyImageAsSheet(name: name)
			}
		}
		.inspector(isPresented: $model.showsInspector) {
			InspectorView()
				.inspectorColumnWidth(min: 280, ideal: 400, max: 480)
		}
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				ToolbarPopUp(options: SymbolWeightOption.allCases, title: \.title, selection: $model.style.weight)
					.help("Symbol Weight")
			}

			ToolbarItem(placement: .primaryAction) {
				ToolbarPopUp(options: SymbolScaleOption.allCases, title: \.title, selection: $model.style.scale)
					.help("Symbol Scale")
			}

			ToolbarItem(placement: .primaryAction) {
				Picker("View", selection: $model.viewMode) {
					ForEach(ViewMode.allCases) { mode in
						Label(mode.title, systemImage: mode.icon).tag(mode)
					}
				}
				.pickerStyle(.segmented)
				.controlSize(.extraLarge)
				.help("View Mode")
			}

			ToolbarItem(placement: .primaryAction) {
				Button {
					model.showsInspector.toggle()
				} label: {
					Label("Inspector", systemImage: "sidebar.trailing")
				}
				.controlSize(.extraLarge)
				.help("Show or Hide the Inspector")
			}
		}
	}

	private var subtitle: String {
		let count = model.visibleSymbols.count
		return "\(count.formatted()) \(count == 1 ? "Symbol" : "Symbols")"
	}
}

struct DetailView: View {
	@Environment(AppModel.self) private var model

	var body: some View {
		let symbols = model.visibleSymbols

		Group {
			if symbols.isEmpty {
				emptyView
			} else {
				switch model.viewMode {
				case .grid:
					SymbolGridView(symbols: symbols)
				case .list:
					SymbolListView(symbols: symbols)
				case .gallery:
					SymbolGalleryView(symbols: symbols)
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.onChange(of: model.searchText) {
			if let name = model.selectedSymbolName, !symbols.contains(where: { $0.name == name }) {
				model.selectedSymbolName = nil
			}
		}
	}

	@ViewBuilder
	private var emptyView: some View {
		if !model.searchText.isEmpty {
			ContentUnavailableView.search(text: model.searchText)
		} else {
			ContentUnavailableView("No Symbols", systemImage: "square.dashed")
		}
	}
}
