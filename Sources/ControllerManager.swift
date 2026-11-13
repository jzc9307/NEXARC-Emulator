import AppKit
import GameController

struct CoreController: Identifiable, Equatable { let id: String; let name: String }

@MainActor
final class ControllerManager: ObservableObject {
    @Published var profiles: [ControllerProfile] = (1...4).map { ControllerProfile(player: $0) }
    @Published var player = 1
    @Published var devices: [CoreController] = []
    @Published var nativeNames: [String] = []
    @Published var nativeIndex = 0 { didSet { attachNative() } }
    @Published var pressed: Set<String> = []
    @Published var leftStick: CGPoint = .zero
    @Published var rightStick: CGPoint = .zero
    @Published var triggerValues: [Float] = [0,0]
    @Published var waitingFor: String?
    @Published var probing = false
    @Published var message: String?
    private let root: URL
    private let store: URL
    private let executable: URL
    private var nativeDevices: [GCController] = []
    private var probe: Process?
    private var applied: [ControllerProfile] = []
    var profile: ControllerProfile { profiles[player-1] }
    var launchArguments: [String] { applied.flatMap(\.arguments) }
    var hasNativeDevice: Bool { nativeDevices.indices.contains(nativeIndex) }
    var nativeFamily: ControllerFamily { hasNativeDevice ? .detect((nativeDevices[nativeIndex].vendorName ?? "") + " " + nativeDevices[nativeIndex].productCategory) : .generic }

    init(root: URL, dataRoot: URL, executable: URL) {
        self.root = root; self.store = dataRoot.appendingPathComponent("controllers.json"); self.executable = executable
        if let data = try? Data(contentsOf: store), let saved = try? JSONDecoder().decode([ControllerProfile].self, from: data), saved.count == 4 { profiles = saved }
        applied = profiles
        refreshNative()
        // Controller hot-plug should only refresh Apple's native device list.
        // Launching the Switch executable here to enumerate SDL devices can
        // make the Ryujinx helper appear unexpectedly. SDL probing is manual.
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshNative() } }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshNative() } }
    }
    func change(_ edit: (inout ControllerProfile) -> Void) { edit(&profiles[player-1]) }
    func refreshNative() {
        for controller in nativeDevices { controller.extendedGamepad?.valueChangedHandler = nil }
        nativeDevices = GCController.controllers()
        nativeNames = nativeDevices.map { $0.vendorName ?? $0.productCategory }
        nativeIndex = min(nativeIndex,max(0,nativeDevices.count-1))
        attachNative()
    }
    private func attachNative() {
        pressed = []; waitingFor = nil
        guard nativeDevices.indices.contains(nativeIndex) else { return }
        let controller = nativeDevices[nativeIndex]
        controller.handlerQueue = .main
        controller.extendedGamepad?.valueChangedHandler = { [weak self] pad, _ in
            Task { @MainActor in self?.read(pad) }
        }
        if nativeFamily != .generic { change { $0.family = nativeFamily } }
    }
    private func read(_ pad: GCExtendedGamepad) {
        let buttons: [(String,GCControllerButtonInput?)] = [("South",pad.buttonA),("East",pad.buttonB),("West",pad.buttonX),("North",pad.buttonY),("LeftShoulder",pad.leftShoulder),("RightShoulder",pad.rightShoulder),("LeftTrigger",pad.leftTrigger),("RightTrigger",pad.rightTrigger),("LeftStick",pad.leftThumbstickButton),("RightStick",pad.rightThumbstickButton),("Minus",pad.buttonOptions),("Plus",pad.buttonMenu),("DpadUp",pad.dpad.up),("DpadDown",pad.dpad.down),("DpadLeft",pad.dpad.left),("DpadRight",pad.dpad.right)]
        let now = Set(buttons.filter { $0.1?.isPressed == true }.map(\.0))
        let newlyPressed = now.subtracting(pressed)
        if let target = waitingFor, let first = newlyPressed.sorted().first { change { $0.bindings[target] = first }; waitingFor = nil }
        pressed = now
        leftStick = CGPoint(x: CGFloat(pad.leftThumbstick.xAxis.value), y: CGFloat(pad.leftThumbstick.yAxis.value))
        rightStick = CGPoint(x: CGFloat(pad.rightThumbstick.xAxis.value), y: CGFloat(pad.rightThumbstick.yAxis.value))
        triggerValues = [pad.leftTrigger.value,pad.rightTrigger.value]
    }
    func refreshCoreDevices() {
        guard !probing else { return }; probing = true
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let log = root.appendingPathComponent("controller-probe.log")
            FileManager.default.createFile(atPath: log.path, contents: nil)
            let handle = try FileHandle(forWritingTo: log), process = Process()
            process.executableURL = executable
            process.arguments = ["--no-gui","--root-data-dir",root.path,"--list-input-ids","unused.nro"]
            process.currentDirectoryURL = root; process.standardOutput = handle; process.standardError = handle
            process.terminationHandler = { [weak self] _ in
                try? handle.close()
                let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
                Task { @MainActor in
                    guard let self else { return }
                    let expression = try! NSRegularExpression(pattern: "- ([^\\r\\n]+) \\(\"([^\"]+)\"\\)")
                    self.devices = expression.matches(in: text, range: NSRange(text.startIndex...,in:text)).compactMap { match in
                        guard let idRange = Range(match.range(at:1),in:text), let nameRange = Range(match.range(at:2),in:text) else { return nil }
                        let id = String(text[idRange]), name = String(text[nameRange])
                        return name.lowercased().contains("keyboard") ? nil : CoreController(id:id,name:name)
                    }
                    if self.devices.count == 1 && self.profile.deviceID.isEmpty { self.selectDevice(self.devices[0].id) }
                    self.probing = false; self.probe = nil
                }
            }
            try process.run(); probe = process
            Task { @MainActor [weak self,weak process] in
                try? await Task.sleep(for:.seconds(7))
                if let process, process.isRunning, self?.probe === process { process.terminate() }
            }
        } catch { probing = false; message = error.localizedDescription }
    }
    func selectDevice(_ id: String) {
        change { $0.deviceID = id }
        if let device = devices.first(where: { $0.id == id }) {
            let family = ControllerFamily.detect(device.name)
            if family != .generic { change { $0.family = family } }
            if let index = nativeNames.firstIndex(where: { ControllerFamily.detect($0) == family }) { nativeIndex = index }
        }
    }
    func save() {
        do {
            let folder = root.appendingPathComponent("profiles/controller")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            for profile in profiles {
                let data = try JSONSerialization.data(withJSONObject:profile.coreJSON(),options:[.prettyPrinted,.sortedKeys])
                try data.write(to:folder.appendingPathComponent(profile.profileName+".json"),options:.atomic)
            }
            try JSONEncoder().encode(profiles).write(to:store,options:.atomic)
            applied = profiles
            message = profile.deviceID.isEmpty ? "Profile saved. Choose a connected device to use it in games." : "Player \(player) profile saved. It will be used on your next launch."
        } catch { message = error.localizedDescription }
    }
}
