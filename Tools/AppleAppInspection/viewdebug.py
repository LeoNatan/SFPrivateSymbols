import lldb
SWIFT = r'''
import Foundation
import SwiftUI
import AppKit
let arr = unsafeBitCast(UInt(%d), to: [SwiftUI._ViewDebug.Data].self)
var lines: [String] = []
func strs(_ v: Any, _ depth: Int, _ out: inout [String], _ label: String) {
    if depth > 9 || out.count > 80 { return }
    let m = Mirror(reflecting: v)
    if let c = v as? Color { out.append("\(label)=Color(\(c))"); return }
    if v is NSColor { out.append("\(label)=\(v)"); return }
    if let s = v as? String { if !s.isEmpty && s.count < 100 { out.append(label.isEmpty ? s : "\(label)=\(s)") }; return }
    if v is Bool || v is Double || v is CGFloat || v is Int { if ["spacing","alignment","width","height","minWidth","maxWidth","minHeight","maxHeight","top","leading","bottom","trailing","edges","cornerRadius","lineWidth","opacity","isOn","value","lineLimit","weight","size","design"].contains(label) { out.append("\(label)=\(v)") }; return }
    if m.displayStyle == .enum && m.children.isEmpty { if ["style","kind","weight","design","alignment","edges","role","textStyle","horizontal","vertical"].contains(label) { out.append("\(label)=\(v)") }; return }
    for c in m.children { strs(c.value, depth + 1, &out, c.label ?? label) }
}
func walk(_ d: Any, _ level: Int) {
    let m = Mirror(reflecting: d)
    var data: [AnyHashable: Any] = [:]
    var kids: [Any] = []
    for c in m.children {
        if c.label == "data", let dd = c.value as? [AnyHashable: Any] { data = dd }
        if c.label == "childData", let cc = c.value as? [Any] { kids = cc }
    }
    var typeName = ""; var size = ""; var vals: [String] = []
    for (k, v) in data {
        let key = "\(k)"
        if key.hasSuffix("type") { typeName = "\(v)" }
        else if key.hasSuffix("size") { size = "\(v)" }
        else if key.hasSuffix("value") { strs(v, 0, &vals, "") }
    }
    let short = typeName.replacingOccurrences(of: "SwiftUI.", with: "")
    lines.append(String(repeating: "  ", count: level) + "\(short.prefix(140)) \(size) | \(vals.joined(separator: " · ").prefix(300))")
    for k in kids { walk(k, level + 1) }
}
for a in arr { walk(a, 0) }
let text = lines.joined(separator: "\n")
try? text.write(toFile: "%s", atomically: true, encoding: .utf8)
"\(lines.count)"
'''
def run(debugger, command, result, internal_dict):
    out, addr = command.split()
    target = debugger.GetSelectedTarget(); proc = target.GetProcess()
    bp = target.BreakpointCreateByRegex(r"static SwiftUI\._ViewDebug\.serializedData\(", "SwiftUICore")
    opts = lldb.SBExpressionOptions(); opts.SetIgnoreBreakpoints(False); opts.SetLanguage(lldb.eLanguageTypeObjC_plus_plus); opts.SetTimeoutInMicroSeconds(0); opts.SetUnwindOnError(False)
    proc.GetSelectedThread().GetFrameAtIndex(0).EvaluateExpression("(id)[(id)%s makeViewDebugData]" % addr, opts)
    th = None
    for t in proc:
        if t.GetStopReason() == lldb.eStopReasonBreakpoint: th = t
    if th is None: print("no stop"); return
    f = th.GetFrameAtIndex(0)
    x0 = f.FindRegister("x0").GetValueAsUnsigned()
    so = lldb.SBExpressionOptions(); so.SetLanguage(lldb.eLanguageTypeSwift); so.SetIgnoreBreakpoints(True); so.SetTimeoutInMicroSeconds(0)
    r = f.EvaluateExpression(SWIFT % (x0, out), so)
    print("written", r.GetSummary(), str(r.GetError())[:1500])
    target.BreakpointDelete(bp.GetID())
    th.UnwindInnermostExpression()
