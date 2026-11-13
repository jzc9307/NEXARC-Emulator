import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: EngineBridge
    @ViewState private var dropping=false
    @ViewState private var resetID=0
    private var system:GameSystem? {model.selectedSystem}
    private var accent:Color {Color(hex:system?.color ?? 0xA2ECD5)}
    var body:some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment:.leading,spacing:25) {
                if let system {hero(system)}
                HStack {
                    VStack(alignment:.leading,spacing:6) {
                        Text(system == nil ? "All your adventures." : "Your \(system!.shortName) collection.").font(.system(size: 25,weight:.medium)).tracking(-0.7)
                        Text("\(model.visibleItems.count) \(model.visibleItems.count == 1 ? "game":"games") · Stored on your Mac").font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Picker("Library filter",selection:$model.filter) {Text("All games").tag("All programs");Text("Recently played").tag("Recently played");Text("Favorites").tag("Favorites")}.labelsHidden().frame(width:145)
                }
                if model.visibleItems.isEmpty {
                    VStack(spacing:15) {
                        Image(systemName:"shippingbox").font(.system(size: 35,weight:.ultraLight)).foregroundStyle(accent)
                        Text(model.search.isEmpty ? "An empty shelf. A world of possibilities." : "No matching games.").font(.system(size: 18,weight:.light))
                        Text(system.map{"Drop \($0.extensions.prefix(5).map{".\($0)"}.joined(separator:", ")) files here, or choose Import games."} ?? "Import a game to start your collection.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                        Button("Import games…"){model.importPrograms()}.buttonStyle(Tactile(primary:true))
                    }.frame(maxWidth:.infinity).frame(height:240).background(accent.opacity(0.025),in:RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).strokeBorder(accent.opacity(0.16),style:StrokeStyle(lineWidth:1,dash:[6,5])))
                }
                LazyVGrid(columns:[GridItem(.adaptive(minimum:245),spacing:18)],spacing:20) {
                    ForEach(model.visibleItems) {item in GameCard(item:item,model:model,engine:engine).id(item.id)}
                }
                if let system {
                    HStack(alignment:.top,spacing:15) {
                        Image(systemName:"info.circle").foregroundStyle(accent)
                        VStack(alignment:.leading,spacing:7) {Text(system.engineLabel).font(.system(size: 14,weight:.semibold));Text(system.requirement).font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)}
                        Spacer()
                        Button("System files ↗"){model.openSystemFiles()}.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(accent)
                    }.padding(20).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
                }
            if model.controllerNavigationActive{Text("A / Cross · Play     X / Square · Details     LB / RB · Sections").font(.system(size:12)).foregroundStyle(Palette.mint)}
            }.padding(28)
        }.onChange(of:model.controllerSelection){_,id in if let id{withAnimation{proxy.scrollTo(id,anchor:.center)}}}.background(GeometryReader{g in Color.clear.onAppear{model.libraryColumns=max(1,Int((g.size.width-38)/263))}.onChange(of:g.size){_,size in model.libraryColumns=max(1,Int((size.width-38)/263))}}).background(accent.opacity(dropping ? 0.045:0))
        .onDrop(of:[.fileURL],isTargeted:$dropping) {providers in
            for provider in providers {_ = provider.loadObject(ofClass:URL.self) {url,_ in if let url {Task{@MainActor in model.add([url])}}}};return true
        }
        }
    }
    private func hero(_ s:GameSystem)->some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:15) {
                Button {model.section="Consoles"} label:{Label("All consoles",systemImage:"arrow.left")}.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Palette.muted)
                Tag(text:"\(s.maker)  /  \(s.year)",color:accent,dot:true)
                Text(s.shortName).font(.system(size: 37,weight:.light)).tracking(-1.6).fixedSize(horizontal:false,vertical:true)
                Text(s.tagline).font(.system(size: 14)).foregroundStyle(Palette.muted)
                HStack(spacing:9) {
                    Button {model.importPrograms()} label:{Label("Import games",systemImage:"plus")}.buttonStyle(Tactile(primary:true))
                    if let game=model.saved.items.first(where:{$0.system==s && !$0.isDiagnostic}) {Button {model.launch(game,resume:model.hasResume(game))} label:{Image(systemName:"play.fill")}.buttonStyle(Tactile()).disabled(engine.running).help("Play \(game.title)")}
                }.padding(.top,4)
            }.padding(30).frame(width:360,alignment:.leading)
            ZStack(alignment:.bottom) {
                Circle().fill(accent.opacity(0.08)).frame(width:230,height:230).blur(radius:40)
                if engine.running {
                    VStack(spacing:14) {Image(systemName:"gamecontroller").font(.system(size: 42,weight:.ultraLight));Text("\(engine.currentTitle) is running").font(.system(size: 14));Text("Play in the emulation window").font(.system(size: 12)).foregroundStyle(Palette.muted)}.frame(maxWidth:.infinity,maxHeight:.infinity).foregroundStyle(accent)
                } else if s == .switchSystem {ConsoleViewport(console:.switchOriginal,commandID:resetID).padding(.bottom,15)}
                else {HardwareViewport(system:s).padding(.bottom,15)}
                Text("DRAG TO EXPLORE  /  SCROLL TO ZOOM").font(.system(size: 9,weight:.medium)).tracking(1.4).foregroundStyle(Palette.muted).padding(.bottom,14).allowsHitTesting(false)
            }.frame(maxWidth:.infinity)
        }.frame(height:320).background(LinearGradient(colors:[accent.opacity(0.12),Color(hex:0x152027),accent.opacity(0.055)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:24)).overlay(RoundedRectangle(cornerRadius:24).strokeBorder(accent.opacity(0.12)))
    }
}

