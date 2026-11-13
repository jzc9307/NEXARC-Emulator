import SwiftUI

struct DisplaySettingsView:View {
    @ObservedObject var model:AppModel
    var compact=false
    @ViewState private var system:GameSystem = .nds
    private var profile:DisplayProfile{model.saved.displays?[system.rawValue] ?? DisplayProfile.defaultProfile(for:system)}
    private func binding<T>(_ key:WritableKeyPath<DisplayProfile,T>)->Binding<T>{Binding(get:{profile[keyPath:key]},set:{value in var p=profile;p[keyPath:key]=value;if model.saved.displays==nil{model.saved.displays=[:]};model.saved.displays?[system.rawValue]=p;model.persist()})}
    var body:some View {
        GlassPanel {
            VStack(alignment:.leading,spacing:20){
                HStack{Image(systemName:"display").foregroundStyle(Palette.mint);Text("Console display & skins").font(.system(size:20,weight:.semibold));Spacer();Picker("Console display",selection:$system){ForEach(GameSystem.allCases){Text($0.shortName).tag($0)}}.frame(width:200)}
                (compact ? AnyLayout(VStackLayout(alignment:.leading,spacing:20)):AnyLayout(HStackLayout(alignment:.top,spacing:28))) {
                    Group {
                        if profile.skin == .custom,let asset=profile.customAsset,system != .switchSystem {
                            SkinPlacementEditor(system:system,dataRoot:model.dataRoot,asset:Binding(get:{profile.customAsset ?? asset},set:{edited in guard var assets=profile.customSkins,let i=assets.firstIndex(where:{$0.id==edited.id}) else{return};assets[i]=edited;binding(\.customSkins).wrappedValue=assets}))
                        }else{SkinPreview(system:system,profile:profile,dataRoot:model.dataRoot)}
                    }.frame(maxWidth:.infinity).frame(height:profile.skin == .custom && system != .switchSystem ? 400:285).background(.black.opacity(0.25),in:RoundedRectangle(cornerRadius:16))
                    VStack(alignment:.leading,spacing:16){
                        Picker("Console skin",selection:binding(\.skin)){ForEach(ConsoleSkin.allCases.filter{($0 != .custom || profile.customAsset != nil) && ($0 != .hardware || HardwareSkinCatalog.asset(for:system) != nil)}){Text($0.rawValue).tag($0)}}
                        Button{model.importSkin(for:system)}label:{Label("Upload skin image…",systemImage:"photo.badge.plus")}.buttonStyle(Tactile()).disabled(model.engine.running)
                        if system == .switchSystem {
                            Text("The NEXARC shell follows the Switch game window. Fullscreen and resolution live in Playback preferences.").font(.system(size:12)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
                        } else {
                            if [.nds,.n3ds].contains(system){Picker("Screen layout",selection:binding(\.layout)){ForEach(ScreenLayout.allCases){Text($0.rawValue).tag($0)}}.disabled(profile.skin == .hardware || (profile.skin == .custom && profile.customAsset?.secondaryScreen != nil))}
                            Picker("Screen sizing",selection:binding(\.sizing)){ForEach(["Fit","Native 1×","Native 2×","Native 3×"],id:\.self){Text($0).tag($0)}}
                            WindowSizePicker(profile:Binding(get:{profile},set:{value in if model.saved.displays==nil{model.saved.displays=[:]};model.saved.displays?[system.rawValue]=value;model.persist()}))
                            if system == .nds{Stepper("Screen gap: \(profile.gap) px",value:binding(\.gap),in:0...64,step:4)}
                            Toggle("Launch in full screen",isOn:binding(\.fullscreen))
                            Toggle("Smooth pixels",isOn:binding(\.smooth))
                        }
                    }.font(.system(size:14)).frame(width:compact ? nil:340).frame(maxWidth:compact ? .infinity:nil,alignment:.leading)
                }
                if profile.skin == .hardware {Text("Hardware artwork by Duimon · CC BY-NC-ND 4.0. Use Stacked for DS and 3DS to match this shell.").font(.system(size:12)).foregroundStyle(Palette.muted)}
                if profile.skin == .custom,let asset=profile.customAsset {
                    VStack(alignment:.leading,spacing:12){
                        HStack{Text("Your uploaded skins").fontWeight(.semibold);Spacer();Picker("Uploaded skin",selection:Binding(get:{profile.customAsset?.id ?? ""},set:{binding(\.selectedCustomSkin).wrappedValue=$0})){ForEach(profile.customSkins ?? []){Text($0.name).tag($0.id)}}.labelsHidden().frame(width:240);Button("Remove"){model.removeSkin(for:system)}.buttonStyle(Tactile()).disabled(model.engine.running)}
                        if system != .switchSystem {
                            Text("Place the game inside your artwork using the draggable screen handles above. DS and 3DS can position the top and touch screens separately.").font(.system(size:12)).foregroundStyle(Palette.muted)

                        } else {Text("Switch skins are transparent overlays scaled to the game window. Use a PNG with a clear screen opening; the game keeps its full-window viewport.").font(.system(size:12)).foregroundStyle(Palette.muted)}
                        Text(asset.name).font(.system(size:11)).foregroundStyle(Palette.muted)
                    }.padding(16).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:12))
                }
                Text("Skins are saved separately for each console. Settings changes apply next launch. During play, press Esc to switch skins. Upload PNG, JPEG, WebP or TIFF images; skin packages must first be exported as an image.").font(.system(size:13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)
            }
        }.onChange(of:profile.skin){_,skin in if skin == .hardware && [.nds,.n3ds].contains(system){binding(\.layout).wrappedValue = .stacked}}
    }
}

