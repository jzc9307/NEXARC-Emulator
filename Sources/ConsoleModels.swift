import AppKit
import SceneKit
import simd

// Curated third-party hardware meshes, packaged for fully offline viewing.
// Attribution, license copies and modifications live beside the bundled GLBs.
enum ConsoleModels {
    static func make(_ console: Console) -> SCNNode {
        let root: SCNNode
        if let url = assetURL(console), let imported = try? ConsoleAsset(url: url).load(console: console) {
            root = imported
        } else {
        switch console {
        case .switchOriginal: root = handheld(secondGeneration: false)
        case .switch2: root = handheld(secondGeneration: true)
        case .ps5: root = playStation5()
        case .ps4: root = playStation4()
        case .xbox: root = xboxSeriesX()
        }
        }
        root.name = console.rawValue
        let bounds = root.boundingBox
        let extent = bounds.max - bounds.min
        let scale = 3.0 / max(extent.x, max(extent.y, extent.z))
        let centered = SCNNode()
        root.position = -(bounds.min + bounds.max) * (0.5 * scale)
        root.scale = SCNVector3(scale, scale, scale)
        centered.addChildNode(root)
        centered.name = "hardware"
        return centered
    }

    static func assetURL(_ console: Console) -> URL? {
        if let url = Bundle.main.url(forResource: console.rawValue, withExtension: "glb", subdirectory: "ConsoleModels") { return url }
        // SwiftPM tests and local source builds use the exact same curated assets.
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/ConsoleModels/" + console.rawValue + ".glb")
        return FileManager.default.fileExists(atPath: source.path) ? source : nil
    }

    static func credit(_ console: Console) -> (name: String, url: URL) {
        switch console {
        case .ps5: return ("Spellmansp · CC BY 4.0", URL(string: "https://sketchfab.com/3d-models/5833f3516db442eaa2ef33702c110ae8")!)
        case .ps4: return ("IMPACTRA · CC BY 4.0", URL(string: "https://sketchfab.com/3d-models/35f5868ea45749b7a6ec865c617742a2")!)
        case .xbox: return ("sc8di · CC BY 4.0", URL(string: "https://sketchfab.com/3d-models/cc6603469f9c4c36a93a52f5afaaad01")!)
        case .switchOriginal: return ("HarrisonHag1 · CC BY 4.0", URL(string: "https://sketchfab.com/3d-models/c73fadccfdc547f9958fd8a1cdbe4811")!)
        case .switch2: return ("tiansongyu · MIT", URL(string: "https://github.com/tiansongyu/open-console-cad/tree/main/devices/switch2")!)
        }
    }

    private static func material(_ rgb: UInt32, roughness: CGFloat = 0.48, metalness: CGFloat = 0) -> SCNMaterial {
        let material = SCNMaterial()
        // Plastic uses a restrained specular lobe; glass and exposed metal
        // retain the environment response of the physical material model.
        material.lightingModel = metalness > 0.5 || roughness < 0.20 ? .physicallyBased : .blinn
        material.diffuse.contents = NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
            green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        material.specular.contents = NSColor(white: 0.10, alpha: 1)
        material.shininess = max(0.08, 1 - roughness)
        material.isDoubleSided = false
        return material
    }

    private static let graphite = material(0x25272A, roughness: 0.62)
    private static let black = material(0x090B0E, roughness: 0.55)
    private static let rubber = material(0x17191B, roughness: 0.86)
    private static let white = material(0xE5E7EA, roughness: 0.45)
    private static let silver = material(0x999EA4, roughness: 0.35, metalness: 0.8)
    private static let ink = material(0xA1A6AD, roughness: 0.7)
    private static let glass = material(0x090F15, roughness: 0.14, metalness: 0.10)

