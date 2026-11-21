//
//  ToolbarPopUp.swift
//  SFPrivateSymbols
//
//  An AppKit toolbar pop-up button, as SF Symbols uses for its family and weight menus.
//

import SwiftUI

/// A pop-up button with the toolbar bezel at extra-large size, sized to the selected item.
struct ToolbarPopUp<Value: Hashable>: NSViewRepresentable {
	let options: [Value]
	let title: (Value) -> String
	@Binding var selection: Value

	func makeNSView(context: Context) -> NSPopUpButton {
		let button = Button(frame: .zero, pullsDown: false)
		button.bezelStyle = .toolbar
		button.controlSize = .extraLarge
		button.font = .systemFont(ofSize: NSFont.systemFontSize)
		button.addItems(withTitles: options.map(title))
		button.target = context.coordinator
		button.action = #selector(Coordinator.changed(_:))

		button.setContentHuggingPriority(.required, for: .horizontal)
		return button
	}

	func updateNSView(_ button: NSPopUpButton, context: Context) {
		context.coordinator.parent = self
		if let index = options.firstIndex(of: selection), button.indexOfSelectedItem != index {
			button.selectItem(at: index)
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	/// SwiftUI's toolbar host reports "shared glass" for hosted AppKit views, so adjacent pop-ups end up in one capsule.
	/// AppKit's own `NSPopUpButton` asks for a capsule of its own (`preferredGlassBehavior` 1), as SF Symbols' pop-ups do,
	/// so the host of this item is flagged to answer the same.
	final class Button: NSPopUpButton {
		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			guard let host = sequence(first: self as NSView, next: \.superview).first(where: {
				NSStringFromClass(type(of: $0)).contains("ToolbarItemHostingView")
			}) else { return }
			OwnGlassPlatter.request(for: host)
		}
	}

	final class Coordinator: NSObject {
		var parent: ToolbarPopUp

		init(parent: ToolbarPopUp) {
			self.parent = parent
		}

		@objc func changed(_ sender: NSPopUpButton) {
			let index = sender.indexOfSelectedItem
			guard parent.options.indices.contains(index) else { return }
			parent.selection = parent.options[index]
		}
	}
}

/// Makes flagged SwiftUI toolbar item hosts report `preferredGlassBehavior` 1 (a glass capsule of their own).
private enum OwnGlassPlatter {
	nonisolated(unsafe) private static var key: UInt8 = 0
	private static var patchedClasses: Set<ObjectIdentifier> = []
	private static let selector = NSSelectorFromString("preferredGlassBehavior")

	static func request(for host: NSView) {
		patch(baseClass(of: host))
		guard objc_getAssociatedObject(host, &key) == nil else { return }
		host.willChangeValue(forKey: "preferredGlassBehavior")
		objc_setAssociatedObject(host, &key, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		host.didChangeValue(forKey: "preferredGlassBehavior")
	}

	/// The class below any KVO subclass.
	private static func baseClass(of view: NSView) -> AnyClass {
		var cls: AnyClass = object_getClass(view)!
		while NSStringFromClass(cls).hasPrefix("NSKVONotifying_"), let superclass = class_getSuperclass(cls) {
			cls = superclass
		}
		return cls
	}

	private static func patch(_ cls: AnyClass) {
		guard !patchedClasses.contains(ObjectIdentifier(cls)),
			  let method = class_getInstanceMethod(cls, selector) else { return }
		patchedClasses.insert(ObjectIdentifier(cls))

		typealias Getter = @convention(c) (AnyObject, Selector) -> Int
		let original = unsafeBitCast(method_getImplementation(method), to: Getter.self)
		let sel = selector
		let block: @convention(block) (AnyObject) -> Int = { object in
			objc_getAssociatedObject(object, &key) != nil ? 1 : original(object, sel)
		}
		let implementation = imp_implementationWithBlock(block)
		// Add an override when the method is inherited, so only this class changes.
		if !class_addMethod(cls, selector, implementation, method_getTypeEncoding(method)) {
			method_setImplementation(method, implementation)
		}
	}
}