struct SkinPreview:View {
    let system:GameSystem
    let profile:DisplayProfile
    let dataRoot:URL
    var body:some View {
        Canvas {c,size in
            if let asset=profile.skin == .hardware ? HardwareSkinCatalog.asset(for:system):(profile.skin == .custom ? profile.customAsset:nil),let image=NSImage(contentsOf:profile.skin == .hardware ? HardwareSkinCatalog.image(for:asset):dataRoot.appendingPathComponent(asset.file)) {
                let w=min(size.width,size.height*asset.imageAspect),h=w/asset.imageAspect
                let canvas=CGRect(x:(size.width-w)/2,y:(size.height-h)/2,width:w,height:h)
                c.draw(Image(nsImage:image),in:canvas)
                if system != .switchSystem && profile.skin == .custom {let a=asset.screen.fitted;let viewport=CGRect(x:canvas.minX+w*a.x,y:canvas.minY+h*a.y,width:w*a.width,height:h*a.height);c.fill(Path(viewport),with:.color(Palette.mint.opacity(0.22)));c.stroke(Path(viewport),with:.color(Palette.mint),lineWidth:2);c.draw(Text("GAME SCREEN").font(.system(size:10,weight:.bold)).foregroundColor(Palette.mint),at:CGPoint(x:viewport.midX,y:viewport.midY))}
                return
            }
            let aspect=profile.aspect(system),w=min(size.width*0.62,size.height*0.74*aspect),h=w/aspect
            let screen=CGRect(x:(size.width-w)/2,y:(size.height-h)/2,width:w,height:h)
            let shell=screen.insetBy(dx:profile.skin == .none ? -5:-min(45,w*0.25),dy:profile.skin == .none ? -5:-17)
            let color=profile.skin == .neon ? Color(hex:0x123E48):Color(hex:system.shellColor)
            c.fill(Path(roundedRect:shell,cornerRadius:17),with:.color(profile.skin == .none ? .white.opacity(0.08):color))
            c.fill(Path(roundedRect:screen,cornerRadius:3),with:.color(Color(hex:0x101A25)))
            if [.nds,.n3ds].contains(system) && profile.layout == .stacked{let r=CGRect(x:screen.minX,y:screen.midY-5,width:w,height:10);c.fill(Path(r),with:.color(color));}
            c.draw(Text(system.shortName.uppercased()).font(.system(size:13,weight:.bold,design:.monospaced)).foregroundColor(Palette.mint),at:CGPoint(x:size.width/2,y:size.height/2-12))
            c.draw(Text(profile.layout.rawValue).font(.system(size:11)).foregroundColor(.gray),at:CGPoint(x:size.width/2,y:size.height/2+12))
            if profile.skin != .none{let x=shell.minX+18,y=screen.maxY-25;c.fill(Path(CGRect(x:x-8,y:y-3,width:16,height:6)),with:.color(.black.opacity(0.65)));c.fill(Path(CGRect(x:x-3,y:y-8,width:6,height:16)),with:.color(.black.opacity(0.65)));for dx in [-4.0,5.0]{c.fill(Path(ellipseIn:CGRect(x:shell.maxX-23+dx,y:y-5+dx,width:6,height:6)),with:.color(.black.opacity(0.65)))}}
        }
    }
}
struct KeyboardSettingsView:View {
    @ObservedObject var model:AppModel
    private var mapping:KeyboardMapping{model.saved.keyboard ?? KeyboardMapping()}
    var body:some View {
        GlassPanel {
            VStack(alignment:.leading,spacing:22){
                HStack{Tag(text:"KEYBOARD READY",color:Palette.mint,dot:true);Spacer();Text("No controller needed").foregroundStyle(Palette.muted)}
                Text("Your keyboard is player one.").font(.system(size:23,weight:.semibold)).tracking(-0.7)
                KeyboardDiagram(mapping:mapping)
                Text("Highlighted keys are your game controls. Customize each action below. Click the DS lower screen to use its touchscreen.").font(.system(size:14)).foregroundStyle(Palette.muted)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){ForEach(KeyboardMapping.actions,id:\.0){action,label in
                    HStack{Text(label).font(.system(size:14,weight:.medium));Spacer();Picker(label,selection:Binding(get:{mapping.bindings[action] ?? "nul"},set:{value in var m=mapping;m.bindings[action]=value;model.saved.keyboard=m;model.persist()})){ForEach(KeyboardMapping.keys,id:\.self){Text(KeyboardMapping.label($0)).tag($0)}}.labelsHidden().frame(width:140)}.padding(12).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:10))
                }}
                HStack{Label("Esc · session menu",systemImage:"pause.rectangle");Spacer();Text("Tab · selected speed   /   Shift + Tab · 5×   /   F5 save   /   F8 load").foregroundStyle(Palette.muted)}.font(.system(size:13))
                HStack{Text("Bindings apply to retro consoles next launch. Switch keyboard bindings are in Core tools → Input.").font(.system(size:13)).foregroundStyle(Palette.muted);Spacer();Button("Reset keys"){model.saved.keyboard=KeyboardMapping();model.persist()}.buttonStyle(Tactile())}
            }
        }
    }
}

