import AppKit
import Metal
import SceneKit
import SwiftUI

struct ModelOrbit: Equatable {
    var yaw: Float = -0.30
    var pitch: Float = 0.18
    var zoom: Double = 1

    mutating func rotate(x: Double, y: Double) {
        guard x.isFinite, y.isFinite else { return }
        yaw = Float((Double(yaw) + x * 0.010).remainder(dividingBy: .pi * 2))
        pitch = min(1.25, max(-1.25, pitch + Float(y) * 0.010))
    }

    mutating func magnify(_ delta: Double) {
        guard delta.isFinite else { return }
        zoom = min(1.9, max(0.60, zoom * exp(-min(4, max(-4, delta)))))
    }

    static func initial(_ console: Console) -> ModelOrbit {
        ModelOrbit(yaw: console == .ps5 ? -0.12 : -0.30, pitch: console == .ps4 ? 0.48 : 0.17)
    }
}

enum StudioAction { case reset, front, back, zoomIn, zoomOut }

@MainActor
enum ConsoleStudio {
    private static var thumbnails: [Console: NSImage] = [:]
    static var liveViewCount = 0

    static func scene(for console: Console) -> (SCNScene, SCNNode, SCNNode) {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = environment()
        scene.lightingEnvironment.intensity = 0.18
        let model = ConsoleModels.make(console)
        scene.rootNode.addChildNode(model)

        let camera = SCNNode()
        camera.name = "studio camera"
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 60
        camera.camera?.wantsHDR = true
        camera.camera?.wantsExposureAdaptation = false
        camera.camera?.exposureOffset = -0.85
        camera.camera?.bloomIntensity = 0.50
        camera.camera?.bloomThreshold = 1.15
        camera.camera?.bloomBlurRadius = 8
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.65
        camera.camera?.screenSpaceAmbientOcclusionRadius = 0.15
        camera.position = SCNVector3(0, 0, 8)
        scene.rootNode.addChildNode(camera)

        light(scene, kind: .omni, position: SCNVector3(-3.5, 4.5, 5), intensity: 150,
            color: NSColor(srgbRed: 1, green: 0.97, blue: 0.94, alpha: 1))
        light(scene, kind: .omni, position: SCNVector3(4, 1.0, 3), intensity: 65,
            color: NSColor(srgbRed: 0.78, green: 0.86, blue: 1, alpha: 1))
        light(scene, kind: .omni, position: SCNVector3(1.5, 3.5, -4), intensity: 140,
            color: NSColor(srgbRed: 0.90, green: 0.94, blue: 1, alpha: 1))
        light(scene, kind: .ambient, position: SCNVector3Zero, intensity: 40, color: .white)
        apply(ModelOrbit.initial(console), to: model, camera: camera, size: CGSize(width: 640, height: 360))
        return (scene, model, camera)
    }

    static func apply(_ orbit: ModelOrbit, to model: SCNNode, camera: SCNNode, size: CGSize) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        model.simdEulerAngles = SIMD3(orbit.pitch, orbit.yaw, 0)
        let bounds = model.boundingBox
        let width = Double(bounds.max.x - bounds.min.x)
        let height = Double(bounds.max.y - bounds.min.y)
        let depth = Double(bounds.max.z - bounds.min.z)
        let aspect = max(0.4, Double(size.width / max(1, size.height)))
        let verticalExtent = height * abs(cos(Double(orbit.pitch))) + depth * abs(sin(Double(orbit.pitch)))
        let horizontalExtent = width * abs(cos(Double(orbit.yaw))) + depth * abs(sin(Double(orbit.yaw)))
        camera.camera?.orthographicScale = max(verticalExtent, horizontalExtent / aspect) * 0.64 * orbit.zoom
        SCNTransaction.commit()
    }

    static func thumbnail(_ console: Console) -> NSImage {
        if let image = thumbnails[console] { return image }
        if let url = Bundle.main.url(forResource: console.rawValue, withExtension: "png", subdirectory: "ConsoleModels"),
           let image = NSImage(contentsOf: url) {
            thumbnails[console] = image
            return image
        }
        let image = render(console, size: CGSize(width: 960, height: 540))
        thumbnails[console] = image
        return image
    }

    static func render(_ console: Console, size: CGSize, orbit: ModelOrbit? = nil) -> NSImage {
        let (scene, model, camera) = scene(for: console)
        apply(orbit ?? ModelOrbit.initial(console), to: model, camera: camera, size: size)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        renderer.scene = nil
        renderer.pointOfView = nil
        return image
    }

    static func exportThumbnails(to directory: URL, only selected: Console? = nil, orbit: ModelOrbit? = nil) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for console in selected.map({ [$0] }) ?? Console.allCases {
            let image = render(console, size: CGSize(width: 1280, height: 720), orbit: orbit)
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { continue }
            try png.write(to: directory.appendingPathComponent(console.rawValue + ".png"))
        }
    }

    private static func light(_ scene: SCNScene, kind: SCNLight.LightType, position: SCNVector3, intensity: CGFloat, color: NSColor) {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = kind
        node.light?.intensity = intensity
        node.light?.color = color
        node.light?.attenuationStartDistance = 0
        node.light?.attenuationEndDistance = 18
        node.position = position
        scene.rootNode.addChildNode(node)
    }

    private static var studioEnvironment: NSImage?
    private static func environment() -> NSImage {
        if let studioEnvironment { return studioEnvironment }
        // A procedural studio reflection map. No downloaded photography.
        let image = NSImage(size: NSSize(width: 1024, height: 512))
        image.lockFocus()
        NSGradient(colors: [NSColor(white: 0.07, alpha: 1), NSColor(white: 0.25, alpha: 1), NSColor(white: 0.65, alpha: 1)])!
            .draw(in: NSRect(x: 0, y: 0, width: 1024, height: 512), angle: 90)
        NSColor(white: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 90, y: 245, width: 115, height: 195), xRadius: 30, yRadius: 30).fill()
        NSColor(white: 0.75, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 710, y: 220, width: 55, height: 240), xRadius: 15, yRadius: 15).fill()
        image.unlockFocus()
        studioEnvironment = image
        return image
    }
}

