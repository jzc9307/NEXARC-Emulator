import AppKit

@MainActor extension AppModel {
    func progress(_ item:LibraryItem)->ProgressStore{ProgressStore(root:RetroRuntime.gameRoot(item,dataRoot:dataRoot))}
    func canonicalState(_ item:LibraryItem)->URL{RetroRuntime.states(item,dataRoot:dataRoot).appendingPathComponent(URL(fileURLWithPath:item.path).deletingPathExtension().lastPathComponent+".state")}
    func effectiveDisplay(_ item:LibraryItem)->DisplayProfile{var p=item.overrides?.display ?? saved.displays?[item.system.rawValue] ?? DisplayProfile.defaultProfile(for:item.system);if p.skin == .custom && p.customAsset?.secondaryScreen != nil{p.layout = .stacked;p.gap=0};if p.skin == .hardware && [GameSystem.nds,.n3ds].contains(item.system){p.layout = .stacked};return p}
    func fingerprint(_ item:LibraryItem)throws->String{try ProgressStore.fingerprint(engine.retro.core(item.system))}
    func protectResume(_ item:LibraryItem,reason:String)throws {
        guard item.system.supportsStates else{return}
        let file=canonicalState(item).appendingPathExtension("auto")
        guard FileManager.default.fileExists(atPath:file.path) else{return}
        try progress(item).backup(file,reason:reason,core:item.system.core ?? "",fingerprint:fingerprint(item))
    }
    func protectResume(reason:String){if let item=engine.currentItem{do{try protectResume(item,reason:reason)}catch{self.error="Could not protect the previous resume snapshot: \(error.localizedDescription)"}}}
    private func captureState(_ item:LibraryItem) async throws->URL {
        guard engine.running,engine.currentItem?.id==item.id,item.system.supportsStates else{throw AppFailure.message("Start this game before creating a save slot.")}
        let file=canonicalState(item)
        let before=(try? FileManager.default.attributesOfItem(atPath:file.path)[.modificationDate] as? Date) ?? .distantPast
        try engine.send("SAVE_STATE")
        var stableSize=0,stable=0
        for _ in 0..<80 {
            try await Task.sleep(for:.milliseconds(100))
            guard engine.running,engine.currentItem?.id==item.id else{throw AppFailure.message("The session ended before the save completed.")}
            if let values=try? FileManager.default.attributesOfItem(atPath:file.path),let date=values[.modificationDate] as? Date,date>before,let size=(values[.size] as? NSNumber)?.intValue,size>0 {
                stable = size==stableSize ? stable+1:0;stableSize=size
                if stable>=4{return file}
            }
        }
        throw AppFailure.message("The core did not finish writing a save state. Your existing slots have been kept.")
    }
    func saveSlot(_ item:LibraryItem,slot:Int,exitAfter:Bool=false) {
        guard saveOperation==nil else{return};saveOperation="Saving slot \(slot+1)…"
        Task{@MainActor in
            defer{self.saveOperation=nil;self.objectWillChange.send()}
            do {
                let hash=try fingerprint(item),store=progress(item)
                try store.backup(canonicalState(item),reason:"Before quick-state write",core:item.system.core ?? "",fingerprint:hash)
                let file=try await captureState(item)
                try store.store(file,slot:slot,title:item.displayTitle,core:item.system.core ?? "",fingerprint:hash)
                engine.reportPlayerAction("Slot \(slot+1) saved.",success:true)
                notify("Slot \(slot+1) saved.")
                if exitAfter{engine.stop()}
            }catch{engine.reportPlayerAction(error.localizedDescription,success:false);self.error=error.localizedDescription}
        }
    }
    func loadSlot(_ item:LibraryItem,slot:Int) {
        guard saveOperation==nil else{return};saveOperation="Preparing slot \(slot+1)…"
        Task{@MainActor in
            defer{self.saveOperation=nil;self.objectWillChange.send()}
            do {
                guard !engine.running || engine.currentItem?.id==item.id else{throw AppFailure.message("End the current game before loading another game's snapshot.")}
                let store=progress(item),hash=try fingerprint(item),source=try store.validate(slot:slot,fingerprint:hash)
                if engine.running {
                    // A load always has an escape route back to the current live state.
                    let current=try await captureState(item)
                    try store.backup(current,reason:"Before loading slot \(slot+1)",core:item.system.core ?? "",fingerprint:hash)
                    try ProgressStore.copyAtomically(source,to:canonicalState(item))
                    try engine.send("LOAD_STATE")
                    engine.reportPlayerAction("Slot \(slot+1) load requested. Resume when ready.",success:true)
                    notify("Load requested for slot \(slot+1).")
                }else{
                    try protectResume(item,reason:"Before loading slot \(slot+1)")
                    try ProgressStore.copyAtomically(source,to:canonicalState(item).appendingPathExtension("auto"))
                    launch(item,resume:true)
                }
            }catch{engine.reportPlayerAction(error.localizedDescription,success:false);self.error=error.localizedDescription}
        }
    }
    func restoreBackup(_ item:LibraryItem,backup:SaveBackupInfo) {
        guard !engine.running,saveOperation==nil else{error="End the session before restoring a recovery snapshot.";return}
        do {
            let hash=try fingerprint(item);guard backup.fingerprint==hash else{throw AppFailure.message("This backup belongs to a different core build. Use the game's in-game save or a matching core.")}
            let source=progress(item).backupFile(backup)
            // Stage the chosen backup first: pruning the rolling history cannot remove it.
            let bytes=try Data(contentsOf:source)
            guard !bytes.isEmpty,bytes.count==backup.bytes,backup.checksum.map({ProgressStore.checksum(bytes)==$0}) ?? true else{throw AppFailure.message("This recovery snapshot is incomplete or damaged.")}
            let image=try? Data(contentsOf:source.appendingPathExtension("png"))
            try protectResume(item,reason:"Before restoring recovery backup")
            let target=canonicalState(item).appendingPathExtension("auto")
            try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
            try bytes.write(to:target,options:.atomic)
            if let image{try image.write(to:target.appendingPathExtension("png"),options:.atomic)}else{try? FileManager.default.removeItem(at:target.appendingPathExtension("png"))}
            notify("Recovery snapshot restored. Use Resume to open it.");objectWillChange.send()
        }catch{self.error=error.localizedDescription}
    }
    func handlePlayerAction(_ action:String,slot:Int) {
        guard let item=engine.currentItem else{return}
        guard saveOperation==nil else{engine.reportPlayerAction("Another save operation is still in progress.",success:false);return}
        switch action {
        case "save":saveSlot(item,slot:slot)
        case "load":loadSlot(item,slot:slot)
        case "saveExit":saveSlot(item,slot:slot,exitAfter:true)
        case "recovery":recoveryOpen=true;NSApp.activate(ignoringOtherApps:true)
        default:engine.reportPlayerAction("Unknown session action.",success:false)
        }
    }
    func restartFromInGameSave() {
        guard let item=engine.currentItem,saveOperation==nil else{return}
        saveOperation="Restarting game…"
        Task{@MainActor in
            defer{self.saveOperation=nil}
            engine.stop()
            for _ in 0..<190{if !engine.running{break};try? await Task.sleep(for:.milliseconds(100))}
            guard !engine.running else{self.error="The core has not stopped yet. Your saved files are kept.";return}
            recoveryOpen=false
            launch(saved.items.first{$0.id==item.id} ?? item,resume:false)
        }
    }
    func exportDiagnostics() {
        let panel=NSSavePanel();panel.allowedContentTypes=[.plainText];panel.nameFieldStringValue="NEXARC-diagnostics.txt"
        guard panel.runModal() == .OK,let url=panel.url else{return}
        let text=diagnosticReport()
        do{try text.write(to:url,atomically:true,encoding:.utf8);notify("Diagnostic report exported.")}catch{self.error=error.localizedDescription}
    }
    func diagnosticReport()->String {
        let log=engine.output.split(separator:"\n").suffix(120).joined(separator:"\n").replacingOccurrences(of:FileManager.default.homeDirectoryForCurrentUser.path,with:"~")
        return "NEXARC diagnostics\n\(Date())\nmacOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\nGame: \(engine.currentTitle)\nSystem: \(engine.currentItem?.system.shortName ?? "None")\nStatus: \(engine.health)\nEmulated frames: \(engine.emulatedFrames)\nVideo callbacks: \(engine.videoFrames)\nPresented software frames: \(engine.presentedFrames)\nDisplay attached: \(engine.rendererAttached)\n\nRecent runtime log\n\(log)\n"
    }
    func controllerArguments(for item:LibraryItem)throws->[String] {
        guard let bindings=item.overrides?.controllers else{return controllers.launchArguments}
        let dir=coreRoot.appendingPathComponent("profiles/controller");try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        return try bindings.filter{(1...4).contains($0.player) && !$0.deviceID.isEmpty}.flatMap {binding in
            let name="NEXARC-\(item.id.uuidString)-Player\(binding.player)"
            try binding.profile.write(to:dir.appendingPathComponent(name+".json"),options:.atomic)
            return ["--input-id-\(binding.player)",binding.deviceID,"--input-profile-\(binding.player)",name]
        }
    }
    func updateOverrides(_ item:LibraryItem,_ edit:(inout GameOverrides)->Void){guard let i=saved.items.firstIndex(where:{$0.id==item.id}) else{return};var value=saved.items[i].overrides ?? GameOverrides();edit(&value);saved.items[i].overrides=value;persist()}
    func setSessionFastTarget(_ value:Int){if let item=engine.currentItem,item.overrides?.fastForwardSpeed != nil{updateOverrides(item){$0.fastForwardSpeed=value}}else{saved.fastForwardSpeed=value;persist()};engine.setFastTarget(value)}
}
