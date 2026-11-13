import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, pixels) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels)/1024, y: CGFloat(pixels)/1024)
    let rect = CGRect(x: 50, y: 50, width: 924, height: 924)
    let background = NSBezierPath(roundedRect: rect, xRadius: 218, yRadius: 218)
    NSGradient(colors: [NSColor(srgbRed: 0.055, green: 0.075, blue: 0.10, alpha: 1), NSColor(srgbRed: 0.16, green: 0.20, blue: 0.23, alpha: 1)])!.draw(in: background, angle: 60)
    NSColor.white.withAlphaComponent(0.12).setStroke(); background.lineWidth = 3; background.stroke()
    func portal(_ points:[(CGFloat,CGFloat)],_ colors:[NSColor]) {
        let p=NSBezierPath();for (i,v) in points.enumerated(){let pt=CGPoint(x:180+v.0*664,y:180+(1-v.1)*664);if i==0{p.move(to:pt)}else{p.line(to:pt)}};p.close()
        NSGradient(colors:colors)!.draw(in:p,angle:-65)
    }
    portal([(0.48,0.06),(0.09,0.285),(0.09,0.715),(0.48,0.94),(0.48,0.745),(0.26,0.615),(0.26,0.385),(0.48,0.255)],[NSColor(srgbRed:0.28,green:0.83,blue:0.72,alpha:1),NSColor(srgbRed:0.63,green:1,blue:0.88,alpha:1)])
    portal([(0.52,0.06),(0.91,0.285),(0.91,0.715),(0.52,0.94),(0.52,0.745),(0.74,0.615),(0.74,0.385),(0.52,0.255)],[NSColor(srgbRed:0.47,green:0.39,blue:0.91,alpha:1),NSColor(srgbRed:0.73,green:0.63,blue:1,alpha:1)])
    portal([(0.50,0.35),(0.63,0.50),(0.50,0.65),(0.37,0.50)],[NSColor(srgbRed:0.81,green:1,blue:0.95,alpha:1),.white])
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name+".png"))
}