@MainActor
final class ConsoleModelSurface: SCNView {
    private(set) var console: Console?
    private var hardware: SCNNode?
    private var studioCamera: SCNNode?
    private var orbit = ModelOrbit()
    private var registered = false
    var lastCommand = 0

    override init(frame: NSRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        backgroundColor = .clear
        antialiasingMode = .multisampling4X
        preferredFramesPerSecond = 60
        rendersContinuously = false
        isPlaying = false
        allowsCameraControl = false // Use a bounded orbit with no idle inertia.
        autoenablesDefaultLighting = false
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    func install(_ console: Console) {
        guard self.console != console else { return }
        self.console = console
        let (scene, model, camera) = ConsoleStudio.scene(for: console)
        self.scene = scene
        hardware = model
        studioCamera = camera
        pointOfView = camera
        orbit = .initial(console)
        if !registered { ConsoleStudio.liveViewCount += 1; registered = true }
        setAccessibilityLabel("Interactive \(console.name) 3D model")
        setAccessibilityHelp("Drag to rotate. Scroll or pinch to zoom. Arrow keys rotate. Double-click resets the view.")
        applyOrbit()
    }

    override func layout() { super.layout(); applyOrbit() }

    private func applyOrbit() {
        guard let hardware, let studioCamera else { return }
        ConsoleStudio.apply(orbit, to: hardware, camera: studioCamera, size: bounds.size)
        needsDisplay = true
    }

    func command(_ action: StudioAction) {
        guard let console else { return }
        switch action {
        case .reset: orbit = .initial(console)
        case .front: orbit = ModelOrbit(yaw: 0, pitch: 0, zoom: orbit.zoom)
        case .back: orbit = ModelOrbit(yaw: .pi, pitch: 0.14, zoom: orbit.zoom)
        case .zoomIn: orbit.magnify(0.16)
        case .zoomOut: orbit.magnify(-0.16)
        }
        applyOrbit()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.clickCount == 2 { command(.reset) }
    }
    override func mouseDragged(with event: NSEvent) {
        orbit.rotate(x: event.deltaX, y: event.deltaY)
        applyOrbit()
    }
    override func scrollWheel(with event: NSEvent) {
        orbit.magnify(Double(event.scrollingDeltaY) * (event.hasPreciseScrollingDeltas ? 0.008 : 0.08))
        applyOrbit()
    }
    override func magnify(with event: NSEvent) { orbit.magnify(Double(event.magnification)); applyOrbit() }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: orbit.rotate(x: -12, y: 0)
        case 124: orbit.rotate(x: 12, y: 0)
        case 125: orbit.rotate(x: 0, y: 12)
        case 126: orbit.rotate(x: 0, y: -12)
        default: super.keyDown(with: event); return
        }
        applyOrbit()
    }

    func releaseRenderer() {
        isPlaying = false
        rendersContinuously = false
        scene = nil
        pointOfView = nil
        hardware = nil
        studioCamera = nil
        if registered { ConsoleStudio.liveViewCount -= 1; registered = false }
    }
}

struct ConsoleViewport: NSViewRepresentable {
    let console: Console
    var action: StudioAction = .reset
    var commandID = 0

    func makeNSView(context: Context) -> ConsoleModelSurface {
        let view = ConsoleModelSurface(frame: .zero)
        view.install(console)
        return view
    }
    func updateNSView(_ view: ConsoleModelSurface, context: Context) {
        view.install(console)
        if view.lastCommand != commandID { view.command(action); view.lastCommand = commandID }
    }
    static func dismantleNSView(_ view: ConsoleModelSurface, coordinator: ()) { view.releaseRenderer() }
}

