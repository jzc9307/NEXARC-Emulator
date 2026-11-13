import SwiftUI

struct VisualSaveSlots:View {
    let item:LibraryItem
    @ObservedObject var model:AppModel
    @ObservedObject var engine:EngineBridge
    private var store:ProgressStore{model.progress(item)}
    private var active:Bool{engine.running && engine.currentItem?.id==item.id}
    var body:some View {
        VStack(alignment:.leading,spacing:14){
            HStack{Label("Save slots",systemImage:"square.grid.3x2").font(.system(size:16,weight:.semibold));Spacer();if let work=model.saveOperation{ProgressView().controlSize(.small);Text(work).font(.system(size:11)).foregroundStyle(Palette.mint)}}
            if item.system.supportsStates {
                LazyVGrid(columns:[GridItem(.adaptive(minimum:160),spacing:12)],spacing:12){ForEach(0..<ProgressStore.slotCount,id:\.self){slot in slotCard(slot)}}
                Text("Creating a slot requires this game to be running. Loads preserve a recovery snapshot first. Snapshots require the same core build.").font(.system(size:12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                if model.controllerNavigationActive{Text("← / → · Select slot    A / Cross · Load    X / Square · Play    B / Circle · Back").font(.system(size:11)).foregroundStyle(Palette.mint)}
            }else{Text("Switch uses its in-game save system. Save-state slots are unavailable for this core.").font(.system(size:13)).foregroundStyle(Palette.muted)}
        }
    }
    private func slotCard(_ slot:Int)->some View {
        let info=store.info(slot)
        return VStack(alignment:.leading,spacing:9){
            ZStack{
                if let image=NSImage(contentsOf:store.thumbnail(slot)){Image(nsImage:image).resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity)}
                else{VStack(spacing:6){Image(systemName:info == nil ? "plus.rectangle":"photo").font(.system(size:22,weight:.light));Text(info == nil ? "Empty slot":"Snapshot saved").font(.system(size:11))}.foregroundStyle(Palette.muted)}
            }.frame(height:104).frame(maxWidth:.infinity).background(.black.opacity(0.24),in:RoundedRectangle(cornerRadius:9)).clipped()
            HStack{Text("Slot \(slot+1)").font(.system(size:13,weight:.semibold));Spacer();if slot==0{Text("QUICK").font(.system(size:8,weight:.bold)).foregroundStyle(Palette.mint)}}
            Text(info.map{$0.date.formatted(date:.abbreviated,time:.shortened)} ?? "Ready for a new memory").font(.system(size:10)).foregroundStyle(Palette.muted).lineLimit(1)
            HStack(spacing:8){Button("Save"){model.saveSlot(item,slot:slot)}.buttonStyle(Tactile()).disabled(!active || model.saveOperation != nil);Button("Load"){model.inspectedItem=nil;model.loadSlot(item,slot:slot)}.buttonStyle(Tactile(primary:info != nil)).disabled(info == nil || model.saveOperation != nil || (engine.running && !active))}
        }.padding(11).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).strokeBorder(model.controllerNavigationActive && model.controllerDetailSlot==slot ? Palette.mint:Palette.line,lineWidth:model.controllerNavigationActive && model.controllerDetailSlot==slot ? 2:1))
    }
}

struct RecoveryBackupsView:View {
    let item:LibraryItem
    @ObservedObject var model:AppModel
    var body:some View {
        DisclosureGroup{
            let records=model.progress(item).history()
            if records.isEmpty{Text("Recovery copies appear before save replacement and resume changes.").font(.system(size:12)).foregroundStyle(Palette.muted).padding(.top,10)}
            ForEach(records){backup in
                HStack(spacing:12){Image(systemName:"clock.arrow.circlepath").foregroundStyle(Palette.mint);VStack(alignment:.leading,spacing:4){Text(backup.reason).font(.system(size:12,weight:.medium));Text(backup.date.formatted(date:.abbreviated,time:.shortened)).font(.system(size:11)).foregroundStyle(Palette.muted)};Spacer();Button("Restore"){model.restoreBackup(item,backup:backup)}.buttonStyle(Tactile()).disabled(model.engine.running || model.saveOperation != nil)}.padding(.vertical,8)
            }
        }label:{Label("Recovery backups · \(model.progress(item).history().count) / \(ProgressStore.backupLimit)",systemImage:"shield.lefthalf.filled").font(.system(size:13,weight:.medium))}
    }
}

struct RecoveryView:View {
    @ObservedObject var model:AppModel
    @ObservedObject var engine:EngineBridge
    var body:some View {
        VStack(alignment:.leading,spacing:22){
            HStack{Label("Session recovery",systemImage:"lifepreserver").font(.system(size:21,weight:.semibold));Spacer();Button{model.recoveryOpen=false}label:{Image(systemName:"xmark").frame(width:30,height:30)}.buttonStyle(SoftPress())}
            Text(engine.currentTitle).font(.system(size:16,weight:.medium)).lineLimit(2)
            GlassPanel(padding:16){VStack(alignment:.leading,spacing:11){HStack{Circle().fill(engine.health=="Running" || engine.health=="Paused" ? Palette.mint:Palette.coral).frame(width:7,height:7);Text(engine.health).font(.system(size:14,weight:.semibold));Spacer()};HStack{metric("Emulated frames",String(engine.emulatedFrames));Spacer();metric("Presented frames",(engine.currentItem.map{[GameSystem.nds,.n3ds].contains($0.system)} ?? false) ? String(engine.presentedFrames):"Native");Spacer();metric("Display",engine.isRetro ? (engine.rendererAttached ? "Attached":"Unavailable"):"Core window")};Text("Frame progress and display attachment help diagnose a stall. An intentionally dark scene is not automatically treated as a failure.").font(.system(size:12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)}}
            VStack(alignment:.leading,spacing:12){
                Button{engine.refreshDisplay()}label:{Label("Refresh game display",systemImage:"display.trianglebadge.exclamationmark").frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(Tactile(primary:true)).disabled(!engine.running || !engine.isRetro)
                Text("Reconnects the display view while keeping the running game.").font(.system(size:12)).foregroundStyle(Palette.muted)
                Divider().overlay(Palette.line)
                Button{model.restartFromInGameSave()}label:{Label("Restart from in-game save",systemImage:"arrow.clockwise").frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(Tactile()).disabled(!engine.running || model.saveOperation != nil)
                Text("Returns to the game's title screen and skips the resume snapshot. Unsaved play may be lost; the previous resume file is backed up first.").font(.system(size:12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
            }
            if let work=model.saveOperation{HStack{ProgressView().controlSize(.small);Text(work).font(.system(size:12)).foregroundStyle(Palette.mint)}}
            HStack{Button("Export diagnostic report…"){model.exportDiagnostics()}.buttonStyle(Tactile());Spacer();Button("Return to game"){model.recoveryOpen=false;engine.resumeGame()}.buttonStyle(Tactile()).disabled(!engine.running)}
        }.padding(26).frame(width:570).background(Palette.surface,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).strokeBorder(Palette.line))
    }
    private func metric(_ title:String,_ value:String)->some View{VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:10)).foregroundStyle(Palette.muted);Text(value).font(.system(size:13,weight:.medium,design:.monospaced))}}
}
