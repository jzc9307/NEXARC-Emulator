import AppKit
import GameController
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var saved = SavedState()
    @Published var section = "Consoles"
    @Published var selectedSystem: GameSystem?
    @Published var inspectedItem: LibraryItem?
    @Published var galleryFilter = "All systems"
    @Published var search = ""
    @Published var filter = "All programs"
    @Published var error: String?
    @Published var toast: String?
    @Published var controllerNames: [String] = []
    @Published var showInspector = false
    @Published var coverLoading:Set<UUID>=[]
    @Published var saveOperation:String?
    @Published var recoveryOpen=false
    @Published var controllerSelection:UUID?
    @Published var controllerConsoleIndex=0
    @Published var controllerNavigationActive=false
    @Published var controllerDetailSlot=0
    var libraryColumns=3
    var navigationTimer:Timer?
    var navigationHasFocus=false
    var navigationPrevious:Set<String>=[]
    var navigationRepeat=Date.distantPast
    let engine = EngineBridge()
    private let discordPresence = DiscordPresence()
    lazy var controllers = ControllerManager(root: coreRoot, dataRoot: dataRoot, executable: engine.executable)
    private var coreApplication: NSRunningApplication?
    let dataRoot: URL
    var coreRoot: URL { dataRoot.appendingPathComponent("Core") }
    var stateURL: URL { dataRoot.appendingPathComponent("library.json") }
    var logs: URL { dataRoot.appendingPathComponent("Sessions") }
    var hasKeys: Bool { FileManager.default.fileExists(atPath: coreRoot.appendingPathComponent("system/prod.keys").path) }
    var firmwarePresent: Bool {
        let path = coreRoot.appendingPathComponent("bis/system/Contents/registered")
        return ((try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)) ?? []).contains { $0.pathExtension == "nca" || $0.hasDirectoryPath }
    }
    var diagnosticURL: URL { Bundle.main.url(forResource: "first-light", withExtension: "nro", subdirectory: "Homebrew")! }
    var diagnostic: LibraryItem { saved.items.first(where: \.isDiagnostic)! }
    var sampleGame: LibraryItem { saved.items.first(where: { $0.bundledName == "orbit-pong" }) ?? diagnostic }
    var visibleItems: [LibraryItem] {
        saved.items.filter {
            (selectedSystem == nil || $0.system == selectedSystem) &&
            (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)) &&
            (filter != "Favorites" || $0.favorite) && (filter != "Recently played" || $0.lastPlayed != nil)
        }.sorted {
            if filter == "Recently played" { return ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            if ($0.bundledName == "orbit-pong") != ($1.bundledName == "orbit-pong") { return $0.bundledName == "orbit-pong" }
            return $0.title < $1.title
        }
    }

    init() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--data-dir"), args.indices.contains(i + 1) { dataRoot = URL(fileURLWithPath: args[i + 1]) }
        else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let current = support.appendingPathComponent("NEXARC", isDirectory: true)
            let legacy = support.appendingPathComponent("Helio", isDirectory: true)
            if !FileManager.default.fileExists(atPath: current.path), FileManager.default.fileExists(atPath: legacy.path) {
                do { try FileManager.default.moveItem(at: legacy, to: current) }
                catch { self.error = "NEXARC could not move your existing library yet: \(error.localizedDescription)" }
            }
            dataRoot = current
        }
        do {
            try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stateURL.path) {
                saved = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: stateURL))
            }
        } catch { self.error = "Could not read the saved library: \(error.localizedDescription)" }
        repairManagedPaths()
        // The path changes when the app moves; always repair only our bundled entry.
        if let i = saved.items.firstIndex(where: \.isDiagnostic) { saved.items[i].path = diagnosticURL.path }
        else { saved.items.insert(LibraryItem(title: "First Light", path: diagnosticURL.path, isDiagnostic: true), at: 0) }
        if let pong = Bundle.main.url(forResource:"orbit-pong",withExtension:"nro",subdirectory:"Homebrew") {
            if let i=saved.items.firstIndex(where:{$0.bundledName=="orbit-pong"}) { saved.items[i].path=pong.path }
            else { saved.items.insert(LibraryItem(title:"Orbit Pong",path:pong.path,bundledName:"orbit-pong"),at:0) }
        }
        for (name,title,ext,system) in [("orbit-catch","Orbit Catch","gb",GameSystem.gb),("color-signal","Color Signal","nes",GameSystem.nes),("2048-3ds","2048 · 3DS Homebrew","3dsx",GameSystem.n3ds)] {
            if let url=Bundle.main.url(forResource:name,withExtension:ext,subdirectory:"Homebrew") {
                if let i=saved.items.firstIndex(where:{$0.bundledName==name}) { saved.items[i].path=url.path }
                else { saved.items.append(LibraryItem(title:title,path:url.path,bundledName:name,systemID:system.rawValue)) }
            }
        }
        engine.onSkinChange = { [weak self] skin in
            guard let self, let system=self.engine.currentItem?.system else { return }
            if let item=self.engine.currentItem,let index=self.saved.items.firstIndex(where:{$0.id==item.id}),var override=self.saved.items[index].overrides,var display=override.display {display.skin=skin;override.display=display;self.saved.items[index].overrides=override;self.persist();return}
            var display=self.saved.displays?[system.rawValue] ?? DisplayProfile.defaultProfile(for:system)
            display.skin=skin
            if self.saved.displays == nil { self.saved.displays=[:] }
            self.saved.displays?[system.rawValue]=display
            self.persist()
        }
        engine.onPlayerAction = { [weak self] action,slot in self?.handlePlayerAction(action,slot:slot) }
        engine.onBeforeStop = { [weak self] in self?.protectResume(reason:"Before ending session") }
        engine.onFinish = { [weak self] record in
            guard let self else { return }
            self.discordPresence.clear()
            self.saved.sessions.insert(record, at: 0)
            if self.saved.sessions.count > 200 { self.saved.sessions.removeLast() }
            if let i = self.saved.items.firstIndex(where: { $0.id == record.itemID }) { self.saved.items[i].playSeconds += record.duration }
            self.persist()
            if record.verifiedDiagnostic { self.notify("First Light passed. ARM64 code executed successfully.") }
            else if !record.stoppedByUser && record.exitCode != 0 { self.error = "The emulation core exited with code \(record.exitCode). Open Sessions to review the log." }
            self.objectWillChange.send()
        }
        startLibraryControllerNavigation()
        refreshControllers()
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshControllers() } }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshControllers() } }
        persist()
        refreshCovers()
    }

    /// Earlier builds stored managed ROM, cover, cheat, and log paths under the
    /// Helio support folder. The data folder is migrated to NEXARC, so rebase
    /// only paths inside that old managed root when the corresponding file exists.
    private func repairManagedPaths() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacyRoot = support.appendingPathComponent("Helio", isDirectory: true).standardizedFileURL.path
        let prefix = legacyRoot.hasSuffix("/") ? legacyRoot : legacyRoot + "/"
        func rebased(_ path: String?) -> String? {
            guard let path, path.hasPrefix(prefix) else { return path }
            let relative = String(path.dropFirst(prefix.count))
            let moved = dataRoot.appendingPathComponent(relative).standardizedFileURL
            return FileManager.default.fileExists(atPath: moved.path) ? moved.path : path
        }
        for index in saved.items.indices {
            saved.items[index].path = rebased(saved.items[index].path) ?? saved.items[index].path
            saved.items[index].coverPath = rebased(saved.items[index].coverPath)
            saved.items[index].cheatPath = rebased(saved.items[index].cheatPath)
        }
        for index in saved.sessions.indices {
            saved.sessions[index].logPath = rebased(saved.sessions[index].logPath) ?? saved.sessions[index].logPath
        }
    }

    func persist() {
        do { let data = try JSONEncoder().encode(saved); try data.write(to: stateURL, options: .atomic) }
        catch { self.error = "Could not save the library: \(error.localizedDescription)" }
    }
    func notify(_ text: String) {
        toast = text
        Task { @MainActor in try? await Task.sleep(for: .seconds(5)); if toast == text { toast = nil } }
    }
    func refreshControllers() { controllerNames = GCController.controllers().map { $0.vendorName ?? "Controller" } }
    func importPrograms() {
        let panel = NSOpenPanel(); panel.title = selectedSystem.map { "Add \($0.shortName) games" } ?? "Add your games"; panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ImportRules.extensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK else { return }
        add(panel.urls)
    }
    func openSystem(_ system: GameSystem) { selectedSystem=system; search=""; filter="All programs"; section="Library" }
    func add(_ urls: [URL]) {
        var count=0
        for url in urls {
            do {
                try ImportRules.validate(url)
                let candidates=GameSystem.detect(url.path)
                let system: GameSystem
                if let selectedSystem, candidates.contains(selectedSystem) { system=selectedSystem }
                else if candidates.count == 1 { system=candidates[0] }
                else {
                    let alert=NSAlert(); alert.messageText="Which console is this game for?";alert.informativeText=url.lastPathComponent
                    let picker=NSPopUpButton(frame:NSRect(x:0,y:0,width:300,height:28)); picker.addItems(withTitles:candidates.map(\.name));alert.accessoryView=picker
                    alert.addButton(withTitle:"Import");alert.addButton(withTitle:"Cancel")
                    guard alert.runModal() == .alertFirstButtonReturn, candidates.indices.contains(picker.indexOfSelectedItem) else { continue };system=candidates[picker.indexOfSelectedItem]
                }
                guard !saved.items.contains(where: { $0.path == url.standardizedFileURL.path }) else { continue }
                var item=LibraryItem(title:url.deletingPathExtension().lastPathComponent,path:url.path,systemID:system.rawValue)
                // Keep large Switch files in place. Retro games are managed local copies.
                if system != .switchSystem {
                    let dir=RetroRuntime.gameRoot(item,dataRoot:dataRoot).appendingPathComponent("ROM")
                    try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
                    let target=dir.appendingPathComponent(url.lastPathComponent)
                    if ["cue","gdi"].contains(url.pathExtension.lowercased()) {
                        try copyDiscCompanions(url,to:dir)
                    }
                    try FileManager.default.copyItem(at:url,to:target);item.path=target.path
                }
                // A same-name sidecar image takes precedence over online matching.
                for ext in ["png","jpg","jpeg"] {
                    let sidecar=url.deletingPathExtension().appendingPathExtension(ext)
                    if FileManager.default.fileExists(atPath:sidecar.path){
                        let folder=dataRoot.appendingPathComponent("Covers");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                        let dest=folder.appendingPathComponent(item.id.uuidString+"."+ext);try FileManager.default.copyItem(at:sidecar,to:dest);item.coverPath=dest.path;break
                    }
                }
                saved.items.append(item);fetchCover(item);count += 1
            } catch { self.error=error.localizedDescription }
        }
        persist(); if count > 0 { notify("Added \(count) game\(count == 1 ? "" : "s") to your library.") }
    }
    private func copyDiscCompanions(_ descriptor: URL,to directory: URL) throws {
        let text=try String(contentsOf:descriptor,encoding:.utf8)
        let pattern=descriptor.pathExtension.lowercased() == "cue" ? #"(?im)^\s*FILE\s+"([^"]+)""# : #"(?m)^\s*\d+\s+\d+\s+\d+\s+\d+\s+(?:"([^"]+)"|(\S+))"#
        let regex=try NSRegularExpression(pattern:pattern)
        for match in regex.matches(in:text,range:NSRange(text.startIndex...,in:text)) {
            let group=match.range(at:1).location != NSNotFound ? 1:2
            guard let range=Range(match.range(at:group),in:text) else {continue}
            let name=String(text[range])
            guard !name.hasPrefix("/"), !name.split(separator:"/").contains(".."), !name.contains("\\") else { throw AppFailure.message("The disc descriptor refers to a file outside its folder.") }
            let source=descriptor.deletingLastPathComponent().appendingPathComponent(name), target=directory.appendingPathComponent(name)
            try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
            if !FileManager.default.fileExists(atPath:target.path) {try FileManager.default.copyItem(at:source,to:target)}
        }
    }
    func launch(_ item: LibraryItem, resume: Bool = false) {
        do {
            if let coreApplication, !coreApplication.isTerminated { throw AppFailure.message("Close core tools before starting a session.") }
            if item.system == .switchSystem && !item.isDiagnostic && ["nsp", "xci", "nca"].contains(URL(fileURLWithPath: item.path).pathExtension.lowercased()) && !hasKeys {
                section = "System"; throw AppFailure.message("Import your console keys in Settings before launching encrypted content.")
            }
            try protectResume(item,reason:"Before launching session")
            try engine.launch(item: item, root: coreRoot, logs: logs, preferences: saved.preferences, controllerArguments: item.isDiagnostic ? [] : controllerArguments(for:item), dataRoot:dataRoot, resume:resume, display:effectiveDisplay(item), keyboard:item.overrides?.keyboard ?? saved.keyboard ?? KeyboardMapping(), fastSpeed:item.overrides?.fastForwardSpeed ?? saved.fastForwardSpeed ?? 2)
            if saved.preferences.discordPresenceEnabled == true {
                discordPresence.start(clientID: saved.preferences.discordClientID ?? "", title: item.displayTitle, system: item.system.shortName, started: engine.started)
            }
            if item.isDiagnostic { section = "Sessions" }
            if let i = saved.items.firstIndex(where: { $0.id == item.id }) { saved.items[i].lastPlayed = Date() }
            persist()
        } catch { self.error = error.localizedDescription }
    }
    func favorite(_ item: LibraryItem) { if let i = saved.items.firstIndex(where: { $0.id == item.id }) { saved.items[i].favorite.toggle(); persist() } }
    func remove(_ item: LibraryItem) { guard !item.isBundled else { return }; saved.items.removeAll { $0.id == item.id }; persist() }
    func cover(_ item: LibraryItem) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.png, .jpeg, .heic]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let i = saved.items.firstIndex(where: { $0.id == item.id }) else { return }
        do {
            let folder = dataRoot.appendingPathComponent("Covers"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent(item.id.uuidString + "." + url.pathExtension)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.copyItem(at: url, to: target); saved.items[i].coverPath = target.path; persist()
        } catch { self.error = error.localizedDescription }
    }
    func importKeys() {
        let panel = NSOpenPanel(); panel.title = "Choose your prod.keys file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard text.count < 1_000_000, text.split(separator: "\n").contains(where: { $0.contains("=") && !$0.hasPrefix("#") }) else { throw AppFailure.message("This does not look like a keys file.") }
            let folder = coreRoot.appendingPathComponent("system"); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let target = folder.appendingPathComponent("prod.keys"); try Data(text.utf8).write(to: target, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            notify("Keys imported locally."); objectWillChange.send()
        } catch { self.error = error.localizedDescription }
    }
    func coreTools(firmware: Bool = false) {
        guard !engine.running else { error = "Stop the session before opening core settings."; return }
        if let coreApplication, !coreApplication.isTerminated {
            if firmware { error = "Close core tools before starting a firmware installation." }
            else { coreApplication.activate(options: [.activateAllWindows]) }
            return
        }
        var args = ["--root-data-dir", coreRoot.path, "--hide-updates"]
        if firmware {
            let panel = NSOpenPanel(); panel.title = "Choose your firmware ZIP"; panel.allowedContentTypes = [.zip]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            args += ["--install-firmware", url.path]
        }
        let config = NSWorkspace.OpenConfiguration(); config.arguments = args
        NSWorkspace.shared.openApplication(at: engine.executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent(), configuration: config) { app, failure in
            Task { @MainActor in self.coreApplication = app }
            if let failure { Task { @MainActor in self.error = failure.localizedDescription } }
        }
    }
}