struct KeyboardDiagram:View {
    let mapping:KeyboardMapping
    private let rows=[["q","w","e","r","t","y","u","i","o","p"],["a","s","d","f","g","h","j","k","l"],["z","x","c","v","b","n","m"]]
    private func key(_ value:String)->some View {
        let assigned=mapping.bindings.filter{$0.value==value}.map{$0.key.uppercased()}.sorted().joined(separator:"/")
        return VStack(spacing:3){Text(KeyboardMapping.label(value)).font(.system(size:value.count>1 ? 11:18,weight:.semibold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.7);Text(assigned.isEmpty ? " ":assigned).font(.system(size:8,weight:.bold)).lineLimit(1).minimumScaleFactor(0.6).foregroundStyle(Palette.mint)}
            .frame(maxWidth:.infinity).frame(height:48).background(LinearGradient(colors:[assigned.isEmpty ? .white.opacity(0.05):Palette.mint.opacity(0.18),.white.opacity(0.025)],startPoint:.top,endPoint:.bottom),in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).strokeBorder(assigned.isEmpty ? Palette.line:Palette.mint.opacity(0.3))).shadow(color:.black.opacity(0.2),radius:0,y:3)
    }
    var body:some View {
        HStack(alignment:.bottom,spacing:20){
            VStack(spacing:9){ForEach(rows,id:\.self){row in HStack(spacing:7){ForEach(row,id:\.self){key($0)}}.padding(.horizontal,row.count==9 ? 12:row.count==7 ? 32:0)}}
            VStack(spacing:9){HStack(spacing:7){key("enter");key("rshift")};HStack(spacing:7){Color.clear;key("up");Color.clear}.frame(height:48);HStack(spacing:7){key("left");key("down");key("right")}}.frame(width:175)
        }.padding(.vertical,10)
    }
}

struct WindowSizePicker:View {
    @Binding var profile:DisplayProfile
    private func dimension(_ key:WritableKeyPath<DisplayProfile,Int>)->Binding<Int>{Binding(get:{profile[keyPath:key]},set:{number in profile.windowPreset = .custom;profile[keyPath:key]=number})}
    var body:some View {
        VStack(alignment:.leading,spacing:10){
            HStack(spacing:12){Text("Window size").font(.system(size:13));Spacer(minLength:0);Picker("Window size",selection:Binding(get:{profile.selectedWindowPreset},set:{preset in
                let frame=NSApp.keyWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1280,height:800)
                profile.applyWindowPreset(preset,availableWidth:Int(frame.width),availableHeight:Int(frame.height))
            })){ForEach(WindowSizePreset.allCases){preset in Text(preset.label).tag(preset)}}.labelsHidden().frame(width:215)}
            if profile.selectedWindowPreset == .custom {
                HStack(spacing:8){Spacer();TextField("Width",value:dimension(\.windowWidth),format:.number.grouping(.never)).frame(width:78).accessibilityLabel("Custom window width");Text("×").foregroundStyle(Palette.muted);TextField("Height",value:dimension(\.windowHeight),format:.number.grouping(.never)).frame(width:78).accessibilityLabel("Custom window height");Text("pt").foregroundStyle(Palette.muted)}.font(.system(size:13))
            }
            if profile.selectedWindowPreset == .fitDisplay{Text("Fits the available display area at launch.").font(.system(size:11)).foregroundStyle(Palette.muted)}
        }
    }
}