struct GameCard:View {
    let item:LibraryItem
    @ObservedObject var model:AppModel
    @ObservedObject var engine:EngineBridge
    @ViewState private var hover=false
    private var accent:Color {Color(hex:item.system.color)}
    @ViewBuilder private var artwork:some View {
        if let path=item.coverPath,let image=NSImage(contentsOfFile:path) {GeometryReader {g in
            ZStack {
                Image(nsImage:image).resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped().blur(radius:22).opacity(0.25)
                Image(nsImage:image).resizable().scaledToFit().frame(width:max(1,g.size.width-18),height:max(1,g.size.height-18)).shadow(color:.black.opacity(0.4),radius:10,y:4)
            }.frame(width:g.size.width,height:g.size.height).clipped()
        }}
        else if item.bundledName=="orbit-pong" {PongArt()}
        else if item.isDiagnostic {DiagnosticArt()}
        else {
            ZStack(alignment:.bottomLeading) {
                LinearGradient(colors:[accent.opacity(0.27),Color(hex:0x14232B)],startPoint:.topLeading,endPoint:.bottomTrailing)
                Canvas {context,size in
                    for i in 0..<6 {
                        let diameter=CGFloat(55+i*40)
                        let rect=CGRect(x:size.width*0.72-diameter/2,y:size.height*0.35-diameter/2,width:diameter,height:diameter)
                        context.stroke(Path(ellipseIn:rect),with:.color(accent.opacity(0.08)),lineWidth:1)
                    }
                }
                VStack(alignment:.leading,spacing:10) {
                    Text(item.system.shortName.uppercased()).font(.system(size: 9,weight:.bold)).tracking(1.8)
                    Spacer(minLength:10)
                    Image(systemName:item.system.family=="Handhelds" ? "dpad":"gamecontroller").font(.system(size: 26,weight:.ultraLight))
                    Text(item.displayTitle).font(.system(size: 23,weight:.light,design:.rounded)).tracking(-0.7).lineLimit(2).minimumScaleFactor(0.85)
                }.foregroundStyle(accent).padding(20).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading)
            }
        }
    }
    private var active:Bool{engine.running && engine.currentItem?.id==item.id}
    private var dimmed:Bool{engine.running && !active}
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            Button {model.inspectedItem=item} label:{
                GeometryReader {geometry in
                    ZStack(alignment:.topTrailing) {
                        artwork.frame(width:geometry.size.width,height:176).clipped()
                        if active {HStack(spacing:6){Circle().fill(Palette.mint).frame(width:5,height:5);Text(engine.menuOpen ? "PAUSED":"NOW PLAYING").font(.system(size:10,weight:.bold)).tracking(0.6)}.foregroundStyle(Palette.mint).padding(.horizontal,11).padding(.vertical,8).background(Color(hex:0x101C21),in:Capsule()).overlay(Capsule().strokeBorder(Palette.mint.opacity(0.4))).shadow(color:.black.opacity(0.3),radius:5,y:2).padding(10)}
                        else if model.hasResume(item) {Text("CONTINUE PLAYING").font(.system(size:10,weight:.bold)).tracking(0.5).foregroundStyle(Palette.mint).padding(.horizontal,11).padding(.vertical,8).background(Color(hex:0x101C21),in:Capsule()).padding(10)}
                        if model.coverLoading.contains(item.id){ProgressView().controlSize(.small).padding(14)}
                    }.frame(width:geometry.size.width,height:176).clipped()
                }.frame(height:176).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Game details, saves and tools")
            VStack(alignment:.leading,spacing:12) {
                HStack(alignment:.top) {VStack(alignment:.leading,spacing:6){Text(item.displayTitle).font(.system(size: 16,weight:.semibold)).lineLimit(1);Text(item.isDiagnostic ? "CPU self-test" : "\(item.system.shortName) · \(item.format)").font(.system(size: 11)).foregroundStyle(Palette.muted)};Spacer();Button{model.favorite(item)}label:{Image(systemName:item.favorite ? "heart.fill":"heart").font(.system(size: 13)).foregroundStyle(item.favorite ? accent:Palette.muted)}.buttonStyle(SoftPress()).frame(width:36,height:36).contentShape(Rectangle()).help("Favorite")}
                HStack {Button {active ? engine.resumeGame():model.launch(item,resume:model.hasResume(item))} label:{Label(active ? "Return to game":model.hasResume(item) ? "Resume":"Play",systemImage:"play.fill").font(.system(size: 12,weight:.semibold)).foregroundStyle(accent).padding(.horizontal,12).frame(minWidth:88,minHeight:40).background(accent.opacity(0.10),in:RoundedRectangle(cornerRadius:9)).contentShape(Rectangle())}.buttonStyle(SoftPress()).disabled(dimmed);Spacer();if active {TimelineView(.periodic(from:.now,by:1)){context in Text(EngineBridge.elapsed(context.date.timeIntervalSince(engine.started))).font(.system(size:12,weight:.semibold,design:.monospaced)).foregroundStyle(Palette.mint)}} else if item.playSeconds>0 {Text("\(Int(item.playSeconds/60)) min").font(.system(size: 10)).foregroundStyle(Palette.muted)};Button{model.inspectedItem=item}label:{Image(systemName:"ellipsis").font(.system(size: 15)).frame(width:36,height:36).contentShape(Rectangle())}.buttonStyle(SoftPress()).foregroundStyle(Palette.muted).help("Game tools")}
            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).frame(height:132)
        }.frame(maxWidth:.infinity).frame(height:308).background(Palette.surface,in:RoundedRectangle(cornerRadius:18)).clipShape(RoundedRectangle(cornerRadius:18)).overlay(RoundedRectangle(cornerRadius:18).strokeBorder(active || (model.controllerNavigationActive && model.controllerSelection==item.id) ? Palette.mint.opacity(0.9):accent.opacity(hover ? 0.28:0.08),lineWidth:model.controllerNavigationActive && model.controllerSelection==item.id ? 2:1)).onHover{hover=$0}.saturation(dimmed ? 0.1:1).opacity(dimmed ? 0.42:1)
        .contextMenu {
            Button("Play from start"){model.launch(item)}.disabled(engine.running)
            if model.hasResume(item){Button("Resume saved session"){model.launch(item,resume:true)}.disabled(engine.running)}
            Button("Game tools & saves…"){model.inspectedItem=item}
            Button("Choose cover image…"){model.cover(item)}
            if item.coverPath==nil{Button("Find cover online"){model.fetchCover(item,retry:true)}}
            Button("Show game in Finder"){NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath:item.path)])}
            if !item.isBundled {Divider();Button("Remove from library",role:.destructive){model.remove(item)}}
        }
    }
}
