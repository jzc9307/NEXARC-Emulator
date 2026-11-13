import SwiftUI
import SceneKit

struct ControllersView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var manager: ControllerManager
    @ObservedObject var engine: EngineBridge
    @ViewState private var previewController=false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:8) {
                        Text("Make yourself at home.").font(.system(size: 28,weight:.light)).tracking(-1)
                        Text("Your controller. Your buttons. Your way to play.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button { manager.refreshNative(); manager.refreshCoreDevices() } label: { Label(manager.probing ? "Detecting…" : "Detect devices",systemImage:"arrow.clockwise") }.buttonStyle(Tactile()).disabled(engine.running || manager.probing)
                }
                GlassPanel(padding:17) {
                    HStack(spacing:14) {Image(systemName:"gamecontroller.fill").foregroundStyle(Palette.mint);Text(manager.hasNativeDevice ? "Your controller is connected. The profile editor below configures Switch. Retro consoles use macOS mapping; F1 → Controls opens per-core remapping." : "Keyboard is ready to play. Connect a Bluetooth or USB controller to see its model and live inputs. You can also preview controller models below.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)}
                }
                if !manager.hasNativeDevice {
                    KeyboardSettingsView(model:model)
                    Button(previewController ? "Hide controller preview":"Preview controller models"){previewController.toggle()}.buttonStyle(Tactile())
                }
                if manager.hasNativeDevice || previewController {
                HStack(alignment:.top,spacing:18) {
                    VStack(spacing:17) {
                        GlassPanel(padding:20) {
                            VStack(alignment:.leading,spacing:16) {
                                HStack { Tag(text: manager.hasNativeDevice ? "LIVE INPUT" : "MODEL PREVIEW",color:manager.hasNativeDevice ? Palette.mint : Palette.coral,dot:manager.hasNativeDevice); Spacer(); Text("PLAYER \(manager.player)").font(.system(size: 11,weight:.semibold)).foregroundStyle(Palette.muted) }
                                Picker("Controller artwork",selection:familyBinding) { ForEach(ControllerFamily.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).labelsHidden()
                                ControllerViewport(family:manager.profile.family,pressed:manager.pressed,leftStick:manager.leftStick,rightStick:manager.rightStick).frame(height:270).id(manager.profile.family)
                                HStack { Text(manager.hasNativeDevice ? manager.nativeNames[manager.nativeIndex] : "Connect a controller by Bluetooth or USB").font(.system(size: 13,weight:.medium)); Spacer() }
                                if manager.nativeNames.count > 1 { Picker("Live input device",selection:$manager.nativeIndex) { ForEach(manager.nativeNames.indices,id:\.self) { Text(manager.nativeNames[$0]).tag($0) } } }
                                Text(manager.hasNativeDevice ? "Press a button to see it light up below. The artwork represents the controller family." : "Preview artwork is available offline. Live input and device assignment require a controller recognized by macOS and the emulation core.").font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                                Text("Model: \(manager.profile.family.credit)").font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.7))
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }
                        GlassPanel(padding:20) {
                            VStack(alignment:.leading,spacing:16) {
                                HStack { Text("Live input").font(.system(size: 14,weight:.semibold)); Spacer(); Tag(text:manager.hasNativeDevice ? "CONNECTED" : "NO DEVICE",color:manager.hasNativeDevice ? Palette.mint : Palette.muted) }
                                HStack(spacing:24) { stick("L",point:manager.leftStick); stick("R",point:manager.rightStick); Spacer(); VStack(spacing:12) { trigger("LT / ZL",value:manager.triggerValues[0]); trigger("RT / ZR",value:manager.triggerValues[1]) } }
                                LazyVGrid(columns:[GridItem(.adaptive(minimum:53))],spacing:8) {
                                    ForEach(ControllerProfile.sources.filter { $0 != "Unbound" },id:\.self) { key in
                                        Text(manager.profile.family.label(key)).font(.system(size: 10,weight:.medium)).lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth:.infinity).frame(height:28)
                                            .background(manager.pressed.contains(key) ? Palette.mint.opacity(0.27) : .white.opacity(0.035),in:RoundedRectangle(cornerRadius:7))
                                            .foregroundStyle(manager.pressed.contains(key) ? Palette.mint : Palette.muted)
                                    }
                                }
                            }
                        }
                    }.frame(maxWidth:.infinity)
                    GlassPanel(padding:22) {
                        VStack(alignment:.leading,spacing:16) {
                            HStack { Text("Switch button mapping").font(.system(size: 16,weight:.semibold)); Spacer(); Picker("Player",selection:$manager.player) { ForEach(1...4,id:\.self) { Text("Player \($0)").tag($0) } }.labelsHidden().frame(width:100) }
                            Picker("Game device",selection:Binding(get:{ manager.profile.deviceID },set:{ manager.selectDevice($0) })) {
                                Text("Not assigned · keyboard fallback").tag("")
                                if !manager.profile.deviceID.isEmpty && !manager.devices.contains(where:{$0.id==manager.profile.deviceID}) { Text("Saved device · disconnected").tag(manager.profile.deviceID) }
                                ForEach(manager.devices) { Text($0.name).tag($0.id) }
                            }.font(.system(size: 13))
                            HStack { Text("SWITCH ACTION"); Spacer(); Text("PHYSICAL BUTTON") }.font(.system(size: 10,weight:.semibold)).tracking(1).foregroundStyle(Palette.muted)
                            ForEach(ControllerProfile.targets,id:\.0) { target,label in
                                HStack(spacing:9) {
                                    Text(label).font(.system(size: 13,weight:.semibold)).frame(width:58,alignment:.leading)
                                    Spacer(minLength:0)
                                    Picker("Switch \(label)",selection:Binding(get:{manager.profile.bindings[target] ?? "Unbound"},set:{value in manager.change{$0.bindings[target]=value}})) {
                                        ForEach(ControllerProfile.sources,id:\.self) { Text(manager.profile.family.label($0)).tag($0) }
                                    }.labelsHidden().frame(width:145)
                                    Button { manager.waitingFor = manager.waitingFor == target ? nil : target } label: { Image(systemName:manager.waitingFor == target ? "waveform" : "record.circle").font(.system(size: 14)).foregroundStyle(manager.waitingFor == target ? Palette.coral : Palette.muted) }.buttonStyle(.plain).disabled(!manager.hasNativeDevice).help("Listen for a physical button")
                                }.padding(.vertical,2)
                                    .background(manager.pressed.contains(manager.profile.bindings[target] ?? "") ? Palette.mint.opacity(0.055) : .clear,in:RoundedRectangle(cornerRadius:5))
                            }
                            if let target = manager.waitingFor { Text("Press a physical button for Switch \(target.uppercased()). Click the listen icon again to cancel.").font(.system(size: 12)).foregroundStyle(Palette.coral) }
                            Divider().overlay(Palette.line)
                            HStack { Text("Stick deadzone"); Spacer(); Text("\(Int(manager.profile.deadzone*100))%") }.font(.system(size: 12)).foregroundStyle(Palette.muted)
                            Slider(value:Binding(get:{manager.profile.deadzone},set:{value in manager.change{$0.deadzone=value}}),in:0...0.4).tint(Palette.mint)
                            HStack { Text("Trigger threshold"); Spacer(); Text("\(Int(manager.profile.triggerThreshold*100))%") }.font(.system(size: 12)).foregroundStyle(Palette.muted)
                            Slider(value:Binding(get:{manager.profile.triggerThreshold},set:{value in manager.change{$0.triggerThreshold=value}}),in:0.05...0.95).tint(Palette.coral)
                            HStack { Toggle("Invert left Y",isOn:Binding(get:{manager.profile.invertLeftY},set:{value in manager.change{$0.invertLeftY=value}})); Toggle("Invert right Y",isOn:Binding(get:{manager.profile.invertRightY},set:{value in manager.change{$0.invertRightY=value}})) }.font(.system(size: 12)).toggleStyle(.checkbox)
                            HStack { Button("Reset layout") { manager.change { $0.bindings=ControllerProfile.defaults; $0.deadzone=0.1; $0.triggerThreshold=0.5; $0.invertLeftY=false; $0.invertRightY=false } }.buttonStyle(Tactile()); Spacer(); Button("Save profile") { manager.save() }.buttonStyle(Tactile(primary:true)) }
                            if let message = manager.message { Text(message).font(.system(size: 12)).foregroundStyle(Palette.mint).fixedSize(horizontal:false,vertical:true) }
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }.frame(width:360).disabled(engine.running)
                }
                }
            }.frame(maxWidth:.infinity,alignment:.leading).padding(28)
        }.onAppear { manager.refreshNative() }
    }
    private var familyBinding: Binding<ControllerFamily> { Binding(get:{manager.profile.family},set:{family in manager.change{$0.family=family}}) }
    private func stick(_ label: String,point: CGPoint) -> some View {
        VStack(spacing:7) {
            ZStack { Circle().stroke(Palette.line,lineWidth:1).frame(width:58,height:58); Rectangle().fill(Palette.line).frame(width:58,height:1); Rectangle().fill(Palette.line).frame(width:1,height:58); Circle().fill(Palette.mint).frame(width:9,height:9).offset(x:point.x*22,y:-point.y*22) }
            Text("\(label)  \(point.x, specifier:"%.2f") / \(point.y, specifier:"%.2f")").font(.system(size: 10,design:.monospaced)).foregroundStyle(Palette.muted)
        }
    }
    private func trigger(_ label: String,value: Float) -> some View {
        HStack(spacing:8) { Text(label).font(.system(size: 10)).foregroundStyle(Palette.muted).frame(width:37); GeometryReader { g in ZStack(alignment:.leading) { Capsule().fill(.white.opacity(0.05)); Capsule().fill(Palette.coral).frame(width:max(0,g.size.width*CGFloat(value))) } }.frame(width:75,height:5) }
    }
}

