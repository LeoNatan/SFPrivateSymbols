import AppKit
let a = CommandLine.arguments
let rep = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[1])))!
let (x0,y0,x1,y1) = (Int(a[2])!,Int(a[3])!,Int(a[4])!,Int(a[5])!)
var minX=Int.max,minY=Int.max,maxX=0,maxY=0
for y in y0..<y1 { for x in x0..<x1 { let c = rep.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!; if c.redComponent > 0.7 { minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y) } } }
print("bright bounds px", minX,minY,maxX,maxY, "size pt", Double(maxX-minX+1)/2, Double(maxY-minY+1)/2, "center pt", Double(minX+maxX)/4, Double(minY+maxY)/4)
for n in a[6...] { let img = NSImage(systemSymbolName: n, accessibilityDescription: nil)!.withSymbolConfiguration(.init(pointSize: 32, weight: .regular))!; print(n, img.size, img.alignmentRect) }
