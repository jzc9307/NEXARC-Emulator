import SwiftUI

struct GameSettingsView:View {
    let item:LibraryItem
    @ObservedObject var model:AppModel
    @ViewState var expanded=false
    private var game:LibraryItem{model.saved.items.first{$0.id==item.id} ?? item}
    private var overrides:GameOverrides{game.overrides ?? GameOverrides()}
    private var baseDisplay:DisplayProfile{model.saved.displays?[game.system.rawValue] ?? DisplayProfile.defaultProfile(for:game.system)}
    private func displayBinding<T>(_ key:WritableKeyPath<DisplayProfile,T>)->Binding<T>{Binding(get:{(overrides.display ?? baseDisplay)[keyPath:key]},set:{value in model.updateOverrides(game){var d=$0.display ?? baseDisplay;d[keyPath:key]=value;if d.skin == .hardware && [GameSystem.nds,.n3ds].contains(game.system){d.layout = .stacked};$0.display=d}})}
    var body:some View {
        DisclosureGroup(isExpanded:$expanded){
            VStack(alignment:.leading,spacing:16){
                Text("Overrides apply to this game on its next launch. Turn a section off to follow the console defaults again.").font(.system(size:12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                Toggle("Custom display & skin",isOn:Binding(get:{overrides.display != nil},set:{enabled in model.updateOverrides(game){$0.display=enabled ? baseDisplay:nil}})).toggleStyle(.switch).controlSize(.small)
                if overrides.display != nil {
                    Picker("Skin",selection:displayBinding(\.skin)){ForEach(ConsoleSkin.allCases.filter{($0 != .hardware || HardwareSkinCatalog.asset(for:game.system) != nil) && ($0 != .custom || overrides.display?.customAsset != nil)}){Text($0.rawValue).tag($0)}}
                    if overrides.display?.skin == .custom{Picker("Artwork",selection:Binding(get:{overrides.display?.customAsset?.id ?? ""},set:{displayBinding(\.selectedCustomSkin).wrappedValue=$0})){ForEach(overrides.display?.customSkins ?? []){Text($0.name).tag($0.id)}}}
                    if [.nds,.n3ds].contains(game.system){Picker("Screen layout",selection:displayBinding(\.layout)){ForEach(ScreenLayout.allCases){Text($0.rawValue).tag($0)}}.disabled(overrides.display?.skin == .hardware || (overrides.display?.skin == .custom && overrides.display?.customAsset?.secondaryScreen != nil))}
                    Picker("Screen size",selection:displayBinding(\.sizing)){ForEach(["Fit","Native 1×","Native 2×","Native 3×"],id:\.self){Text($0).tag($0)}}
                    if game.system != .switchSystem{WindowSizePicker(profile:Binding(get:{overrides.display ?? baseDisplay},set:{value in model.updateOverrides(game){$0.display=value}}))}
                    Toggle("Launch in full screen",isOn:displayBinding(\.fullscreen)).toggleStyle(.switch).controlSize(.small)
                }
                Divider().overlay(Palette.line)
                HStack{Toggle("Custom fast-forward speed",isOn:Binding(get:{overrides.fastForwardSpeed != nil},set:{enabled in model.updateOverrides(game){$0.fastForwardSpeed=enabled ? model.saved.fastForwardSpeed ?? 2:nil}})).toggleStyle(.switch).controlSize(.small);Spacer();if overrides.fastForwardSpeed != nil{Picker("Speed",selection:Binding(get:{overrides.fastForwardSpeed ?? 2},set:{value in model.updateOverrides(game){$0.fastForwardSpeed=value}})){ForEach(2...5,id:\.self){Text("\($0)×").tag($0)}}.labelsHidden().frame(width:90)}}
                Toggle("Custom keyboard mapping",isOn:Binding(get:{overrides.keyboard != nil},set:{enabled in model.updateOverrides(game){$0.keyboard=enabled ? model.saved.keyboard ?? KeyboardMapping():nil}})).toggleStyle(.switch).controlSize(.small)
                if overrides.keyboard != nil {
                    LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10){ForEach(KeyboardMapping.actions,id:\.0){action,label in
                        HStack{Text(label).font(.system(size:11));Spacer();Picker(label,selection:Binding(get:{overrides.keyboard?.bindings[action] ?? "nul"},set:{key in model.updateOverrides(game){var mapping=$0.keyboard ?? KeyboardMapping();mapping.bindings[action]=key;$0.keyboard=mapping}})){ForEach(KeyboardMapping.keys,id:\.self){Text(KeyboardMapping.label($0)).tag($0)}}.labelsHidden().frame(width:125)}
                    }}
                    Text("This keyboard mapping applies to retro cores. Switch keyboard bindings remain in Core tools.").font(.system(size:11)).foregroundStyle(Palette.muted)
                }
                if game.system != .switchSystem {
                    Toggle("Custom gamepad layout",isOn:Binding(get:{overrides.gamepad != nil},set:{enabled in model.updateOverrides(game){$0.gamepad=enabled ? RetroPadMapping():nil}})).toggleStyle(.switch).controlSize(.small)
                    if overrides.gamepad != nil {
                        Text("Remap player one's logical gamepad buttons, including keyboard input. Sticks keep their normal mapping.").font(.system(size:11)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                        LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10){ForEach(0..<16,id:\.self){index in
                            VStack(alignment:.leading,spacing:4){Text(RetroPadMapping.labels[index]).font(.system(size:11));Picker("Source button",selection:Binding(get:{let buttons=overrides.gamepad?.buttons ?? [];return buttons.indices.contains(index) ? buttons[index]:index},set:{source in model.updateOverrides(game){var mapping=$0.gamepad ?? RetroPadMapping();if mapping.buttons.count != 16{mapping=RetroPadMapping()};mapping.buttons[index]=source;$0.gamepad=mapping}})){ForEach(0..<16,id:\.self){source in Text(RetroPadMapping.labels[source]).tag(source)}}.labelsHidden().frame(maxWidth:.infinity)}
                        }}
                    }
                }
                if game.system == .switchSystem {
                    Divider().overlay(Palette.line)
                    Text(overrides.controllers == nil ? "Switch controller profiles: following defaults":"Switch controller profiles: saved for this game").font(.system(size:12))
                    HStack{Button("Copy current controller profiles"){snapshotControllers()}.buttonStyle(Tactile());if overrides.controllers != nil{Button("Use defaults"){model.updateOverrides(game){$0.controllers=nil}}.buttonStyle(Tactile())}}
                }
                Button("Reset all game overrides"){if let i=model.saved.items.firstIndex(where:{$0.id==game.id}){model.saved.items[i].overrides=nil;model.persist()}}.buttonStyle(Tactile())
            }.font(.system(size:13)).padding(.top,12)
        }label:{Label("Per-game settings",systemImage:"slider.horizontal.3").font(.system(size:15,weight:.semibold))}
        .disabled(model.engine.running)
    }
    private func snapshotControllers(){
        do {
            let bindings=try model.controllers.profiles.filter{!$0.deviceID.isEmpty}.map{GameControllerBinding(player:$0.player,deviceID:$0.deviceID,profile:try JSONSerialization.data(withJSONObject:$0.coreJSON(),options:[.sortedKeys]))}
            guard !bindings.isEmpty else{model.error="Choose and save a connected controller in Controllers first.";return}
            model.updateOverrides(game){$0.controllers=bindings}
        }catch{model.error=error.localizedDescription}
    }
}
