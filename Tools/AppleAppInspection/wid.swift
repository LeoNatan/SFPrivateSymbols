import CoreGraphics
let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String:Any]]
for w in l where (w["kCGWindowOwnerName"] as? String)?.contains(CommandLine.arguments[1]) == true && (w["kCGWindowLayer"] as? Int) == 0 {
	let b = w["kCGWindowBounds"] as! [String: Double]
	if b["Height"]! > 300 { print(w["kCGWindowNumber"]!) }
}
