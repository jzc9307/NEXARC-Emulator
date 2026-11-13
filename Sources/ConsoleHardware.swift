import SwiftUI
import SceneKit
import Metal

// Original, code-built studio models. No network assets or brand logos.
@MainActor enum HardwareStudio {
    static var thumbnails: [GameSystem:NSImage]=[:]
    static func material(_ color: NSColor, metallic: CGFloat=0.05) -> SCNMaterial {
        let m=SCNMaterial();m.diffuse.contents=color;m.metalness.contents=metallic;m.roughness.contents=0.38;return m
    }
    static func color(_ hex: UInt32) -> NSColor { NSColor(srgbRed:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,alpha:1) }
    @discardableResult static func box(_ parent: SCNNode,_ w: CGFloat,_ h: CGFloat,_ d: CGFloat,_ x: Float,_ y: Float,_ z: Float,_ color: NSColor,_ radius: CGFloat=0.12) -> SCNNode {
        let g=SCNBox(width:w,height:h,length:d,chamferRadius:radius);g.materials=[material(color)];let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);parent.addChildNode(n);return n
    }
    @discardableResult static func disc(_ p: SCNNode,_ r: CGFloat,_ x: Float,_ y: Float,_ z: Float,_ color: NSColor) -> SCNNode {
        let g=SCNCylinder(radius:r,height:0.045);g.materials=[material(color)];let n=SCNNode(geometry:g);n.eulerAngles.x = .pi/2;n.position=SCNVector3(x,y,z);p.addChildNode(n);return n
    }
    static func label(_ p:SCNNode,_ text:String,_ x:Float,_ y:Float,_ z:Float,_ size:CGFloat=0.12,_ color:NSColor = .lightGray) {
        let g=SCNText(string:text,extrusionDepth:0.001);g.font=NSFont.systemFont(ofSize:size,weight:.medium);g.flatness=0.1;g.materials=[material(color)];let n=SCNNode(geometry:g);n.position=SCNVector3(x,y,z);p.addChildNode(n)
    }
    static func dpad(_ p:SCNNode,_ x:Float,_ y:Float,_ z:Float) { let c=color(0x232936);box(p,0.53,0.17,0.10,x,y,z,c,0.025);box(p,0.17,0.53,0.11,x,y,z+0.01,c,0.025);disc(p,0.065,x,y,z+0.07,color(0x3A414B)) }
    static func buttons(_ p:SCNNode,_ x:Float,_ y:Float,_ z:Float,_ accent:NSColor,four:Bool=true) {
        if four {for (dx,dy,c) in [(-0.23,0.0,NSColor.systemGreen),(0.23,0.0,NSColor.systemRed),(0.0,0.23,NSColor.systemBlue),(0.0,-0.23,NSColor.systemYellow)] {disc(p,0.11,x+Float(dx),y+Float(dy),z,c)}}
        else {disc(p,0.16,x-0.16,y-0.06,z,accent);disc(p,0.16,x+0.24,y+0.15,z,accent)}
    }
    static func screen(_ p:SCNNode,_ w:CGFloat,_ h:CGFloat,_ x:Float,_ y:Float,_ z:Float,_ system:GameSystem) {
        box(p,w+0.20,h+0.20,0.04,x,y,z,color(0x1A202B),0.06)
        let panel=box(p,w,h,0.02,x,y,z+0.03,system == .gb ? color(0x78984B):color(0x111F2C),0.025)
        panel.geometry?.firstMaterial?.lightingModel = .constant
        panel.geometry?.firstMaterial?.emission.contents=NSColor.black
        let ink=system == .gb ? color(0xD4E8A1):color(system.color)
        for row in 0..<4 {for col in 0..<7 where (row+col)%3 == 0 {box(p,0.08,0.08,0.01,x+Float(col-3)*0.20,y+Float(row-2)*0.16,z+0.055,ink,0)}}
        label(p,"NEXARC",x-Float(w)*0.22,y-0.05,z+0.06,w*0.12,ink)
    }
    static func make(_ s:GameSystem)->SCNNode {
        let p=SCNNode(),gray=color(0xBFC2C9),dark=color(0x252A33),accent=color(s.color)
        switch s {
        case .gb,.gbc:
            let shell=s == .gb ? color(0xCBC9BD):color(0x78529B)
            box(p,2.35,3.85,0.48,0,0,0,shell,0.22);box(p,1.99,1.70,0.04,0,0.72,0.26,color(0x525361),0.12)
            screen(p,1.43,1.22,0,0.73,0.30,s);dpad(p,-0.63,-0.64,0.30);buttons(p,0.55,-0.62,0.30,color(0x9F3658),four:false)
            for x:Float in [-0.21,0.20] {let b=box(p,0.35,0.10,0.06,x,-1.15,0.29,color(0x74787C),0.04);b.eulerAngles.z=0.20}
            for i in 0..<5 {let b=box(p,0.055,0.43,0.02,0.55+Float(i)*0.11,-1.45,0.26,color(0x82878A),0.015);b.eulerAngles.z=0.35}
            label(p,"POCKET / 89",-0.93,-0.27,0.29,0.11,color(0x414568))
        case .gba,.gameGear,.psp:
            let shell=s == .gba ? color(0x6653B1):dark
            box(p,4.8,2.25,0.45,0,0,0,shell,0.38);screen(p,s == .psp ? 2.75:2.45,1.65,0,0.06,0.25,s)
            dpad(p,-1.84,0.12,0.30);buttons(p,1.82,0.14,0.30,s == .gba ? gray:accent,four:s == .psp)
            box(p,0.38,0.08,0.04,-0.25,-0.98,0.25,gray,0.03);box(p,0.38,0.08,0.04,0.25,-0.98,0.25,gray,0.03)
            if s == .psp {disc(p,0.18,-1.84,-0.65,0.30,color(0x555963))}
        case .nds,.n3ds:
            let shell=s == .n3ds ? color(0x347DAB):gray
            box(p,3.50,2.12,0.23,0,1.12,-0.06,shell,0.14);screen(p,s == .n3ds ? 2.80:2.15,1.50,0,1.14,0.08,s)
            box(p,3.50,2.13,0.35,0,-1.10,0.12,shell,0.16);screen(p,1.85,1.45,0,-1.06,0.32,s)
            box(p,3.18,0.16,0.24,0,0,0.10,dark,0.07);dpad(p,-1.34,-1.32,0.35);buttons(p,1.32,-0.83,0.35,dark)
            if s == .n3ds {disc(p,0.21,-1.34,-0.62,0.35,gray)}
            disc(p,0.035,1.49,1.22,0.10,dark);disc(p,0.035,-1.49,1.22,0.10,dark)
            box(p,0.04,0.13,0.02,1.52,-1.98,0.31,accent,0.005)
        case .gamecube:
            box(p,3.0,2.4,2.6,0,0,0,color(0x57499A),0.12)
            let lid=disc(p,1.03,0,1.23,0,color(0x31303D));lid.eulerAngles.x=0
            label(p,"OPTICAL / 01",-0.70,1.25,0.20,0.14,.white)
            for x:Float in [-0.97,-0.33,0.33,0.97] {disc(p,0.15,x,-0.25,1.32,dark);disc(p,0.075,x,-0.25,1.36,gray)}
            for x:Float in [-0.61,0.61] {box(p,0.94,0.12,0.04,x,-0.79,1.33,dark,0.02)}
            let handle=SCNTorus(ringRadius:0.76,pipeRadius:0.09);handle.materials=[material(dark)];let n=SCNNode(geometry:handle);n.position=SCNVector3(0,0.4,-1.42);n.eulerAngles.x = .pi/2;p.addChildNode(n)
        case .wii,.ps2:
            box(p,s == .wii ? 1.10:1.20,3.9,2.7,0,0,0,s == .wii ? color(0xE3E7E7):dark,0.08)
            box(p,0.055,2.75,0.03,0.15,0.20,1.37,s == .wii ? color(0x63CBEA):color(0x0C121B),0.01)
            box(p,2.0,0.12,3.1,0,-2.02,0,gray,0.04)
            disc(p,0.05,-0.27,1.52,1.38,accent)
            if s == .ps2 {for i in 0..<12 {box(p,1.24,0.05,2.73,0,-1.76+Float(i)*0.30,0,color(0x141B26),0.01)}}
        case .ps1,.saturn,.dreamcast:
            box(p,3.8,0.92,3.0,0,-0.15,0,s == .saturn ? dark:color(0xCED2D4),0.18)
            let lid=disc(p,1.19,0,0.34,-0.10,s == .saturn ? color(0x343945):color(0xB5BAC0));lid.eulerAngles.x=0
            for x:Float in [-1.38,1.38] {let b=disc(p,0.22,x,0.36,0.65,accent);b.eulerAngles.x=0}
            for x:Float in [-0.90,0.90] {box(p,1.22,0.18,0.07,x,-0.15,1.55,dark,0.05)}
            for i in 0..<8 {box(p,0.025,0.34,0.02,-1.65+Float(i)*0.10,-0.07,1.52,color(0x676F7B),0)}
        default:
            let shell: NSColor = s == .nes ? color(0xC9C5BD):s == .snes ? color(0xABA8B9):s == .pcEngine ? color(0xE6E2D8):dark
            box(p,4.0,0.95,2.8,0,0,0,shell,0.15)
            if s == .nes {box(p,2.8,0.44,0.035,-0.30,0.11,1.43,color(0x626975),0.035);box(p,0.70,1.0,2.85,1.35,0.01,0,dark,0.02)}
            else if s == .atari2600 {box(p,4.02,0.37,0.025,0,-0.11,1.43,color(0x956444),0.02);for i in 0..<16 {box(p,0.08,0.03,2.15,-1.65+Float(i)*0.22,0.50,-0.10,color(0x10141B),0.01)}}
            else {let lid=disc(p,0.95,0,0.51,-0.1,dark);lid.eulerAngles.x=0;box(p,1.85,0.09,0.22,0,0.57,-0.45,color(0x090E15),0.015)}
            for x:Float in [-1.15,1.15] {box(p,0.85,0.18,0.05,x,-0.17,1.44,dark,0.04)}
            disc(p,0.055,-1.62,0.14,1.45,accent);label(p,s.shortName.uppercased(),-0.80,0.03,1.45,0.13,s == .nes ? dark:accent)
        }
        return p
    }
    static func scene(_ system:GameSystem)->(SCNScene,SCNNode) {
        let scene=SCNScene();scene.background.contents=NSColor.clear
        let model=make(system);model.eulerAngles=SCNVector3(0.28,-0.36,-0.035);scene.rootNode.addChildNode(model)
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.usesOrthographicProjection=true;camera.camera?.orthographicScale=3.05;camera.camera?.zNear=0.1;camera.camera?.zFar=40;camera.position=SCNVector3(0,0,12);scene.rootNode.addChildNode(camera)
        for (pos,intensity,c) in [(SCNVector3(-4,6,7),CGFloat(1100),NSColor.white),(SCNVector3(5,0,4),CGFloat(650),color(system.color)),(SCNVector3(0,4,-4),CGFloat(850),NSColor.white)] {
            let l=SCNNode();l.light=SCNLight();l.light?.type = .omni;l.light?.intensity=intensity;l.light?.color=c;l.position=pos;scene.rootNode.addChildNode(l)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=220;scene.rootNode.addChildNode(ambient)
        return (scene,model)
    }
    static func thumbnail(_ s:GameSystem)->NSImage {
        if let image=thumbnails[s] {return image}
        let (scene,_)=scene(s),renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=scene
        let image=renderer.snapshot(atTime:0,with:CGSize(width:640,height:420),antialiasingMode:.multisampling4X);thumbnails[s]=image;return image
    }
}

