import SwiftUI
import AppKit

@main
struct NEXARCApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(NEXARCDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("NEXARC") {
            RootView(model: model, engine: model.engine)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1080, minHeight: 740)
                .onAppear { delegate.model = model; NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshControllers(); model.objectWillChange.send() }
        }.windowStyle(.hiddenTitleBar).defaultSize(width: 1270, height: 850)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("Import programs…") { model.importPrograms() }.keyboardShortcut("o")
                    Button("Run First Light") { model.launch(model.diagnostic) }.keyboardShortcut("r").disabled(model.engine.running)
                    Button("Stop session") { model.engine.stop() }.keyboardShortcut(".").disabled(!model.engine.running)
                }
                CommandGroup(replacing: .appSettings) { Button("Settings…") { model.section = "System" }.keyboardShortcut(",") }
                CommandGroup(replacing: .appTermination) {
                    Button("Quit NEXARC") {
                        NSApp.terminate(nil)
                    }.keyboardShortcut("q")
                }
            }
    }
}

@MainActor
final class NEXARCDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let engine = model?.engine, engine.running else { return .terminateNow }
        engine.stop()
        Task { @MainActor in
            for _ in 0..<180 {
                if !engine.running { break }
                try? await Task.sleep(for:.milliseconds(100))
            }
            sender.reply(toApplicationShouldTerminate:true)
        }
        return .terminateLater
    }
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: EngineBridge
    @ViewState private var intro = true
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let navigation: [(String, String)] = [("Consoles", "square.stack.3d.up"), ("Library", "square.grid.2x2"), ("Saves", "clock.arrow.circlepath"), ("Controllers", "gamecontroller"), ("Sessions", "waveform.path"), ("System", "gearshape"), ("Learn", "sparkle.magnifyingglass")]

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Palette.line).frame(width: 1)
                VStack(spacing: 0) {
                    toolbar
                    Rectangle().fill(Palette.line).frame(height: 1)
                    if engine.running {playControls}
                    Group {
                        switch model.section {
                        case "Consoles": ConsolesView(model:model,engine:engine)
                        case "Saves": SavesView(model:model)
                        case "Controllers": ControllersView(model:model,manager:model.controllers,engine:engine)
                        case "Sessions": SessionsView(model: model, engine: engine)
                        case "System": SystemView(model: model, engine: engine)
                        case "Learn": LearnView(model: model)
                        default: LibraryView(model: model, engine: engine)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).id(model.section).transition(.opacity)

                    statusbar
                }
            }
            if let toast = model.toast {
                VStack { Spacer(); HStack(spacing: 9) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint); Text(toast).font(.system(size: 13)) }.padding(.horizontal, 20).padding(.vertical, 14).background(.regularMaterial, in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.12))).shadow(radius: 15).padding(.bottom, 55) }.allowsHitTesting(false).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if intro { IntroView { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) { intro = false } }.transition(.opacity) }
            if let item=model.inspectedItem {
                GeometryReader {geometry in
                    ZStack {
                        Button {withAnimation(.easeOut(duration:0.16)){model.inspectedItem=nil}} label:{Color.black.opacity(0.56).ignoresSafeArea().contentShape(Rectangle())}.buttonStyle(.plain).accessibilityLabel("Dismiss game details")
                        GameInspector(item:item,model:model,engine:engine)
                            .frame(width:min(720,geometry.size.width-64),height:min(720,geometry.size.height-64))
                            .clipShape(RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).strokeBorder(.white.opacity(0.13)))
                            .shadow(color:.black.opacity(0.5),radius:38,y:18)
                            .onTapGesture {}
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }.transition(.opacity)
            }
            if model.recoveryOpen {
                ZStack{Button{model.recoveryOpen=false}label:{Color.black.opacity(0.55).ignoresSafeArea().contentShape(Rectangle())}.buttonStyle(.plain).accessibilityLabel("Dismiss recovery");RecoveryView(model:model,engine:engine).onTapGesture{}}
            }
            if let error=model.error {
                ZStack {
                    Button {model.error=nil} label:{Color.black.opacity(0.55).ignoresSafeArea().contentShape(Rectangle())}.buttonStyle(.plain).accessibilityLabel("Dismiss message")
                    VStack(alignment:.leading,spacing:18) {
                        HStack {Image(systemName:"info.circle").foregroundStyle(Palette.coral);Text("NEXARC").font(.system(size:20,weight:.semibold));Spacer();Button{model.error=nil}label:{Image(systemName:"xmark").frame(width:34,height:34)}.buttonStyle(SoftPress()).help("Dismiss")}
                        Text(error).font(.system(size:14)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                        HStack {Spacer();Button("Got it"){model.error=nil}.buttonStyle(Tactile(primary:true)).keyboardShortcut(.cancelAction)}
                    }.padding(25).frame(width:440).background(Palette.surface,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).strokeBorder(Palette.line)).shadow(radius:30).onTapGesture{}
                }.transition(.opacity)
            }
        }.onExitCommand {if model.error != nil {model.error=nil}else if model.recoveryOpen{model.recoveryOpen=false}else{model.inspectedItem=nil}}.foregroundStyle(.white.opacity(0.91)).tint(Palette.mint)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.section)
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: model.toast)
            .onAppear {
                intro = model.saved.preferences.showIntro && !CommandLine.arguments.contains("--skip-intro")
                if CommandLine.arguments.contains("--run-diagnostic") { intro = false; model.section = "Sessions"; model.launch(model.diagnostic) }
            }
            .background {
                Button("") { model.section = "Library"; searchFocused = true }.keyboardShortcut("k").hidden()
                Button(""){engine.openSessionMenu()}.keyboardShortcut(.cancelAction).disabled(!engine.running || model.inspectedItem != nil || model.error != nil).hidden()
            }
    }

    private var sidebar: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:11) {
                NEXARCMark().frame(width:35,height:35)
                VStack(alignment:.leading,spacing:3) {
                    Text("NEXARC").font(.system(size:22,weight:.black,design:.monospaced)).tracking(1.5)
                    Text("EVERY ERA. ONE ENGINE.").font(.system(size:8,weight:.medium)).tracking(1).foregroundStyle(Palette.muted).lineLimit(1).minimumScaleFactor(0.85)
                }
            }.padding(.horizontal,24).padding(.top,38).padding(.bottom,28)
            ScrollView(.vertical) {
                VStack(alignment:.leading,spacing:0) {
                    Text("YOUR SPACE").font(.system(size:10,weight:.semibold)).tracking(1.6).foregroundStyle(Palette.muted.opacity(0.6)).padding(.horizontal,27).padding(.bottom,12)
                    ForEach(navigation,id:\.0) {name,icon in
                        Button {model.section=name;if name=="Library" {model.selectedSystem=nil}} label:{
                            HStack(spacing:13) {
                                Image(systemName:icon).font(.system(size:15)).frame(width:19)
                                Text(name=="System" ? "Settings":name).font(.system(size:14,weight:model.section==name ? .semibold:.regular))
                                Spacer()
                                if name=="Library" {Text("\(model.saved.items.count)").font(.system(size:11)).foregroundStyle(Palette.muted)}
                            }.foregroundStyle(model.section==name ? .white:Palette.muted).padding(.horizontal,15).frame(height:44)
                                .background(model.section==name ? .white.opacity(0.065):.clear,in:RoundedRectangle(cornerRadius:11))
                                .overlay(alignment:.leading){if model.section==name {RoundedRectangle(cornerRadius:2).fill(Palette.coral).frame(width:3,height:17)}}
                        }.buttonStyle(SoftPress()).padding(.horizontal,14).padding(.bottom,5).accessibilityAddTraits(model.section==name ? .isSelected:[])
                    }
                    VStack(alignment:.leading,spacing:3) {
                        Text("QUICK ACCESS").font(.system(size:10,weight:.semibold)).tracking(1.5).foregroundStyle(Palette.muted.opacity(0.6)).padding(.bottom,7)
                        ForEach([GameSystem.gb,.gba,.nds,.n3ds,.switchSystem]) {system in
                            Button {model.openSystem(system)} label:{
                                HStack(spacing:9) {
                                    Circle().fill(Color(hex:system.color)).frame(width:5,height:5)
                                    Text(system == .gba ? "Game Boy Advance":system.shortName).font(.system(size:12)).lineLimit(1)
                                    Spacer(minLength:4)
                                    Text("\(model.saved.items.filter{$0.system==system && !$0.isDiagnostic}.count)").font(.system(size:10)).foregroundStyle(Palette.muted)
                                }.frame(maxWidth:.infinity).frame(height:32).contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(model.selectedSystem==system && model.section=="Library" ? .white:Palette.muted)
                        }
                    }.padding(.horizontal,25).padding(.top,20).padding(.bottom,12)
                }
            }.scrollIndicators(.hidden)
            if engine.running {
                VStack(alignment:.leading,spacing:10) {
                    Tag(text:"SESSION ACTIVE",color:Palette.mint,dot:true)
                    Text(engine.currentTitle).font(.system(size:14,weight:.medium)).lineLimit(1)
                    Button("View session →"){model.section="Sessions"}.buttonStyle(SoftPress()).font(.system(size:12)).foregroundStyle(Palette.mint)
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(Palette.mint.opacity(0.04),in:RoundedRectangle(cornerRadius:14)).padding(14)
            } else {
                Button {model.section="Learn"} label:{
                    HStack(spacing:11) {
                        Image(systemName:"sun.horizon").font(.system(size:23,weight:.light)).foregroundStyle(Palette.coral)
                        VStack(alignment:.leading,spacing:5){Text("Curious by design.").font(.system(size:12,weight:.medium));Text("Explore how it works ↗").font(.system(size:11)).foregroundStyle(Palette.muted)}
                        Spacer(minLength:0)
                    }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).strokeBorder(Palette.line))
                }.buttonStyle(SoftPress()).padding(14)
            }
            HStack(spacing:8){Circle().fill(Palette.mint).frame(width:5,height:5);Text("Made for Apple Silicon").font(.system(size:10)).foregroundStyle(Palette.muted)}.padding(.horizontal,25).padding(.bottom,20)
        }.frame(width:230).background(Color(hex:0x10151B))
    }

    private var toolbar: some View {
        HStack(spacing: 15) {
            Text(model.section == "Library" ? model.selectedSystem?.shortName ?? "All games" : model.section=="System" ? "Settings":model.section).font(.system(size: 16, weight: .semibold)).tracking(-0.4)
            Spacer()
            if model.section == "Library" || model.section == "Consoles" {
                HStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.system(size: 13)); TextField(model.section == "Consoles" ? "Find a console":"Find a game", text: $model.search).textFieldStyle(.plain).font(.system(size: 13)).focused($searchFocused); Text("⌘ K").font(.system(size: 11)).padding(.horizontal, 5).padding(.vertical, 3).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 4)) }.foregroundStyle(Palette.muted).padding(.horizontal, 12).frame(width: 233, height: 36).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
            }
            Button { model.importPrograms() } label: { Label("Import", systemImage: "plus") }.buttonStyle(Tactile())
            Button { model.section = "System" } label: { Image(systemName: "gearshape") }.buttonStyle(Tactile()).help("Settings")
        }.padding(.horizontal, 28).frame(height: 64)
    }
    private var playControls:some View {
        VStack(alignment:.leading,spacing:12){
            HStack(spacing:12){
                ZStack{RoundedRectangle(cornerRadius:11).fill(Palette.mint.opacity(0.12));Image(systemName:engine.menuOpen ? "pause.fill":"waveform").font(.system(size:22)).foregroundStyle(Palette.mint)}.frame(width:48,height:48)
                VStack(alignment:.leading,spacing:5){Text(engine.menuOpen ? "SESSION PAUSED":engine.speed>1 ? "FAST FORWARD · \(engine.speed)×":"NOW PLAYING").font(.system(size:10,weight:.bold)).tracking(1.7).foregroundStyle(Palette.mint);Text(engine.currentTitle).font(.system(size:17,weight:.semibold)).lineLimit(1)}
                Spacer(minLength:10)
                TimelineView(.periodic(from:.now,by:1)){context in VStack(alignment:.trailing,spacing:4){Text(EngineBridge.elapsed(context.date.timeIntervalSince(engine.started))).font(.system(size:20,weight:.medium,design:.monospaced));Text("THIS SESSION").font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(Palette.muted)}}
                Button("Return to game"){engine.resumeGame()}.buttonStyle(Tactile(primary:true))
            }
            HStack(spacing:9){
                if engine.isRetro{
                    Button {model.quickSave()}label:{Label("Quick save",systemImage:"square.and.arrow.down")}.buttonStyle(Tactile())
                    Button {engine.openSessionMenu()}label:{Label("Session menu",systemImage:"pause.rectangle")}.buttonStyle(Tactile())
                    Button("Save slots"){model.inspectedItem=engine.currentItem}.buttonStyle(Tactile())
                }
                Button("Recovery"){model.recoveryOpen=true}.buttonStyle(Tactile())
                Spacer(minLength:0)
                Picker("Hold Tab",selection:Binding(get:{engine.fastTarget},set:{value in model.setSessionFastTarget(value)})){ForEach(2...5,id:\.self){Text("\($0)×").tag($0)}}.frame(width:115)
                Button("Save & exit"){engine.stop()}.buttonStyle(Tactile())
            }
        }.padding(.horizontal,24).padding(.vertical,16).background(LinearGradient(colors:[Palette.mint.opacity(0.09),Palette.surface],startPoint:.leading,endPoint:.trailing)).overlay(alignment:.bottom){Rectangle().fill(Palette.mint.opacity(0.2)).frame(height:1)}
    }
    private var statusbar: some View {
        HStack(spacing: 8) {
            Circle().fill(engine.running ? Palette.coral : engine.available ? Palette.mint : Palette.muted).frame(width: 5, height: 5)
            Text(engine.running ? "Running · \(engine.currentTitle)" : "21 systems · Local library · Saves on this Mac").font(.system(size: 10)).foregroundStyle(Palette.muted)
            Spacer()
            Text("APPLE SILICON").font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(Palette.muted.opacity(0.6))
            Rectangle().fill(Palette.line).frame(width: 1, height: 10).padding(.horizontal, 5)
            Text("NEXARC \(AppVersion.current)").font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(Palette.muted.opacity(0.6))
        }.padding(.horizontal, 28).frame(height: 32).background(.white.opacity(0.012))
    }
}

