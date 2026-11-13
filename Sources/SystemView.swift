import SwiftUI

struct SystemView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: EngineBridge
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("The engine room.").font(.system(size: 31, weight: .light)).tracking(-1)
                    Text("Set up once. Spend the rest of your time playing.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                }
                GlassPanel {
                    VStack(alignment:.leading,spacing:16) {
                        HStack {panelHeading("Console engines",icon:"cpu");Spacer();Tag(text:"APPLE SILICON",color:Palette.mint)}
                        Text("NEXARC combines open-source emulators behind your library. Compatibility varies by game; a bundled core is not a guarantee that every title runs.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        LazyVGrid(columns:[GridItem(.adaptive(minimum:180),spacing:15)],alignment:.leading,spacing:15) {
                            ForEach(GameSystem.allCases) {system in
                                HStack(spacing:9) {Circle().fill(Color(hex:system.color)).frame(width:5,height:5);VStack(alignment:.leading,spacing:4){Text(system.shortName).font(.system(size: 12,weight:.medium));Text(system.engineLabel).font(.system(size: 10)).foregroundStyle(Palette.muted)};Spacer();Image(systemName:(system == .switchSystem ? engine.available:engine.retro.available(system)) ? "checkmark.circle":"circle.dashed").foregroundStyle(Palette.muted).font(.system(size: 12))}
                            }
                        }
                        HStack {Button("Open BIOS / system files"){model.openSystemFiles()}.buttonStyle(Tactile());Spacer();Text("Esc session menu · F5 quick save · F8 load").font(.system(size: 12)).foregroundStyle(Palette.muted)}
                    }
                }
                DisplaySettingsView(model:model,compact:geometry.size.width<900)
                (geometry.size.width>1120 ? AnyLayout(HStackLayout(alignment:.top,spacing:18)):AnyLayout(VStackLayout(alignment:.leading,spacing:18))) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 20) {
                            panelHeading("Switch setup", icon: "shippingbox")
                            fileRow("Emulation core", subtitle: "Ryujinx-derived · ARM64 · Built from source", ready: engine.available)
                            Divider().overlay(Palette.line)
                            fileRow("Console keys", subtitle: model.hasKeys ? "Imported locally · contents kept private" : "Required for encrypted game content", ready: model.hasKeys)
                            Button("Import keys…") { model.importKeys() }.buttonStyle(Tactile()).disabled(engine.running)
                            Divider().overlay(Palette.line)
                            fileRow("System firmware", subtitle: model.firmwarePresent ? "Content found · verify version in core tools" : "Add your console's firmware when needed", ready: model.firmwarePresent)
                            Button("Install firmware…") { model.coreTools(firmware: true) }.buttonStyle(Tactile()).disabled(engine.running || !model.hasKeys)
                            Text("The bundled homebrew works without these console files.").font(.system(size: 12)).foregroundStyle(Palette.mint)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(width:panelWidth(geometry.size.width))
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 21) {
                            panelHeading("Playback preferences", icon: "sparkles")
                            setting("Hold Tab to fast-forward",description:"Release for 1×. Shift + Tab uses 5×. Actual speed depends on the game.") {
                                Picker("Fast-forward speed",selection:Binding(get:{model.saved.fastForwardSpeed ?? 2},set:{model.saved.fastForwardSpeed=$0;model.persist();if engine.running{engine.setFastTarget($0)}})){ForEach(2...5,id:\.self){Text("\($0)×").tag($0)}}.labelsHidden().frame(width:120)
                            }
                            setting("Resolution", description: "Start at 1× for the most headroom.") {
                                Picker("Resolution", selection: $model.saved.preferences.resolution) { Text("1× Native").tag(1); Text("2×").tag(2); Text("3×").tag(3) }.labelsHidden().frame(width: 120)
                            }
                            setting("Docked mode", description: "Uses the console's TV-mode profile.") { Toggle("Docked mode", isOn: $model.saved.preferences.docked).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                            setting("Switch full-screen launch", description: "Open games directly in full screen.") { Toggle("Full-screen launch", isOn: $model.saved.preferences.fullscreen).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                            setting("Apple Hypervisor", description: "Run guest CPU code using Apple's virtualization APIs.") { Toggle("Apple Hypervisor", isOn: $model.saved.preferences.hypervisor).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                            VStack(alignment: .leading, spacing: 8) { HStack { Text("Volume").font(.system(size: 13, weight: .medium)); Spacer(); Text("\(Int(model.saved.preferences.volume*100))%").font(.system(size: 12)).foregroundStyle(Palette.muted) }; Slider(value: $model.saved.preferences.volume, in: 0...1).tint(Palette.mint).accessibilityLabel("Game volume") }
                            Toggle("Show cinematic intro", isOn: $model.saved.preferences.showIntro).font(.system(size: 13)).toggleStyle(.switch).controlSize(.small)
                            Text("Changes apply to the next session. Resolution, docked mode and hypervisor apply to Switch.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(width:panelWidth(geometry.size.width))
                }
                GlassPanel {
                    VStack(alignment:.leading,spacing:14) {
                        HStack { panelHeading("Discord Rich Presence", icon:"gamecontroller.fill"); Spacer(); Toggle("Show what I’m playing", isOn:Binding(get:{model.saved.preferences.discordPresenceEnabled == true},set:{model.saved.preferences.discordPresenceEnabled=$0})).labelsHidden().help("Show what I’m playing").toggleStyle(.switch).controlSize(.small) }
                        Text("Show NEXARC and your current game on your Discord profile while you play.").font(.system(size:12)).foregroundStyle(Palette.muted)
                        HStack(spacing:12) {
                            TextField("Discord Application ID",text:Binding(get:{model.saved.preferences.discordClientID ?? ""},set:{model.saved.preferences.discordClientID=$0.trimmingCharacters(in:.whitespacesAndNewlines)})).textFieldStyle(.roundedBorder).disabled(model.saved.preferences.discordPresenceEnabled != true)
                            Link("Create app ↗",destination:URL(string:"https://discord.com/developers/applications")!).font(.system(size:12,weight:.medium)).foregroundStyle(Palette.mint)
                        }
                        Text("Create an app in Discord Developer Portal, copy its Application ID, and paste it here. Discord must be running on this Mac.").font(.system(size:11)).foregroundStyle(Palette.muted)
                    }
                }
                GlassPanel {
                    (geometry.size.width>1000 ? AnyLayout(HStackLayout(spacing:20)):AnyLayout(VStackLayout(alignment:.leading,spacing:16))) {
                        Image(systemName: "gamecontroller").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Palette.mint)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(model.controllerNames.isEmpty ? "Keyboard, or your favorite controller." : model.controllerNames.joined(separator: ", ")).font(.system(size: 14, weight: .medium))
                            Text("Configure bindings, user profiles, updates, DLC, and advanced graphics in core tools.").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Button("Configure controller") { model.section = "Controllers" }.buttonStyle(Tactile(primary:true)).disabled(engine.running)
                        Button("Core tools ↗") { model.coreTools() }.buttonStyle(Tactile()).disabled(engine.running)
                    }
                }
                HStack {
                    Text("Independent project. Nintendo Switch is a trademark of Nintendo.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Spacer()
                    Button("Open data folder") { NSWorkspace.shared.open(model.dataRoot) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.coral)
                }
            }.padding(28).frame(width:max(1,geometry.size.width),alignment:.topLeading)
        }
        }.onChange(of: model.saved.preferences) { _, _ in model.persist() }
    }
    private func panelWidth(_ width:CGFloat)->CGFloat {max(1,width>1120 ? (width-74)/2:width-56)}
    private func panelHeading(_ title: String, icon: String) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(Palette.coral); Text(title).font(.system(size: 16, weight: .semibold)) }
    }
    private func fileRow(_ title: String, subtitle: String, ready: Bool) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 14, weight: .medium)); Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ready ? Palette.mint : Palette.muted)
        }
    }
    private func setting<C: View>(_ title: String, description: String, @ViewBuilder control: () -> C) -> some View {
        HStack { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13, weight: .medium)); Text(description).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth:.infinity,alignment:.leading); Spacer(minLength:16); control().fixedSize() }
    }
}

