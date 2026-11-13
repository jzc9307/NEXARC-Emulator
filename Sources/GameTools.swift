import SwiftUI
import UniformTypeIdentifiers

@MainActor extension AppModel {
    func files(_ item:LibraryItem,states:Bool=false)->[URL] {
        guard item.system != .switchSystem else {return []}
        let root=states ? RetroRuntime.states(item,dataRoot:dataRoot):RetroRuntime.saves(item,dataRoot:dataRoot)
        let enumerator=FileManager.default.enumerator(at:root,includingPropertiesForKeys:[.isRegularFileKey,.contentModificationDateKey],options:.skipsHiddenFiles)
        return (enumerator?.allObjects as? [URL] ?? []).filter{(try? $0.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile)==true}.sorted{((try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast)}
    }
    func hasResume(_ item:LibraryItem)->Bool {files(item,states:true).contains{$0.lastPathComponent.hasSuffix(".auto")}}
    func openSystemFiles() {let url=dataRoot.appendingPathComponent("System Files");try? FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);NSWorkspace.shared.open(url)}
    func openSaves(_ item:LibraryItem) {
        let url=item.system == .switchSystem ? coreRoot.appendingPathComponent("bis/user/save"):RetroRuntime.gameRoot(item,dataRoot:dataRoot)
        try? FileManager.default.createDirectory(at:url,withIntermediateDirectories:true);NSWorkspace.shared.open(url)
    }
    func quickSave() {if let item=engine.currentItem{saveSlot(item,slot:0)}}
    func runtimeCommand(_ command:String) {do{try engine.send(command)}catch{self.error=error.localizedDescription}}
    func importCheats(_ item:LibraryItem) {
        let panel=NSOpenPanel();panel.title="Import a RetroArch cheat file";panel.allowedContentTypes=[UTType(filenameExtension:"cht") ?? .plainText]
        guard panel.runModal() == .OK,let url=panel.url else{return}
        do {
            let data=try Data(contentsOf:url);guard data.count<1_000_000,let text=String(data:data,encoding:.utf8),text.contains("cheats") else {throw AppFailure.message("Choose a text-format RetroArch .cht file.")}
            try storeCheats(item,data:data);notify("Cheat file imported. Applies on the next launch.")
        }catch{self.error=error.localizedDescription}
    }
    func writeCheat(_ item:LibraryItem,code:String) {
        guard !code.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {return}
        let text="cheats = 1\ncheat0_desc = \"NEXARC custom code\"\ncheat0_enable = true\ncheat0_code = \(RetroRuntime.quote(code.trimmingCharacters(in:.whitespacesAndNewlines)))\n"
        do{try storeCheats(item,data:Data(text.utf8));notify("Code saved. Applies on the next launch.")}catch{self.error=error.localizedDescription}
    }
    private func storeCheats(_ item:LibraryItem,data:Data)throws {
        guard item.system.supportsCheats,let i=saved.items.firstIndex(where:{$0.id==item.id}) else {throw AppFailure.message("This core does not support these cheat files.")}
        let root=RetroRuntime.gameRoot(item,dataRoot:dataRoot);try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let target=root.appendingPathComponent("user.cht");try data.write(to:target,options:.atomic);saved.items[i].cheatPath=target.path;persist()
    }
    func clearCheats(_ item:LibraryItem) {
        guard let i=saved.items.firstIndex(where:{$0.id==item.id}) else{return}
        saved.items[i].cheatPath=nil
        // Remove only generated cheat copies, not the user's imported source file.
        let dir=RetroRuntime.gameRoot(item,dataRoot:dataRoot).appendingPathComponent("Cheats")
        try? FileManager.default.removeItem(at:dir);persist();notify("Cheats disabled for the next launch.")
    }
    func applyPatch(_ item:LibraryItem) {
        guard item.system.supportsPatches else{return}
        let panel=NSOpenPanel();panel.title="Apply IPS or BPS patch to a copy";panel.allowedContentTypes=["ips","bps"].compactMap{UTType(filenameExtension:$0)}
        guard panel.runModal() == .OK,let patch=panel.url else{return}
        do {
            let output=try ROMPatch.apply(source:Data(contentsOf:URL(fileURLWithPath:item.path)),patch:Data(contentsOf:patch))
            var result=LibraryItem(title:"\(item.title) · \(patch.deletingPathExtension().lastPathComponent)",path:"",systemID:item.system.rawValue,patchedFrom:item.id.uuidString)
            let dir=RetroRuntime.gameRoot(result,dataRoot:dataRoot).appendingPathComponent("ROM");try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            let target=dir.appendingPathComponent("\(patch.deletingPathExtension().lastPathComponent).\(item.format.lowercased())");try output.write(to:target,options:.atomic);result.path=target.path
            saved.items.append(result);persist();inspectedItem=nil;openSystem(item.system);notify("Patched copy added. Your original game and saves are unchanged.")
        }catch{self.error=error.localizedDescription}
    }
    func exportSaves(_ item:LibraryItem) {
        guard !engine.running else{error="Stop the session before exporting a consistent save backup.";return}
        let source=item.system == .switchSystem ? coreRoot.appendingPathComponent("bis/user/save"):RetroRuntime.gameRoot(item,dataRoot:dataRoot)
        guard FileManager.default.fileExists(atPath:source.path) else {notify("No saves yet. Play and save first.");return}
        let panel=NSSavePanel();panel.title="Export save backup";panel.nameFieldStringValue="\(item.title)-saves.zip";panel.allowedContentTypes=[.zip]
        guard panel.runModal() == .OK,let url=panel.url else{return}
        do {
            let staging=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:staging,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:staging)}
            if item.system == .switchSystem {try FileManager.default.copyItem(at:source,to:staging.appendingPathComponent("Switch saves"))}
            else {for name in ["Saves","States","Save Slots","Recovery Backups"] {let f=source.appendingPathComponent(name);if FileManager.default.fileExists(atPath:f.path){try FileManager.default.copyItem(at:f,to:staging.appendingPathComponent(name))}}}
            let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/bin/ditto");p.arguments=["-c","-k","--keepParent",staging.path,url.path];try p.run();p.waitUntilExit();guard p.terminationStatus==0 else{throw AppFailure.message("Could not create the save backup.")};notify("Save backup exported.")
        }catch{self.error=error.localizedDescription}
    }
}