struct ControllerViewport: NSViewRepresentable {
    let family: ControllerFamily
    var pressed:Set<String> = []
    var leftStick:CGPoint = .zero
    var rightStick:CGPoint = .zero
    func makeNSView(context:Context) -> ControllerSceneView {
        let view=ControllerSceneView()
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting=false
        view.allowsCameraControl=true
        view.rendersContinuously=false
        view.antialiasingMode = .multisampling4X
        let scene=SCNScene();scene.background.contents=NSColor.clear
        let artwork=SCNNode()
        var importedModel=false
        if let file=family.modelFile,
           let url=Bundle.main.url(forResource:file,withExtension:"glb",subdirectory:"ControllerModels"),
           let imported=try? ConsoleAsset(url:url).load(console:.switchOriginal) {
            let bounds=imported.boundingBox
            let extent=SCNVector3(bounds.max.x-bounds.min.x,bounds.max.y-bounds.min.y,bounds.max.z-bounds.min.z)
            let scale:CGFloat=3/max(extent.x,max(extent.y,extent.z))
            imported.scale=SCNVector3(scale,scale,scale)
            imported.position=SCNVector3(-(bounds.min.x+bounds.max.x)*scale/2,-(bounds.min.y+bounds.max.y)*scale/2,-(bounds.min.z+bounds.max.z)*scale/2)
            artwork.addChildNode(imported);importedModel=true
        } else {
            artwork.addChildNode(ProControllerModel.make(family))
        }
        scene.rootNode.addChildNode(artwork)
        view.artwork=artwork
        let camera=SCNNode();camera.camera=SCNCamera()
        camera.camera?.usesOrthographicProjection=true
        camera.camera?.orthographicScale=1.5
        camera.camera?.zNear=0.1;camera.camera?.zFar=30
        camera.camera?.wantsHDR=true
        camera.camera?.wantsExposureAdaptation=false
        camera.camera?.exposureOffset=importedModel ? -0.85 : -2.0
        camera.position=SCNVector3(0,0.7,5.5)
        camera.look(at:SCNVector3Zero)
        scene.rootNode.addChildNode(camera);view.pointOfView=camera
        let lamps:[(SCNVector3,CGFloat)] = importedModel ? [(SCNVector3(-3,4,5),350),(SCNVector3(3,1,-2),170)] : [(SCNVector3(-3,5,6),600),(SCNVector3(4,1,4),300),(SCNVector3(1,4,-3),400)]
        for (position,intensity) in lamps {
            let node=SCNNode();node.light=SCNLight();node.light?.type = .omni
            node.light?.intensity=intensity;node.position=position;scene.rootNode.addChildNode(node)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient
        ambient.light?.intensity=importedModel ? 70:80;scene.rootNode.addChildNode(ambient)
        view.scene=scene
        view.setAccessibilityLabel("Interactive \(family.rawValue) controller model")
        return view
    }
    func updateNSView(_ view:ControllerSceneView,context:Context) {
        SCNTransaction.begin();SCNTransaction.disableActions=true
        view.artwork?.enumerateChildNodes {node,_ in
            if let name=node.name,name.hasPrefix("control.") {
                let key=String(name.dropFirst(8))
                node.geometry?.firstMaterial?.emission.contents=pressed.contains(key) ? NSColor(srgbRed:0.40,green:0.85,blue:0.72,alpha:1):NSColor.black
            }
            if node.name=="motion.LeftStick" {node.eulerAngles.x = -leftStick.y*0.18;node.eulerAngles.y=leftStick.x*0.18}
            if node.name=="motion.RightStick" {node.eulerAngles.x = -rightStick.y*0.18;node.eulerAngles.y=rightStick.x*0.18}
        }
        SCNTransaction.commit();view.needsDisplay=true
    }
    static func dismantleNSView(_ view:ControllerSceneView,coordinator:()) {view.scene=nil;view.pointOfView=nil}
}

final class ControllerSceneView:SCNView {
    var artwork:SCNNode?
    override func layout() {
        super.layout()
        guard let artwork,let camera=pointOfView?.camera,bounds.height>0 else{return}
        let box=artwork.boundingBox
        let width=Double(box.max.x-box.min.x),height=Double(box.max.y-box.min.y),depth=Double(box.max.z-box.min.z)
        let aspect=max(0.5,Double(bounds.width/bounds.height))
        camera.orthographicScale=max((height+depth*0.15)/2,(width+depth*0.1)/(2*aspect))*1.16
    }
}