struct HardwareViewport: NSViewRepresentable {
    let system:GameSystem
    func makeNSView(context:Context)->HardwareOrbitView { let v=HardwareOrbitView();v.configure(system);return v }
    func updateNSView(_ v:HardwareOrbitView,context:Context) {if v.system != system {v.configure(system)}}
}
final class HardwareOrbitView:SCNView {
    var system:GameSystem?;var model:SCNNode?
    func configure(_ system:GameSystem) {self.system=system;let (scene,model)=HardwareStudio.scene(system);self.scene=scene;self.model=model;backgroundColor = .clear;antialiasingMode = .multisampling4X;rendersContinuously=false;preferredFramesPerSecond=30;allowsCameraControl=false;setAccessibilityLabel("Interactive \(system.name) studio model")}
    override func mouseDragged(with event:NSEvent) {model?.eulerAngles.y += CGFloat(event.deltaX)*0.01;model?.eulerAngles.x = min(1.25,max(-1.25,(model?.eulerAngles.x ?? 0)+CGFloat(event.deltaY)*0.01));needsDisplay=true}
    override func scrollWheel(with event:NSEvent) {if let camera=pointOfView?.camera {camera.orthographicScale=min(5,max(1.6,camera.orthographicScale+Double(event.scrollingDeltaY)*0.015));needsDisplay=true}}
}
