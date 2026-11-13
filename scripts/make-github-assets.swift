import AppKit

let root=URL(fileURLWithPath:CommandLine.arguments[1]).standardizedFileURL
let assets=root.appendingPathComponent("docs/assets")
try FileManager.default.createDirectory(at:assets,withIntermediateDirectories:true)
guard let icon=NSImage(contentsOf:root.appendingPathComponent("Resources/NEXARC.icns")) else{fatalError("NEXARC icon missing")}
func render(_ name:String,_ width:Int,_ height:Int,_ draw:()->Void)throws {
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);draw();NSGraphicsContext.restoreGraphicsState()
 try bitmap.representation(using:.png,properties:[:])!.write(to:assets.appendingPathComponent(name))
}
try render("nexarc-avatar.png",512,512){icon.draw(in:NSRect(x:0,y:0,width:512,height:512))}
try render("social-preview.png",1280,640){
 let rect=NSRect(x:0,y:0,width:1280,height:640)
 NSGradient(starting:NSColor(srgbRed:0.045,green:0.075,blue:0.10,alpha:1),ending:NSColor(srgbRed:0.10,green:0.085,blue:0.17,alpha:1))!.draw(in:rect,angle:-30)
 NSColor(srgbRed:0.64,green:0.92,blue:0.84,alpha:0.12).setStroke()
 for size in [360.0,500.0,650.0]{let circle=NSBezierPath(ovalIn:NSRect(x:1030-size/2,y:320-size/2,width:size,height:size));circle.lineWidth=1;circle.stroke()}
 icon.draw(in:NSRect(x:875,y:160,width:330,height:330))
 func text(_ string:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight){string.draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color])}
 let mint=NSColor(srgbRed:0.64,green:0.92,blue:0.84,alpha:1)
 text("YOUR COLLECTION. YOUR WAY TO PLAY.",72,516,17,mint,.semibold)
 text("NEXARC",66,350,108,.white,.bold)
 text("Every era, one library.",72,285,37,NSColor(srgbRed:0.78,green:0.77,blue:0.89,alpha:1),.medium)
 text("Native macOS multi-console emulation",72,221,25,NSColor(srgbRed:0.60,green:0.66,blue:0.72,alpha:1),.regular)
 text("Handheld skins  ·  Visual saves  ·  Local library",72,172,20,NSColor(srgbRed:0.60,green:0.66,blue:0.72,alpha:1),.regular)
 text("APPLE SILICON   /   macOS 14+   /   EXPERIMENTAL",72,64,16,mint,.medium)
}
print("Rendered NEXARC avatar and social preview.")
