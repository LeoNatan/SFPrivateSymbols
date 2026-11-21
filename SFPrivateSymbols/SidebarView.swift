//
//  SidebarView.swift
//  SFPrivateSymbols
//

import SwiftUI

struct SidebarView: View {
	@Environment(AppModel.self) private var model

	var body: some View {
		@Bindable var model = model

		List(selection: $model.sidebarSelection) {
			Section("SF Private Symbols") {
				ForEach(model.catalog.categories) { category in
					Label(category.label, systemImage: category.icon)
						.tag(SidebarItem.category(category.key))
				}
			}
		}
		.listStyle(.sidebar)
	}
}
