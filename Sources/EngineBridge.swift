import Foundation
import AppKit
import Darwin

// The core owns emulation. This bridge owns only the process we launched,
// its arguments, and its output. No shell is involved in launching a game.
@MainActor
final class EngineBridge: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var output = ""
    @Published private(set) var currentTitle = ""
    @Published private(set) var diagnosticPassed = false
    private var child: Process?
    private var pipe: Pipe?
    private var commandPort: UInt16?
    @Published private(set) var currentItem: LibraryItem?
    var retro: RetroRuntime { RetroRuntime(bundle: Bundle.main.bundleURL) }
    var isRetro: Bool { currentItem?.system != .switchSystem && currentItem != nil }
    @Published private(set) var started = Date()
    @Published private(set) var menuOpen = false
    @Published private(set) var speed = 1
    @Published var fastTarget = 2
    private var speedRequest:URL?
    func setFastTarget(_ value:Int){fastTarget=max(2,min(5,value));if let speedRequest{try? Data(String(fastTarget).utf8).write(to:speedRequest,options:.atomic)}}
    private var menuRequest:URL?
    private var statusPath:URL?
    private var statusTimer:Timer?
    private var actionRequest:URL?
    private var actionResult:URL?
    private var displayRequest:URL?
    @Published private(set) var emulatedFrames:UInt64=0
    @Published private(set) var videoFrames:UInt64=0
    @Published private(set) var presentedFrames:UInt64=0
    @Published private(set) var rendererAttached=false
    @Published private(set) var health="Idle"
    private var lastProgress=Date()
    private var lastHeartbeat=Date()
    var onPlayerAction:((String,Int)->Void)?
    var onBeforeStop:(()->Void)?
    func refreshDisplay(){guard running,isRetro,let displayRequest else{return};try? Data().write(to:displayRequest,options:.atomic);health="Display refresh requested"}
    func reportPlayerAction(_ message:String,success:Bool){guard let actionResult else{return};if let data=try? JSONSerialization.data(withJSONObject:["message":message,"success":success,"time":Date().timeIntervalSince1970]){try? data.write(to:actionResult,options:.atomic)}}
    func focusGame() {if let child {NSRunningApplication(processIdentifier:child.processIdentifier)?.activate(options:[.activateAllWindows])}}
    func openSessionMenu() {
        guard running else{return}
        focusGame()
        if isRetro, let menuRequest {try? Data().write(to:menuRequest,options:.atomic)}
    }
    func resumeGame(){guard running else{return};focusGame();if isRetro,let menuRequest{try? Data("resume".utf8).write(to:menuRequest,options:.atomic)}}
    static func elapsed(_ seconds:Double)->String {let t=max(0,Int(seconds));return t>=3600 ? String(format:"%d:%02d:%02d",t/3600,t/60%60,t%60):String(format:"%02d:%02d",t/60,t%60)}
    private var stoppedByUser = false
    private var logHandle: FileHandle?
    private var logURL: URL?
    private var pending = Data()
    var onSkinChange: ((ConsoleSkin) -> Void)?
    private var activeSkin: ConsoleSkin = .none
    var onFinish: ((SessionRecord) -> Void)?

    var executable: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Ryujinx.app/Contents/MacOS/Ryujinx")
    }
    var available: Bool { FileManager.default.isExecutableFile(atPath: executable.path) }

    func launch(item: LibraryItem, root: URL, logs: URL, preferences: Preferences, controllerArguments: [String] = [], dataRoot: URL? = nil, resume: Bool = false, display:DisplayProfile = DisplayProfile(), keyboard:KeyboardMapping = KeyboardMapping(), fastSpeed:Int = 2) throws {
        guard !running else { throw AppFailure.message("Stop the current session before starting another.") }
        var display=display
        if display.selectedWindowPreset == .fitDisplay{let frame=NSApp.keyWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1280,height:800);display.applyWindowPreset(.fitDisplay,availableWidth:Int(frame.width),availableHeight:Int(frame.height))}
        guard item.system == .switchSystem ? available : retro.available(item.system) else { throw AppFailure.message("The bundled emulation core is missing. Rebuild NEXARC with scripts/build.sh.") }
        guard FileManager.default.fileExists(atPath: item.path) else { throw AppFailure.message("The program has moved. Remove this library entry and import it again.") }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        output = ""; pending = Data(); diagnosticPassed = false; stoppedByUser = false
        currentTitle = item.displayTitle; currentItem = item; started = Date()
        let log = logs.appendingPathComponent(UUID().uuidString + ".log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        logHandle = try FileHandle(forWritingTo: log); logURL = log
        let process = Process(), stream = Pipe()
        process.executableURL = item.system == .switchSystem ? executable : retro.executable
        process.arguments = LaunchPlan.arguments(file: item.path, root: root.path, preferences: preferences, diagnostic: item.isDiagnostic)
        if item.system == .switchSystem { process.arguments?.insert(contentsOf: controllerArguments, at: 1) }
        else {
            commandPort = try Self.freeLocalPort()
            process.arguments = try retro.prepare(item, dataRoot: dataRoot ?? root, preferences: preferences, resume: resume, commandPort:Int(commandPort!), display:display, keyboard:keyboard)
            process.standardInput = FileHandle.nullDevice
        }
        process.currentDirectoryURL = root
        process.standardOutput = stream; process.standardError = stream
        var environment = ProcessInfo.processInfo.environment
        environment["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
        environment["NEXARC_SYSTEM_NAME"]=item.system.shortName
        environment["NEXARC_SKIN_DESIGN"]=item.system.skinDesign
        environment["NEXARC_SHELL_COLOR"]=String(item.system.shellColor,radix:16)
        environment["NEXARC_ACCENT_COLOR"]=String(item.system.color,radix:16)
        if let hardware=HardwareSkinCatalog.asset(for:item.system) {
            let image=HardwareSkinCatalog.image(for:hardware)
            environment["NEXARC_HARDWARE_IMAGE"]=image.path
            environment["NEXARC_HARDWARE_ASPECT"]=String(hardware.imageAspect)
            let area=hardware.screen.fitted
            environment["NEXARC_HARDWARE_SCREEN"]="\(area.x),\(area.y),\(area.width),\(area.height)"
        }
        if let asset=display.customAsset {
            let image=(dataRoot ?? root).appendingPathComponent(asset.file).standardizedFileURL
            if FileManager.default.fileExists(atPath:image.path) {
                environment["NEXARC_SKIN_IMAGE"]=image.path
                environment["NEXARC_SKIN_IMAGE_ASPECT"]=String(asset.imageAspect)
                let area=asset.screen.fitted
                environment["NEXARC_SKIN_SCREEN"]="\(area.x),\(area.y),\(area.width),\(area.height)"
            } else if display.skin == .custom {throw AppFailure.message("The uploaded skin image is missing. Choose another skin in Settings → Console display & skins.")}
        } else if display.skin == .custom {throw AppFailure.message("Upload a skin image in Settings → Console display & skins first.")}
        environment["NEXARC_WINDOW_TITLE"] = "NEXARC · \(item.displayTitle)"
        // These two bundled programs have no saves; the core uses their isolated exit path.
        environment["NEXARC_DIAGNOSTIC"] = item.isDiagnostic || item.bundledName == "orbit-pong" ? "1" : "0"
        if item.system != .switchSystem, let commandPort {
            environment["DYLD_INSERT_LIBRARIES"] = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/LocalCommands.dylib").path
            environment["DYLD_INSERT_LIBRARIES"]! += ":" + Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/PlayerCompanion.dylib").path
            environment["NEXARC_COMMAND_PORT"] = String(commandPort)
            let gameRoot=RetroRuntime.gameRoot(item,dataRoot:dataRoot ?? root)
            menuRequest=gameRoot.appendingPathComponent("session-menu.request")
            statusPath=gameRoot.appendingPathComponent("session-status.json")
            try? FileManager.default.removeItem(at:menuRequest!);try? FileManager.default.removeItem(at:statusPath!)
            environment["NEXARC_MENU_REQUEST"]=menuRequest!.path
            environment["NEXARC_STATUS_PATH"]=statusPath!.path
            environment["NEXARC_SLOTS_DIRECTORY"]=gameRoot.appendingPathComponent("Save Slots").path
            environment["NEXARC_STATE_PATH"]=RetroRuntime.states(item,dataRoot:dataRoot ?? root).appendingPathComponent(URL(fileURLWithPath:item.path).deletingPathExtension().lastPathComponent+".state").path
            environment["NEXARC_GAME_TITLE"]=item.displayTitle
            environment["NEXARC_SYSTEM"]=item.system.shortName
            environment["NEXARC_SYSTEM_ID"]=item.system.rawValue
            environment["NEXARC_CORE_PATH"]=retro.core(item.system).path
            environment["NEXARC_SKIN"]=display.skin.rawValue
            environment["NEXARC_LAYOUT"]=display.layout.rawValue
            environment["NEXARC_GAP"]=String(display.effectiveGap)
            environment["NEXARC_ASPECT"]=String(display.skin == .hardware && item.system == .nds ? 256.0/392:display.aspect(item.system))
            environment["NEXARC_SIZING"]=display.sizing
            environment["NEXARC_SMOOTH"]=display.smooth ? "1":"0"
            environment["NEXARC_WINDOW_WIDTH"]=String(max(480,min(3840,display.windowWidth)))
            environment["NEXARC_WINDOW_HEIGHT"]=String(max(360,min(2160,display.windowHeight)))
        }
        let sessionRoot=RetroRuntime.gameRoot(item,dataRoot:dataRoot ?? root)
        try FileManager.default.createDirectory(at:sessionRoot,withIntermediateDirectories:true)
        actionRequest=sessionRoot.appendingPathComponent("player-action.request")
        actionResult=sessionRoot.appendingPathComponent("player-action-result.json")
        displayRequest=sessionRoot.appendingPathComponent("display-refresh.request")
        for file in [actionRequest,actionResult,displayRequest].compactMap({$0}){try? FileManager.default.removeItem(at:file)}
        environment["NEXARC_PLAYER_ACTION"]=actionRequest!.path
        environment["NEXARC_PLAYER_RESULT"]=actionResult!.path
        environment["NEXARC_DISPLAY_REQUEST"]=displayRequest!.path
        if let mapping=item.overrides?.gamepad,mapping.buttons.count==16{environment["NEXARC_GAMEPAD_MAP"]=mapping.buttons.map{String(max(0,min(15,$0)))}.joined(separator:",")}
        environment["NEXARC_CAPTURE_VIDEO"]=[GameSystem.nds,.n3ds].contains(item.system) ? "1":"0"
        if let asset=display.customAsset,display.skin == .custom,let secondary=asset.secondaryScreen {
            environment["NEXARC_DUAL_PRIMARY"]=Self.skinRect(asset.screen)
            environment["NEXARC_DUAL_SECONDARY"]=Self.skinRect(secondary)
        }
        speedRequest=sessionRoot.appendingPathComponent("speed-target.request")
        try? FileManager.default.removeItem(at:speedRequest!)
        if item.system == .switchSystem {statusPath=sessionRoot.appendingPathComponent("session-status.json");try? FileManager.default.removeItem(at:statusPath!)}
        environment["NEXARC_STATUS_PATH"]=statusPath?.path
        environment["NEXARC_SPEED_CONTROL"]="1"
        environment["NEXARC_FAST_SPEED"]=String(max(2,min(5,fastSpeed)))
        environment["NEXARC_SPEED_REQUEST"]=speedRequest!.path
        if item.system == .switchSystem {
            environment["NEXARC_SKIN"] = display.skin.rawValue
            environment["NEXARC_SYSTEM_ID"] = item.system.rawValue
            environment["NEXARC_GAME_TITLE"] = item.displayTitle
            environment["NEXARC_SWITCH_OVERLAY"] = "1"
            environment["DYLD_INSERT_LIBRARIES"] = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/PlayerCompanion.dylib").path
        } else {
            environment["NEXARC_RESUMING"] = resume ? "1" : "0"
        }
        activeSkin=display.skin
        fastTarget=max(2,min(5,fastSpeed));speed=1
        process.environment = environment
        // FileHandle callbacks arrive off the main thread. Serialize UI changes here.
        stream.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in self?.append(data) }
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                stream.fileHandleForReading.readabilityHandler = nil
                self.append(stream.fileHandleForReading.readDataToEndOfFile())
                try? self.logHandle?.close(); self.logHandle = nil
                self.running = false; self.child = nil; self.pipe = nil
                self.commandPort = nil; self.statusTimer?.invalidate(); self.statusTimer=nil; self.menuOpen=false; self.speed=1;self.health="Idle"
                let record = SessionRecord(itemID: item.id, title: item.title, started: self.started,
                    duration: Date().timeIntervalSince(self.started), exitCode: process.terminationStatus,
                    verifiedDiagnostic: self.diagnosticPassed && item.isDiagnostic && process.terminationStatus == 0,
                    stoppedByUser: self.stoppedByUser, logPath: log.path)
                self.onFinish?(record)
            }
        }
        do { try process.run() }
        catch {
            stream.fileHandleForReading.readabilityHandler = nil
            try? logHandle?.close(); logHandle = nil
            throw error
        }
        child = process; pipe = stream; running = true
        emulatedFrames=0;videoFrames=0;presentedFrames=0;rendererAttached=false;health="Starting";lastProgress=Date();lastHeartbeat=Date()
        statusTimer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){[weak self] _ in Task{@MainActor in self?.pollPlayer()}}
        Task { @MainActor [weak self, weak process] in
            try? await Task.sleep(for:.milliseconds(800))
            if let process,process.isRunning,self?.child === process {NSRunningApplication(processIdentifier:process.processIdentifier)?.activate(options:[.activateAllWindows])}
        }
    }

    private static func skinRect(_ area:SkinScreenArea)->String{let a=area.fitted;return "\(a.x),\(a.y),\(a.width),\(a.height)"}
    private func pollPlayer(){
        guard running else{return}
        if let request=actionRequest,let data=try? Data(contentsOf:request){
            try? FileManager.default.removeItem(at:request)
            if let object=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let action=object["action"] as? String {onPlayerAction?(action,max(0,min(5,object["slot"] as? Int ?? 0)))}
        }
        if let path=statusPath,let data=try? Data(contentsOf:path),let v=try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
            lastHeartbeat=(try? FileManager.default.attributesOfItem(atPath:path.path)[.modificationDate] as? Date) ?? lastHeartbeat
            if let value=v["skin"] as? String,let skin=ConsoleSkin(rawValue:value),skin != activeSkin{activeSkin=skin;onSkinChange?(skin)}
            menuOpen=(v["menuOpen"] as? Bool ?? false) || (v["paused"] as? Bool ?? false);speed=v["speed"] as? Int ?? 1
            let frames=(v["emulatedFrames"] as? NSNumber)?.uint64Value ?? 0
            if frames != emulatedFrames{lastProgress=Date()};emulatedFrames=frames
            videoFrames=(v["videoFrames"] as? NSNumber)?.uint64Value ?? 0
            presentedFrames=(v["presentedFrames"] as? NSNumber)?.uint64Value ?? 0
            rendererAttached=v["rendererAttached"] as? Bool ?? false
        }
        if !isRetro{health="Running"}
        else if Date().timeIntervalSince(started)<5{health="Starting"}
        else if Date().timeIntervalSince(lastHeartbeat)>8{health="Player not responding"}
        else if menuOpen{health="Paused"}
        else if !rendererAttached{health="Display detached"}
        else if Date().timeIntervalSince(lastProgress)>8{health="No frame progress"}
        else{health="Running"}
    }
    private func append(_ bytes: Data) {
        guard !bytes.isEmpty else { return }
        try? logHandle?.write(contentsOf: bytes)
        pending.append(bytes)
        // Preserve multibyte characters split across reads until valid UTF-8 arrives.
        guard let text = String(data: pending, encoding: .utf8) else { return }
        pending.removeAll(keepingCapacity: true)
        output += text
        if output.contains("NEXARC_DIAGNOSTIC_PASS") { diagnosticPassed = true }
        if output.count > 160_000 { output = String(output.suffix(120_000)) }
    }

    private static func freeLocalPort() throws -> UInt16 {
        let fd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP);guard fd>=0 else {throw AppFailure.message("Could not reserve a local session port.")};defer{close(fd)}
        var address=sockaddr_in();address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);address.sin_family=sa_family_t(AF_INET);address.sin_addr.s_addr=inet_addr("127.0.0.1")
        let bound=withUnsafePointer(to:&address){$0.withMemoryRebound(to:sockaddr.self,capacity:1){bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}
        guard bound==0 else {throw AppFailure.message("Could not reserve a local session port.")}
        var length=socklen_t(MemoryLayout<sockaddr_in>.size)
        guard withUnsafeMutablePointer(to:&address,{$0.withMemoryRebound(to:sockaddr.self,capacity:1){getsockname(fd,$0,&length)}})==0 else {throw AppFailure.message("Could not read the session port.")}
        return UInt16(bigEndian:address.sin_port)
    }

    func send(_ command: String) throws {
        let allowed: Set<String> = ["SAVE_STATE","LOAD_STATE","PAUSE_TOGGLE","FAST_FORWARD","RESET","SCREENSHOT","MENU_TOGGLE","QUIT"]
        guard running, isRetro, allowed.contains(command), let commandPort else { throw AppFailure.message("This control is available during a retro-console session.") }
        // Cocoa's draw observer processes commands when the game window is active.
        if let child {NSRunningApplication(processIdentifier:child.processIdentifier)?.activate(options:[.activateAllWindows])}
        let fd=socket(AF_INET,SOCK_DGRAM,IPPROTO_UDP)
        guard fd>=0 else {throw AppFailure.message("Could not open the local session control socket.")};defer{close(fd)}
        var address=sockaddr_in();address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);address.sin_family=sa_family_t(AF_INET);address.sin_port=commandPort.bigEndian;address.sin_addr.s_addr=inet_addr("127.0.0.1")
        let data=Data((command + "\n").utf8)
        let sent=data.withUnsafeBytes {bytes in withUnsafePointer(to:&address) {ptr in ptr.withMemoryRebound(to:sockaddr.self,capacity:1) {sendto(fd,bytes.baseAddress,data.count,0,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}}
        guard sent==data.count else {throw AppFailure.message("The session control command could not be sent.") }
    }

    func stop() {
        guard let child, child.isRunning else { return }
        onBeforeStop?()
        stoppedByUser = true
        if isRetro { try? send("QUIT") } else { child.terminate() }
        // Cocoa cores may recreate their input drivers. Ask the owned app to quit
        // normally if it did not respond, so its native save-on-exit hook still runs.
        if isRetro {
            Task { @MainActor [weak self, weak child] in
                try? await Task.sleep(for:.seconds(1))
                if let child,child.isRunning,self?.child === child {NSRunningApplication(processIdentifier:child.processIdentifier)?.terminate()}
            }
        }
        // Only signal the Process instance we own; never search for other emulator processes.
        Task { @MainActor [weak self, weak child] in
            try? await Task.sleep(for: .seconds(self?.isRetro == true ? 15 : 5))
            if let child, child.isRunning, self?.child === child { kill(child.processIdentifier, SIGKILL) }
        }
    }
}