    @discardableResult
    private static func box(_ parent: SCNNode, _ name: String, _ size: SIMD3<Float>, _ at: SIMD3<Float>, _ material: SCNMaterial, radius: CGFloat = 0.015) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z),
            chamferRadius: min(radius, CGFloat(min(size.x, min(size.y, size.z))) * 0.45))
        geometry.chamferSegmentCount = 4
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.simdPosition = at
        parent.addChildNode(node)
        return node
    }

    @discardableResult
    private static func cylinder(_ parent: SCNNode, _ name: String, radius: CGFloat, depth: CGFloat, at: SIMD3<Float>, _ material: SCNMaterial, faceForward: Bool = true) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: depth)
        geometry.radialSegmentCount = 32
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.name = name
        node.simdPosition = at
        if faceForward { node.eulerAngles.x = .pi / 2 }
        parent.addChildNode(node)
        return node
    }

    private static func ring(_ parent: SCNNode, radius: CGFloat, tube: CGFloat, at: SIMD3<Float>, _ material: SCNMaterial) {
        let geometry = SCNTorus(ringRadius: radius, pipeRadius: tube)
        geometry.ringSegmentCount = 40
        geometry.pipeSegmentCount = 8
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.simdPosition = at
        node.eulerAngles.x = .pi / 2
        parent.addChildNode(node)
    }

    private static func text(_ value: String, parent: SCNNode, at: SIMD3<Float>, width: Float, color: SCNMaterial = ink) {
        // A dimensioned decal keeps typography out of mesh bounds/tessellation.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .medium),
            .foregroundColor: color.diffuse.contents as? NSColor ?? NSColor.lightGray
        ]
        let size = (value as NSString).size(withAttributes: attributes)
        let pw = max(8, Int(ceil(size.width)) + 8)
        let ph = max(8, Int(ceil(size.height)) + 8)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: pw, height: ph))
        (value as NSString).draw(at: NSPoint(x: 4, y: 4), withAttributes: attributes)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: pw, height: ph))
        image.addRepresentation(bitmap)
        let decal = SCNMaterial()
        decal.lightingModel = .constant
        decal.diffuse.contents = image
        decal.blendMode = .alpha
        decal.writesToDepthBuffer = false
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(width) * CGFloat(ph) / CGFloat(pw))
        plane.materials = [decal]
        let node = SCNNode(geometry: plane)
        node.name = "printed \(value)"
        node.simdPosition = at
        parent.addChildNode(node)
    }

    private static func screw(_ parent: SCNNode, at: SIMD3<Float>, back: Bool = false) {
        cylinder(parent, "recessed screw", radius: 0.012, depth: 0.004, at: at, black)
        let mark = box(parent, "screw slot", SIMD3(0.013, 0.002, 0.001), at + SIMD3(0, 0, back ? -0.003 : 0.003), silver, radius: 0)
        mark.eulerAngles.z = .pi / 4
    }

    private static func thumbstick(_ root: SCNNode, at: SIMD3<Float>, accent: SCNMaterial? = nil) {
        cylinder(root, "joystick socket", radius: 0.082, depth: 0.007, at: at, black)
        if let accent { ring(root, radius: 0.075, tube: 0.005, at: at + SIMD3(0, 0, 0.006), accent) }
        cylinder(root, "joystick stem", radius: 0.035, depth: 0.062, at: at + SIMD3(0, 0, 0.030), graphite)
        cylinder(root, "rubber joystick cap", radius: 0.071, depth: 0.027, at: at + SIMD3(0, 0, 0.067), rubber)
        ring(root, radius: 0.060, tube: 0.004, at: at + SIMD3(0, 0, 0.082), graphite)
        // A shallow concave-looking pad with a molded outer lip.
        cylinder(root, "thumb pad", radius: 0.053, depth: 0.002, at: at + SIMD3(0, 0, 0.081), rubber)
        for i in 0..<28 {
            let angle = Float(i) * 2 * .pi / 28
            let p = at + SIMD3(cos(angle) * 0.068, sin(angle) * 0.068, 0.073)
            let ridge = box(root, "grip knurl", SIMD3(0.003, 0.006, 0.011), p, rubber, radius: 0.001)
            ridge.eulerAngles.z = CGFloat(angle)
        }
    }

    private static func actionButton(_ root: SCNNode, label: String, at: SIMD3<Float>, radius: CGFloat = 0.031) {
        cylinder(root, "button recess", radius: radius + 0.004, depth: 0.005, at: at, black)
        cylinder(root, "\(label) button", radius: radius, depth: 0.015, at: at + SIMD3(0, 0, 0.010), graphite)
        if !label.isEmpty { text(label, parent: root, at: at + SIMD3(0, -0.001, 0.019), width: Float(radius) * 0.85) }
    }

    private static func handheld(secondGeneration: Bool) -> SCNNode {
        let root = SCNNode()
        let w: Float = secondGeneration ? 2.72 : 2.39
        let h: Float = secondGeneration ? 1.16 : 1.02
        let centerWidth: Float = secondGeneration ? 1.95 : 1.70
        let joyWidth = (w - centerWidth) / 2
        let joyCenter = centerWidth / 2 + joyWidth / 2
        let shell = material(secondGeneration ? 0x303337 : 0x282B2F, roughness: 0.64)
        let leftColor = material(secondGeneration ? 0x303438 : 0x00B6D3, roughness: 0.48)
        let rightColor = material(secondGeneration ? 0x303438 : 0xF14F56, roughness: 0.48)
        let blue = material(0x62B9ED, roughness: 0.40)
        let orange = material(0xF1764B, roughness: 0.40)

        box(root, "console chassis", SIMD3(centerWidth, h, 0.139), .zero, shell, radius: 0.04)
        box(root, "front bezel", SIMD3(centerWidth - 0.025, h - 0.025, 0.018), SIMD3(0, 0, 0.072), black, radius: 0.035)
        let screenWidth: Float = secondGeneration ? 1.736 : 1.370
        let screenHeight = screenWidth * 9 / 16
        box(root, "reflective screen glass", SIMD3(screenWidth, screenHeight, 0.009), SIMD3(0, 0, 0.084), glass, radius: secondGeneration ? 0.023 : 0.006)

        for left in [true, false] {
            let sign: Float = left ? -1 : 1
            let x = joyCenter * sign
            let color = left ? leftColor : rightColor
            // Extruded rounded endcap, flat where it meets the tablet.
            let outline = NSBezierPath()
            outline.flatness = 0.001
            let inner: CGFloat = left ? CGFloat(joyWidth / 2) : -CGFloat(joyWidth / 2)
            let outer: CGFloat = -inner
            let top = CGFloat(h / 2)
            let bottom = -top
            let corner: CGFloat = secondGeneration ? 0.17 : 0.15
            outline.move(to: NSPoint(x: inner, y: bottom + 0.015))
            outline.line(to: NSPoint(x: inner, y: top - 0.015))
            outline.line(to: NSPoint(x: outer + CGFloat(left ? 1 : -1) * corner, y: top))
            outline.curve(to: NSPoint(x: outer, y: top - corner), controlPoint1: NSPoint(x: outer, y: top), controlPoint2: NSPoint(x: outer, y: top - corner * 0.45))
            outline.line(to: NSPoint(x: outer, y: bottom + corner))
            outline.curve(to: NSPoint(x: outer + CGFloat(left ? 1 : -1) * corner, y: bottom), controlPoint1: NSPoint(x: outer, y: bottom + corner * 0.45), controlPoint2: NSPoint(x: outer, y: bottom))
            outline.close()
            let geometry = SCNShape(path: outline, extrusionDepth: 0.144)
            geometry.chamferRadius = 0.016
            geometry.materials = [color]
            let controller = SCNNode(geometry: geometry)
            controller.name = left ? "left Joy-Con" : "right Joy-Con"
            controller.simdPosition = SIMD3(x, 0, -0.072)
            root.addChildNode(controller)
            box(root, "controller join", SIMD3(0.012, h - 0.05, 0.15), SIMD3(sign * (centerWidth / 2 + 0.004), 0, -0.002), black, radius: 0.002)
            if secondGeneration {
                box(root, "magnetic rail color", SIMD3(0.010, h - 0.12, 0.145), SIMD3(sign * (centerWidth / 2 + 0.014), 0, -0.005), left ? blue : orange, radius: 0.003)
            }
            box(root, left ? "L shoulder" : "R shoulder", SIMD3(joyWidth - 0.035, 0.055, 0.095), SIMD3(x, h / 2 - 0.018, -0.005), graphite, radius: 0.02)
            box(root, left ? "ZL trigger" : "ZR trigger", SIMD3(joyWidth - 0.06, 0.13, 0.10), SIMD3(x, h / 2 - 0.07, -0.096), black, radius: 0.035)
            for yy: Float in [-h * 0.35, h * 0.32] { screw(root, at: SIMD3(x + sign * joyWidth * 0.22, yy, -0.077), back: true) }
        }
        let controlTop: Float = h * 0.24
        let controlBottom: Float = -h * 0.11
        thumbstick(root, at: SIMD3(-joyCenter, controlTop, 0.080), accent: secondGeneration ? blue : nil)
        thumbstick(root, at: SIMD3(joyCenter, controlBottom, 0.080), accent: secondGeneration ? orange : nil)
        for (dx, dy, label): (Float, Float, String) in [(0, 0.080, "X"), (0.080, 0, "A"), (0, -0.080, "B"), (-0.080, 0, "Y")] {
            actionButton(root, label: label, at: SIMD3(joyCenter + dx, controlTop + dy, 0.080))
        }
        for (dx, dy, label): (Float, Float, String) in [(0, 0.078, "▴"), (0.078, 0, "▸"), (0, -0.078, "▾"), (-0.078, 0, "◂")] {
            actionButton(root, label: label, at: SIMD3(-joyCenter + dx, controlBottom + dy, 0.080))
        }
        box(root, "minus", SIMD3(0.057, 0.013, 0.012), SIMD3(-centerWidth / 2 - 0.055, h * 0.385, 0.086), graphite, radius: 0.003)
        let plusAt = SIMD3<Float>(centerWidth / 2 + 0.055, h * 0.385, 0.086)
        box(root, "plus horizontal", SIMD3(0.055, 0.014, 0.012), plusAt, graphite, radius: 0.003)
        box(root, "plus vertical", SIMD3(0.014, 0.055, 0.012), plusAt, graphite, radius: 0.003)
        box(root, "capture button", SIMD3(0.052, 0.052, 0.010), SIMD3(-joyCenter + 0.025, -h * 0.34, 0.084), graphite, radius: 0.007)
        cylinder(root, "capture button center", radius: 0.013, depth: 0.002, at: SIMD3(-joyCenter + 0.025, -h * 0.34, 0.091), black)
        actionButton(root, label: "⌂", at: SIMD3(joyCenter - 0.025, -h * 0.34, 0.080), radius: 0.036)
        if secondGeneration { actionButton(root, label: "C", at: SIMD3(joyCenter - 0.025, -h * 0.44, 0.080), radius: 0.029) }
        for sign: Float in [-1, 1] {
            for i in 0..<5 {
                box(root, "front speaker grille", SIMD3(0.012, 0.022, 0.002), SIMD3(sign * (screenWidth / 2 - 0.04) + Float(i) * 0.018, -h * 0.435, 0.083), rubber, radius: 0.005)
            }
        }
        // Side and top details remain visible when the model is turned over.
        for i in 0..<15 {
            box(root, "top exhaust vent", SIMD3(0.020, 0.006, 0.065), SIMD3(-0.24 + Float(i) * 0.033, h / 2 + 0.002, -0.006), black, radius: 0.002)
        }
        box(root, "power button", SIMD3(0.055, 0.013, 0.037), SIMD3(-centerWidth * 0.41, h / 2 + 0.008, -0.002), graphite, radius: 0.006)
        box(root, "volume rocker", SIMD3(0.13, 0.012, 0.032), SIMD3(-centerWidth * 0.31, h / 2 + 0.008, -0.002), graphite, radius: 0.005)
        box(root, "cartridge cover", SIMD3(0.21, 0.009, 0.10), SIMD3(centerWidth * 0.35, h / 2 + 0.003, -0.015), shell, radius: 0.012)
        box(root, "bottom USB-C surround", SIMD3(0.085, 0.005, 0.036), SIMD3(0, -h / 2 - 0.002, 0), silver, radius: 0.009)
        box(root, "bottom USB-C port", SIMD3(0.067, 0.007, 0.022), SIMD3(0, -h / 2 - 0.006, 0), black, radius: 0.006)
        if secondGeneration {
            for sign: Float in [-1, 1] {
                box(root, "U stand side", SIMD3(0.035, h * 0.66, 0.018), SIMD3(sign * centerWidth * 0.42, -h * 0.12, -0.080), graphite, radius: 0.007)
            }
            box(root, "U stand crossbar", SIMD3(centerWidth * 0.86, 0.035, 0.018), SIMD3(0, -h * 0.44, -0.080), graphite, radius: 0.008)
        } else {
            box(root, "rear kickstand", SIMD3(0.31, 0.69, 0.015), SIMD3(0.54, -0.115, -0.078), graphite, radius: 0.009)
        }
        let label = SCNNode()
        label.eulerAngles.y = .pi
        label.simdPosition = SIMD3(0, -0.06, -0.081)
        root.addChildNode(label)
        text(secondGeneration ? "NINTENDO SWITCH 2" : "NINTENDO SWITCH", parent: label, at: .zero, width: secondGeneration ? 0.63 : 0.56)
        for sign: Float in [-1, 1] {
            for i in 0..<6 {
                box(root, "rear intake", SIMD3(0.02, 0.13, 0.004), SIMD3(sign * centerWidth * 0.38 + Float(i) * 0.024, h * 0.27, -0.072), black, radius: 0.003)
            }
        }
        return root
    }

    private static func playStation5() -> SCNNode {
        let root = SCNNode()
        let glossy = material(0x101318, roughness: 0.22, metalness: 0.12)
        box(root, "complete black core", SIMD3(0.72, 3.50, 2.12), SIMD3(0, -0.02, -0.02), graphite, radius: 0.13)
        box(root, "gloss front spine", SIMD3(0.66, 3.42, 0.025), SIMD3(0, -0.04, 1.057), glossy, radius: 0.011)
        for sign: Float in [-1, 1] {
            let panel = ps5Panel(side: sign)
            panel.name = sign < 0 ? "curved left faceplate" : "curved right drive faceplate"
            root.addChildNode(panel)
            let blue = material(0x3579DE, roughness: 0.4)
            blue.emission.contents = NSColor(srgbRed: 0.03, green: 0.15, blue: 0.62, alpha: 1)
            for i in 0..<44 {
                let t = Float(i) / 43
                let y = -1.68 + t * 3.41
                let x = sign * (0.371 + 0.066 * t * t)
                box(root, "blue inner light channel", SIMD3(0.009, 0.081, 0.006), SIMD3(x, y, 1.079), blue, radius: 0.002)
                if i > 25 {
                    box(root, "inner cooling fins", SIMD3(0.035, 0.025, 0.20), SIMD3(sign * 0.345, y, 0.99), black, radius: 0.002)
                }
            }
        }
        cylinder(root, "circular stand", radius: 0.88, depth: 0.075, at: SIMD3(0, -1.93, 0), black, faceForward: false)
        // Original disc model: the right faceplate swells around the drive.
        box(root, "vertical disc slot", SIMD3(0.019, 1.28, 0.010), SIMD3(0.524, -0.72, 1.193), black, radius: 0.008)
        box(root, "USB-A bezel", SIMD3(0.128, 0.054, 0.014), SIMD3(-0.10, 0.13, 1.077), silver, radius: 0.006)
        box(root, "USB-A opening", SIMD3(0.105, 0.034, 0.018), SIMD3(-0.10, 0.13, 1.085), black, radius: 0.002)
        box(root, "USB-C opening", SIMD3(0.074, 0.030, 0.017), SIMD3(-0.10, 0.32, 1.080), black, radius: 0.012)
        box(root, "power key", SIMD3(0.022, 0.12, 0.009), SIMD3(-0.15, -1.53, 1.079), silver, radius: 0.005)
        box(root, "eject key", SIMD3(0.018, 0.08, 0.009), SIMD3(0.16, -1.53, 1.079), silver, radius: 0.004)
        let rear = SCNNode()
        rear.eulerAngles.y = .pi
        rear.simdPosition = SIMD3(0, 0, -1.088)
        root.addChildNode(rear)
        for row in 0..<20 {
            for col in 0..<5 {
                box(rear, "rear ventilation", SIMD3(0.056, 0.045, 0.010), SIMD3(-0.25 + Float(col) * 0.12, -1.15 + Float(row) * 0.13, 0), black, radius: 0.012)
            }
        }
        port(rear, at: SIMD3(-0.11, -1.43, 0.016), size: SIMD3(0.20, 0.09, 0.025))
        port(rear, at: SIMD3(0.15, -1.43, 0.016), size: SIMD3(0.12, 0.11, 0.025))
        text("PS5", parent: rear, at: SIMD3(0, 1.56, 0.01), width: 0.22)
        return root
    }

    private static func ps5Panel(side: Float) -> SCNNode {
        let rows = 36
        let cols = 18
        var vertices: [SIMD3<Float>] = []
        var triangles: [UInt32] = []
        for face in 0..<2 {
            for row in 0...rows {
                let t = Float(row) / Float(rows)
                for col in 0...cols {
                    let u = Float(col) / Float(cols)
                    let z = -1.13 + u * 2.31
                    let y = -1.84 + t * (3.63 + 0.19 * u)
                    let waist = 0.025 * sin(t * .pi)
                    let flare = 0.085 * pow(t, 4)
                    let drive: Float = side > 0 ? 0.135 * pow(1 - t, 1.45) * (0.5 + 0.5 * u) : 0
                    let x = side * (0.39 + waist + flare + drive + Float(face) * 0.065 + 0.014 * cos(u * .pi))
                    vertices.append(SIMD3(x, y, z))
                }
            }
        }
        let stride = cols + 1
        let faceCount = (rows + 1) * stride
        func quad(_ a: Int, _ b: Int, _ c: Int, _ d: Int, reversed: Bool = false) {
            let values = reversed ? [a, c, b, a, d, c] : [a, b, c, a, c, d]
            triangles.append(contentsOf: values.map(UInt32.init))
        }
        for face in 0..<2 {
            for row in 0..<rows {
                for col in 0..<cols {
                    let a = face * faceCount + row * stride + col
                    quad(a, a + 1, a + stride + 1, a + stride, reversed: (side > 0) != (face == 0))
                }
            }
        }
        for row in 0..<rows {
            for col in [0, cols] {
                let a = row * stride + col
                let b = (row + 1) * stride + col
                quad(a, b, b + faceCount, a + faceCount, reversed: col == 0)
            }
        }
        for row in [0, rows] {
            for col in 0..<cols {
                let a = row * stride + col
                quad(a, a + faceCount, a + faceCount + 1, a + 1, reversed: row == 0)
            }
        }
        let geometry = mesh(vertices, triangles)
        let surface = white.copy() as! SCNMaterial
        surface.isDoubleSided = true
        geometry.materials = [surface]
        return SCNNode(geometry: geometry)
    }

    private static func playStation4() -> SCNNode {
        let root = SCNNode()
        let matte = material(0x292B31, roughness: 0.60)
        let gloss = material(0x171C24, roughness: 0.20, metalness: 0.10)
        // Two angled slabs, each a complete closed mesh rather than flat art.
        for layer in 0..<2 {
            let y: Float = layer == 0 ? -0.15 : 0.13
            let slab = prism(width: 2.75, height: 0.245, depth: 3.05, skew: 0.15)
            slab.materials = [matte]
            let node = SCNNode(geometry: slab)
            node.name = layer == 0 ? "lower angled chassis" : "upper angled chassis"
            node.simdPosition.y = y
            root.addChildNode(node)
        }
        box(root, "central recessed seam", SIMD3(2.73, 0.025, 3.02), SIMD3(0, -0.008, 0), black, radius: 0)
        box(root, "glossy top third", SIMD3(0.87, 0.009, 3.03), SIMD3(-0.49, 0.259, 0), gloss, radius: 0.003)
        let light = material(0x507CB8, roughness: 0.4)
        light.emission.contents = NSColor(srgbRed: 0.06, green: 0.15, blue: 0.38, alpha: 1)
        box(root, "blue status stripe", SIMD3(0.014, 0.012, 3.04), SIMD3(-0.035, 0.265, 0), light, radius: 0.002)
        box(root, "disc slot", SIMD3(1.03, 0.017, 0.014), SIMD3(-0.57, 0.071, 1.529), black, radius: 0.004)
        for x: Float in [0.46, 0.86] { port(root, at: SIMD3(x, -0.075, 1.532), size: SIMD3(0.17, 0.052, 0.025)) }
        box(root, "power control", SIMD3(0.013, 0.16, 0.014), SIMD3(-0.035, 0.12, 1.537), silver, radius: 0.003)
        box(root, "eject control", SIMD3(0.013, 0.16, 0.014), SIMD3(-0.035, -0.15, 1.537), silver, radius: 0.003)
        for sign: Float in [-1, 1] {
            for i in 0..<28 {
                box(root, "side cooling slots", SIMD3(0.008, 0.115, 0.038), SIMD3(sign * 1.366 + Float(i) * 0.003, -0.11, -1.36 + Float(i) * 0.1), black, radius: 0.002)
            }
        }
        let logo = SCNNode()
        logo.eulerAngles.x = -.pi / 2
        logo.simdPosition = SIMD3(0.61, 0.270, 0)
        root.addChildNode(logo)
        text("PS4", parent: logo, at: .zero, width: 0.29, color: silver)
        let rear = SCNNode()
        rear.eulerAngles.y = .pi
        rear.simdPosition = SIMD3(0, 0, -1.535)
        root.addChildNode(rear)
        for (x, width): (Float, Float) in [(-0.88, 0.15), (-0.44, 0.20), (0.10, 0.16), (0.65, 0.22)] {
            port(rear, at: SIMD3(x, -0.09, 0), size: SIMD3(width, 0.078, 0.026))
        }
        for x: Float in [-1.0, 1.0] { for z: Float in [-1.10, 1.10] { box(root, "rubber foot", SIMD3(0.17, 0.026, 0.15), SIMD3(x, -0.286, z), rubber, radius: 0.01) } }
        return root
    }

    private static func xboxSeriesX() -> SCNNode {
        let root = SCNNode()
        let surface = material(0x252A28, roughness: 0.58)
        let body = box(root, "tower body", SIMD3(1.51, 3.01, 1.51), .zero, surface, radius: 0.035)
        let invisible = SCNMaterial()
        invisible.transparency = 0
        invisible.writesToDepthBuffer = false
        body.geometry?.materials = [surface, surface, surface, surface, invisible, surface]
        cylinder(root, "base foot", radius: 0.63, depth: 0.035, at: SIMD3(0, -1.517, 0), black, faceForward: false)
        let green = material(0x427F22, roughness: 0.75)
        box(root, "green fan interior", SIMD3(1.39, 0.018, 1.39), SIMD3(0, 1.25, 0), green, radius: 0.025)
        root.addChildNode(xboxGrille(material: surface))
        box(root, "disc slot", SIMD3(0.018, 1.27, 0.013), SIMD3(-0.52, -0.46, 0.759), black, radius: 0.007)
        cylinder(root, "eject button", radius: 0.019, depth: 0.006, at: SIMD3(-0.52, 0.25, 0.762), graphite)
        cylinder(root, "power emblem surround", radius: 0.071, depth: 0.006, at: SIMD3(0.52, 1.21, 0.757), silver)
        text("×", parent: root, at: SIMD3(0.52, 1.212, 0.765), width: 0.105, color: black)
        port(root, at: SIMD3(0.49, -1.17, 0.763), size: SIMD3(0.145, 0.048, 0.020))
        cylinder(root, "pair button", radius: 0.016, depth: 0.004, at: SIMD3(0.49, -1.04, 0.762), graphite)
        let back = SCNNode()
        back.eulerAngles.y = .pi
        back.simdPosition = SIMD3(0, 0, -0.759)
        root.addChildNode(back)
        box(back, "rear IO recess", SIMD3(0.85, 0.60, 0.012), SIMD3(0.10, -0.96, 0), black, radius: 0.02)
        for x: Float in [-0.13, 0.14] { port(back, at: SIMD3(x, -0.80, 0.018), size: SIMD3(0.14, 0.05, 0.018)) }
        port(back, at: SIMD3(-0.13, -1.02, 0.018), size: SIMD3(0.18, 0.073, 0.018))
        port(back, at: SIMD3(0.14, -1.02, 0.018), size: SIMD3(0.11, 0.12, 0.018))
        for row in 0..<8 {
            for col in 0..<7 {
                box(back, "rear vent", SIMD3(0.10, 0.045, 0.004), SIMD3(-0.53 + Float(col) * 0.17, 0.10 + Float(row) * 0.13, 0), black, radius: 0.015)
            }
        }
        text("XBOX", parent: back, at: SIMD3(0, -0.20, 0.008), width: 0.24, color: ink)
        return root
    }

    private static func xboxGrille(material: SCNMaterial) -> SCNNode {
        // A perforated, concave top: 144 actual openings, not dots painted on
        // a solid box. Each cell is triangulated from a circle to its square rim.
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let cells = 12
        let span: Float = 1.43
        let step = span / Float(cells)
        func height(_ x: Float, _ z: Float) -> Float {
            let radial = min(1, sqrt(x * x + z * z) / 0.88)
            return 1.505 - (1 - radial * radial) * 0.085
        }
        for row in 0..<cells {
            for col in 0..<cells {
                let cx = -span / 2 + (Float(col) + 0.5) * step
                let cz = -span / 2 + (Float(row) + 0.5) * step
                let count = 24
                let base = UInt32(positions.count)
                for segment in 0..<count {
                    let angle = Float(segment) * .pi * 2 / Float(count)
                    let dx = cos(angle), dz = sin(angle)
                    let edge = (step / 2) / max(abs(dx), abs(dz))
                    let inner: Float = 0.041
                    let x1 = cx + dx * inner, z1 = cz + dz * inner
                    let x2 = cx + dx * edge, z2 = cz + dz * edge
                    positions.append(SIMD3(x1, height(x1, z1), z1))
                    positions.append(SIMD3(x2, height(x2, z2), z2))
                    positions.append(SIMD3(x1, height(x1, z1) - 0.045, z1))
                }
                for segment in 0..<count {
                    let next = (segment + 1) % count
                    let a = base + UInt32(segment * 3), b = base + UInt32(next * 3)
                    indices += [a, b, b + 1, a, b + 1, a + 1]
                    indices += [a, b + 2, b, a, a + 2, b + 2]
                }
            }
        }
        let geometry = mesh(positions, indices)
        let grilleMaterial = material.copy() as! SCNMaterial
        grilleMaterial.isDoubleSided = true
        geometry.materials = [grilleMaterial]
        let node = SCNNode(geometry: geometry)
        node.name = "perforated concave cooling grille"
        return node
    }

    private static func port(_ parent: SCNNode, at: SIMD3<Float>, size: SIMD3<Float>) {
        box(parent, "metal IO surround", size, at, silver, radius: 0.003)
        box(parent, "IO port opening", SIMD3(size.x * 0.83, size.y * 0.69, 0.006), at + SIMD3(0, 0, size.z / 2 + 0.001), black, radius: 0.002)
        box(parent, "IO tongue", SIMD3(size.x * 0.63, 0.007, 0.003), at + SIMD3(0, -size.y * 0.1, size.z / 2 + 0.005), graphite, radius: 0)
    }

    private static func prism(width: Float, height: Float, depth: Float, skew: Float) -> SCNGeometry {
        let w = width / 2, h = height / 2, d = depth / 2
        let v: [SIMD3<Float>] = [SIMD3(-w-skew,-h,d), SIMD3(w-skew,-h,d), SIMD3(w+skew,-h,-d), SIMD3(-w+skew,-h,-d),
            SIMD3(-w-skew,h,d), SIMD3(w-skew,h,d), SIMD3(w+skew,h,-d), SIMD3(-w+skew,h,-d)]
        let quads = [[0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7], [4,5,6,7], [3,2,1,0]]
        // Separate vertices along hard edges to keep the industrial corners crisp.
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for q in quads {
            let start = UInt32(vertices.count)
            vertices += q.map { v[$0] }
            indices += [start, start+1, start+2, start, start+2, start+3]
        }
        return mesh(vertices, indices)
    }

    private static func mesh(_ points: [SIMD3<Float>], _ indices: [UInt32]) -> SCNGeometry {
        var normals = Array(repeating: SIMD3<Float>.zero, count: points.count)
        for offset in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[offset]), b = Int(indices[offset+1]), c = Int(indices[offset+2])
            let normal = simd_cross(points[b] - points[a], points[c] - points[a])
            normals[a] += normal; normals[b] += normal; normals[c] += normal
        }
        let vertices = SCNGeometrySource(vertices: points.map { SCNVector3($0) })
        let normalSource = SCNGeometrySource(normals: normals.map { SCNVector3(simd_length_squared($0) > 0 ? simd_normalize($0) : SIMD3(0,1,0)) })
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [vertices, normalSource], elements: [element])
    }
}

private extension SCNVector3 {
    static func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x+b.x, a.y+b.y, a.z+b.z) }
    static func - (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x-b.x, a.y-b.y, a.z-b.z) }
    static prefix func - (v: SCNVector3) -> SCNVector3 { SCNVector3(-v.x,-v.y,-v.z) }
    static func * (a: SCNVector3, s: CGFloat) -> SCNVector3 { SCNVector3(a.x*s,a.y*s,a.z*s) }
}
