import AppKit
import SceneKit

/// Original studio mesh, built from a contoured shell rather than a box.
/// The Nintendo layout has offset sticks and the actual A/B/X/Y positions.
@MainActor enum ProControllerModel {
    static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: Double((rgb >> 16) & 255)/255,
                green: Double((rgb >> 8) & 255)/255, blue: Double(rgb & 255)/255, alpha: 1)
    }
    static func finish(_ rgb: UInt32, roughness: CGFloat = 0.64) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color(rgb)
        material.roughness.contents = roughness
        material.metalness.contents = 0.05
        return material
    }
    static func shellPath(inset: CGFloat = 0) -> NSBezierPath {
        let path = NSBezierPath()
        path.flatness = 0.004
        path.move(to: NSPoint(x: -1.10, y: 0.89))
        path.curve(to: NSPoint(x: 1.10, y: 0.89), controlPoint1: NSPoint(x: -0.45, y: 1.03), controlPoint2: NSPoint(x: 0.45, y: 1.03))
        path.curve(to: NSPoint(x: 1.67, y: 0.37), controlPoint1: NSPoint(x: 1.45, y: 0.92), controlPoint2: NSPoint(x: 1.61, y: 0.70))
        path.curve(to: NSPoint(x: 1.78, y: -0.97), controlPoint1: NSPoint(x: 1.77, y: -0.07), controlPoint2: NSPoint(x: 1.88, y: -0.65))
        path.curve(to: NSPoint(x: 1.18, y: -1.18), controlPoint1: NSPoint(x: 1.72, y: -1.33), controlPoint2: NSPoint(x: 1.38, y: -1.40))
        path.curve(to: NSPoint(x: 0.75, y: -0.61), controlPoint1: NSPoint(x: 1.02, y: -0.99), controlPoint2: NSPoint(x: 0.92, y: -0.68))
        path.curve(to: NSPoint(x: -0.75, y: -0.61), controlPoint1: NSPoint(x: 0.35, y: -0.39), controlPoint2: NSPoint(x: -0.35, y: -0.39))
        path.curve(to: NSPoint(x: -1.18, y: -1.18), controlPoint1: NSPoint(x: -0.92, y: -0.68), controlPoint2: NSPoint(x: -1.02, y: -0.99))
        path.curve(to: NSPoint(x: -1.78, y: -0.97), controlPoint1: NSPoint(x: -1.38, y: -1.40), controlPoint2: NSPoint(x: -1.72, y: -1.33))
        path.curve(to: NSPoint(x: -1.67, y: 0.37), controlPoint1: NSPoint(x: -1.88, y: -0.65), controlPoint2: NSPoint(x: -1.77, y: -0.07))
        path.curve(to: NSPoint(x: -1.10, y: 0.89), controlPoint1: NSPoint(x: -1.61, y: 0.70), controlPoint2: NSPoint(x: -1.45, y: 0.92))
        path.close()
        return path
    }
    @discardableResult static func disc(_ parent: SCNNode, radius: CGFloat, depth: CGFloat,
                                       x: CGFloat, y: CGFloat, z: CGFloat, color: UInt32,
                                       name: String? = nil) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: depth)
        geometry.radialSegmentCount = 48
        geometry.materials = [finish(color)]
        let node = SCNNode(geometry: geometry)
        node.eulerAngles.x = .pi / 2
        node.position = SCNVector3(x, y, z)
        node.name = name
        parent.addChildNode(node)
        return node
    }
    @discardableResult static func block(_ parent: SCNNode, width: CGFloat, height: CGFloat,
                                         depth: CGFloat, x: CGFloat, y: CGFloat, z: CGFloat,
                                         color: UInt32, bevel: CGFloat = 0.025,
                                         name: String? = nil) -> SCNNode {
        let geometry = SCNBox(width: width, height: height, length: depth, chamferRadius: bevel)
        geometry.materials = [finish(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        node.name = name
        parent.addChildNode(node)
        return node
    }
    static func text(_ parent: SCNNode, _ value: String, x: CGFloat, y: CGFloat,
                     z: CGFloat, size: CGFloat = 0.14, rgb: UInt32 = 0xE7EBEC) {
        let geometry = SCNText(string: value, extrusionDepth: 0.001)
        geometry.font = NSFont.systemFont(ofSize: size, weight: .semibold)
        geometry.flatness = 0.05
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color(rgb)
        material.emission.contents = color(rgb)
        material.emission.intensity = 2.8
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        let bounds = node.boundingBox
        node.position = SCNVector3(x - (bounds.min.x + bounds.max.x)/2,
                                  y - (bounds.min.y + bounds.max.y)/2, z)
        parent.addChildNode(node)
    }
    static func stick(_ parent: SCNNode, x: CGFloat, y: CGFloat, name: String) {
        disc(parent, radius: 0.31, depth: 0.035, x: x, y: y, z: 0.23, color: 0x141A20)
        disc(parent, radius: 0.275, depth: 0.025, x: x, y: y, z: 0.26, color: 0x59616A)
        let movement = SCNNode()
        movement.position = SCNVector3(x, y, 0.28)
        movement.name = "motion.\(name)"
        parent.addChildNode(movement)
        disc(movement, radius: 0.13, depth: 0.13, x: 0, y: 0, z: 0.055, color: 0x20262C)
        disc(movement, radius: 0.235, depth: 0.065, x: 0, y: 0, z: 0.15,
             color: 0x343A40, name: "control.\(name)")
        disc(movement, radius: 0.185, depth: 0.008, x: 0, y: 0, z: 0.187, color: 0x242B30)
        let ring = SCNTorus(ringRadius: 0.213, pipeRadius: 0.012)
        ring.ringSegmentCount = 64
        ring.pipeSegmentCount = 8
        ring.materials = [finish(0x626A73)]
        let node = SCNNode(geometry: ring)
        node.eulerAngles.x = .pi/2
        node.position.z = 0.19
        movement.addChildNode(node)
        for i in 0..<24 {
            let angle = CGFloat(i) * .pi/12
            disc(movement, radius: 0.009, depth: 0.003,
                 x: cos(angle)*0.166, y: sin(angle)*0.166, z: 0.193, color: 0x4C545C)
        }
    }
    static func dpad(_ parent: SCNNode, x: CGFloat, y: CGFloat) {
        disc(parent, radius: 0.33, depth: 0.025, x: x, y: y, z: 0.23, color: 0x222930)
        block(parent, width: 0.58, height: 0.18, depth: 0.075, x: x, y: y,
              z: 0.29, color: 0x11171C)
        block(parent, width: 0.18, height: 0.58, depth: 0.078, x: x, y: y,
              z: 0.293, color: 0x11171C)
        disc(parent, radius: 0.08, depth: 0.01, x: x, y: y, z: 0.337, color: 0x202930)
        for (name,dx,dy) in [("DpadUp",CGFloat(0),CGFloat(0.21)),("DpadDown",0,-0.21),("DpadLeft",-0.21,0),("DpadRight",0.21,0)] {
            block(parent,width:0.075,height:0.075,depth:0.004,x:x+dx,y:y+dy,z:0.337,color:0x424D56,bevel:0.01,name:"control.\(name)")
        }
    }
    static func make(_ family: ControllerFamily) -> SCNNode {
        let root = SCNNode()
        let shell = SCNShape(path: shellPath(), extrusionDepth: 0.36)
        shell.chamferRadius = 0.105
        shell.materials = [finish(0x2B323B, roughness: 0.58)]
        let body = SCNNode(geometry: shell)
        body.position.z = -0.18
        root.addChildNode(body)
        // A raised front shell creates a visible seam around the body.
        let face = SCNShape(path: shellPath(), extrusionDepth: 0.03)
        face.chamferRadius = 0.04
        face.materials = [finish(0x333C46)]
        let plate = SCNNode(geometry: face)
        plate.scale = SCNVector3(0.972, 0.972, 1)
        plate.position.z = 0.18
        root.addChildNode(plate)
        // Textured grip panels follow each handle, rather than adding separate boxes.
        for side: CGFloat in [-1,1] {
            let grip = NSBezierPath()
            grip.flatness = 0.004
            grip.move(to: NSPoint(x:side*1.34,y:0.18))
            grip.curve(to:NSPoint(x:side*1.68,y:-0.96),controlPoint1:NSPoint(x:side*1.55,y:-0.12),controlPoint2:NSPoint(x:side*1.76,y:-0.66))
            grip.curve(to:NSPoint(x:side*1.25,y:-1.12),controlPoint1:NSPoint(x:side*1.62,y:-1.20),controlPoint2:NSPoint(x:side*1.39,y:-1.30))
            grip.curve(to:NSPoint(x:side*1.04,y:-0.53),controlPoint1:NSPoint(x:side*1.11,y:-0.96),controlPoint2:NSPoint(x:side*1.10,y:-0.67))
            grip.curve(to:NSPoint(x:side*1.34,y:0.18),controlPoint1:NSPoint(x:side*0.96,y:-0.20),controlPoint2:NSPoint(x:side*1.24,y:0.07))
            grip.close()
            let geometry = SCNShape(path:grip,extrusionDepth:0.012)
            geometry.materials = [finish(0x4A535D,roughness:0.9)]
            let panel = SCNNode(geometry:geometry)
            panel.position.z = 0.222
            root.addChildNode(panel)
            for row in 0..<9 { for col in 0..<4 {
                let y = CGFloat(-0.42)-CGFloat(row)*0.065
                let x = side*(1.30+CGFloat(col)*0.06+CGFloat(row)*0.011)
                disc(root,radius:0.009,depth:0.003,x:x,y:y,z:0.238,color:0x303A44)
            }}
            block(root,width:0.64,height:0.18,depth:0.20,x:side*1.05,y:0.88,z:0.08,color:0x1C242C,bevel:0.07,name:side<0 ? "control.LeftShoulder":"control.RightShoulder")
            block(root,width:0.60,height:0.21,depth:0.18,x:side*1.05,y:1.03,z:-0.12,color:0x252E38,bevel:0.07,name:side<0 ? "control.LeftTrigger":"control.RightTrigger")
            text(root,side<0 ? "L":"R",x:side*1.05,y:0.90,z:0.191,size:0.11)
            text(root,side<0 ? "ZL":"ZR",x:side*1.05,y:1.04,z:-0.015,size:0.10,rgb:0xAAB7C2)
        }
        let offset = family != .generic && family != .playstation
        stick(root,x:-0.94,y:offset ? 0.38:-0.32,name:"LeftStick")
        stick(root,x:0.57,y:-0.35,name:"RightStick")
        dpad(root,x:offset ? -0.65:-1.02,y:offset ? -0.41:0.40)
        let letters = family == .nintendo ? ["East":"A","South":"B","West":"Y","North":"X"] : ["East":"B","South":"A","West":"X","North":"Y"]
        for (name,dx,dy) in [("East",CGFloat(0.27),CGFloat(0)),("South",0,-0.27),("West",-0.27,0),("North",0,0.27)] {
            let x=CGFloat(1.00)+dx,y=CGFloat(0.38)+dy
            disc(root,radius:0.135,depth:0.055,x:x,y:y,z:0.255,color:0x151D25,name:"control.\(name)")
            text(root,letters[name]!,x:x,y:y,z:0.287,size:0.15)
        }
        for (x,name,label) in [(CGFloat(-0.29),"Minus","−"),(CGFloat(0.29),"Plus","+")] {
            disc(root,radius:0.085,depth:0.03,x:x,y:0.43,z:0.244,color:0x1B242C,name:"control.\(name)")
            text(root,label,x:x,y:0.43,z:0.265,size:0.16)
        }
        block(root,width:0.14,height:0.14,depth:0.035,x:-0.24,y:-0.05,z:0.245,color:0x17212A,name:"control.Capture")
        text(root,"○",x:-0.24,y:-0.05,z:0.269,size:0.12)
        disc(root,radius:0.09,depth:0.035,x:0.24,y:-0.05,z:0.245,color:0x606E7A,name:"control.Home")
        text(root,"⌂",x:0.24,y:-0.05,z:0.268,size:0.13)
        text(root,"NEXARC",x:0,y:0.73,z:0.235,size:0.105,rgb:0x9EAEBB)
        for i in 0..<4 {block(root,width:0.037,height:0.022,depth:0.01,x:CGFloat(i)*0.085-0.1275,y:-0.43,z:0.22,color:0x536D62,bevel:0.005)}
        root.eulerAngles.y = -0.10
        return root
    }
}