struct GameInspector:View {
    let item:LibraryItem
    @ObservedObject var model:AppModel
    @ObservedObject var engine:EngineBridge
    private func dismiss() {model.inspectedItem=nil}
    @ViewState private var code=""
    private var game:LibraryItem {model.saved.items.first{$0.id==item.id} ?? item}
    private var accent:Color {Color(hex:game.system.color)}
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {Tag(text:game.system.name.uppercased(),color:accent);Spacer();Button("Done"){dismiss()}.buttonStyle(Tactile()).keyboardShortcut(.cancelAction)}
            Text(game.displayTitle).font(.system(size: 31,weight:.light)).tracking(-1).lineLimit(2)
            HStack(spacing:10) {
                Button{dismiss();model.launch(game)}label:{Label("Play from start",systemImage:"play.fill")}.buttonStyle(Tactile(primary:true)).disabled(engine.running)
                if model.hasResume(game){Button("Resume"){dismiss();model.launch(game,resume:true)}.buttonStyle(Tactile()).disabled(engine.running)}
                Button("Choose cover…"){model.cover(game)}.buttonStyle(Tactile())
            }
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    GlassPanel(padding:18){VisualSaveSlots(item:game,model:model,engine:engine)}
                    GlassPanel(padding:18){RecoveryBackupsView(item:game,model:model)}
                    GlassPanel(padding:18){GameSettingsView(item:game,model:model)}
                    GlassPanel(padding:18) {
                        VStack(alignment:.leading,spacing:12) {
                            Label("Your progress",systemImage:"clock.arrow.circlepath").font(.system(size: 15,weight:.medium))
                            Text(game.system.supportsStates ? "In-game saves persist automatically. A resume snapshot is created when you exit normally. F5 saves the selected slot; F8 loads it. Recovery backups protect prior snapshots. Save states depend on the core version." : "Switch progress uses the game's own save system. Quick states are not supported.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                            Text("\(model.files(game).count) save files · \(model.files(game,states:true).count) state files · \(Int(game.playSeconds/60)) minutes played").font(.system(size: 12)).foregroundStyle(accent)
                            HStack {Button("Open save folder"){model.openSaves(game)}.buttonStyle(Tactile());Button("Export backup…"){model.exportSaves(game)}.buttonStyle(Tactile()).disabled(engine.running)}
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                    GlassPanel(padding:18) {
                        VStack(alignment:.leading,spacing:12) {
                            Label("Patches & ROM hacks",systemImage:"wrench.and.screwdriver").font(.system(size: 15,weight:.medium))
                            Text(game.system.supportsPatches ? "Apply an IPS or BPS patch to create a separate library entry. BPS checks the original ROM's checksum; IPS requires you to select the right version." : "You can import an already patched game in a supported format. This console does not use NEXARC's IPS/BPS patch tool.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                            if game.system.supportsPatches {Button("Apply patch to a copy…"){model.applyPatch(game)}.buttonStyle(Tactile()).disabled(engine.running)}
                            if game.patchedFrom != nil {Tag(text:"PATCHED COPY",color:accent)}
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                    GlassPanel(padding:18) {
                        VStack(alignment:.leading,spacing:12) {
                            Label("Cheat codes",systemImage:"sparkles").font(.system(size: 15,weight:.medium))
                            if game.system.supportsCheats {
                                Text("Use codes for this game, region and core. Imported .cht files retain their enabled flags. Changes apply on the next launch.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                                HStack {Button("Import .cht file…"){model.importCheats(game)}.buttonStyle(Tactile());if game.cheatPath != nil {Tag(text:"FILE ATTACHED",color:Palette.mint);Button("Disable"){model.clearCheats(game)}.buttonStyle(.plain).font(.system(size: 13))}}
                                HStack {TextField("Game Genie / GameShark code",text:$code).textFieldStyle(.roundedBorder);Button("Save code"){model.writeCheat(game,code:code);code=""}.buttonStyle(Tactile()).disabled(code.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}
                            } else {Text("This core does not support NEXARC's RetroArch cheat-code workflow. Use compatible engine-specific tools where available.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)}
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                    Text(game.path).font(.system(size: 11,design:.monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled)
                }
            }
        }.padding(26).frame(maxWidth:.infinity,maxHeight:.infinity).background(Palette.background).preferredColorScheme(.dark)
    }
}

struct SavesView:View {
    @ObservedObject var model:AppModel
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:23) {
                Tag(text:"PICK UP WHERE YOU LEFT OFF",color:Palette.mint)
                Text("Good stories deserve\na second session.").font(.system(size: 38,weight:.light)).tracking(-1.3)
                Text("In-game saves and resume snapshots stay on your Mac. Use Export backup before changing cores.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                ForEach(model.saved.items.filter{!$0.isDiagnostic && ($0.lastPlayed != nil || !model.files($0).isEmpty || !model.files($0,states:true).isEmpty)}) {item in
                    GlassPanel(padding:18){
                        VStack(alignment:.leading,spacing:16){
                            HStack{Image(systemName:"externaldrive").foregroundStyle(Color(hex:item.system.color));VStack(alignment:.leading,spacing:4){Text(item.displayTitle).font(.system(size:16,weight:.semibold));Text(item.system.shortName).font(.system(size:12)).foregroundStyle(Palette.muted)};Spacer();if model.hasResume(item){Button("Resume"){model.launch(item,resume:true)}.buttonStyle(Tactile(primary:true)).disabled(model.engine.running)};Button("Manage"){model.inspectedItem=item}.buttonStyle(Tactile())}
                            DisclosureGroup("Visual save slots"){VisualSaveSlots(item:item,model:model,engine:model.engine).padding(.top,14)}
                            if item.system.supportsStates{RecoveryBackupsView(item:item,model:model)}
                        }
                    }
                }
                if !model.saved.items.contains(where:{$0.lastPlayed != nil}) {ContentUnavailableView("Your progress will appear here",systemImage:"clock.arrow.circlepath",description:Text("Play a game and use its save menu, or exit normally to create a resume snapshot."))}
            }.padding(28)
        }
    }
}
