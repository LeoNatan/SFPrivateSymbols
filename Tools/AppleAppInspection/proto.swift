import AppKit
import ObjectiveC
_ = NSApplication.shared
dlopen("/System/Library/Frameworks/SwiftUI.framework/SwiftUI", RTLD_NOW)
let p = objc_getProtocol("NSGlassAwareView")!
for (req, inst) in [(true,true),(false,true)] {
	var n: UInt32 = 0
	if let d = protocol_copyMethodDescriptionList(p, req, inst, &n) { for k in 0..<Int(n) { print(req ? "required" : "optional", NSStringFromSelector(d[k].name!)) } }
}
for c in ["NSPopUpButton","NSButton","NSControl","NSView","NSSegmentedControl","SwiftUI.ToolbarItemHostingView"] {
	if let cls = NSClassFromString(c) { print(c, class_conformsToProtocol(cls, p)) } else { print(c, "missing") }
}