struct IntroView: View {
    let finish: () -> Void
    @ViewState private var reveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            Circle().fill(Palette.coral.opacity(0.07)).frame(width: 420, height: 420).blur(radius: 75).scaleEffect(reveal ? 1.3 : 0.6)
            ForEach(0..<4) { i in Circle().stroke(Palette.coral.opacity(0.035), lineWidth: 1).frame(width: CGFloat(250+i*120), height: CGFloat(250+i*120)).scaleEffect(reveal ? 1 : 0.85) }
            VStack(spacing: 22) {
                NEXARCMark().frame(width: 98, height: 98).rotationEffect(.degrees(reveal ? 0 : -45)).shadow(color: Palette.coral.opacity(0.2), radius: 30)
                Text("NEXARC").font(.system(size: 52, weight: .black,design:.monospaced)).tracking(5)
                Text("A FAMILIAR WORLD. A NEW PLACE TO PLAY.").font(.system(size: 10, weight: .medium)).tracking(2.5).foregroundStyle(Palette.muted)
            }.opacity(reveal ? 1 : 0).offset(y: reveal ? 0 : 12)
            VStack { Spacer(); HStack { Text("EVERY ERA · APPLE SILICON").font(.system(size: 10)).tracking(1.2).foregroundStyle(Palette.muted.opacity(0.6)); Spacer(); Button("Skip intro  ↵", action: finish).buttonStyle(Tactile()).keyboardShortcut(.return, modifiers: []) }.padding(30) }
        }.task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 1.6)) { reveal = true }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 5500))
            if !Task.isCancelled { finish() }
        }
    }
}
