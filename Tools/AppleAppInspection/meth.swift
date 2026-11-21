import AppKit
import ObjectiveC
_ = NSApplication.shared; _ = NSToolbarItem.self; dlopen("/System/Library/Frameworks/SwiftUI.framework/SwiftUI", RTLD_NOW)
for cls in CommandLine.arguments.dropFirst() {
	guard let c: AnyClass = NSClassFromString(cls) else { print("no", cls); continue }
	var n: UInt32 = 0
	let m = class_copyMethodList(c, &n)!
	for k in 0..<Int(n) {
		let s = NSStringFromSelector(method_getName(m[k]))
		if CommandLine.arguments.count > 0, s.range(of: ProcessInfo.processInfo.environment["PAT"] ?? ".", options: [.regularExpression, .caseInsensitive]) != nil { print(cls, s) }
	}
}
