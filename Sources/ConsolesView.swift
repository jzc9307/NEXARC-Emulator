import SwiftUI

struct ConsolesView:View {
    @ObservedObject var model:AppModel
    @ObservedObject var engine:EngineBridge
    private var systems:[GameSystem] {GameSystem.allCases.filter {s in
        (model.galleryFilter == "All systems" || s.family == model.galleryFilter || s.maker.capitalized == model.galleryFilter) &&
        (model.search.isEmpty || s.name.localizedCaseInsensitiveContains(model.search))
    }}
    var body:some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment:.leading,spacing:27) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:11) {
                        Tag(text:"YOUR PERSONAL PLAY MUSEUM",color:Palette.mint,dot:true)
                        Text("Every era.\nOne home.").font(.system(size: 52,weight:.light)).tracking(-2.4).lineSpacing(-3).fixedSize(horizontal:false,vertical:true)
                        Text("The consoles you remember. The adventures you keep.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                        HStack(spacing:22) {stat("21","SYSTEMS");stat("\(model.saved.items.filter{!$0.isDiagnostic}.count)","YOUR GAMES");stat("LOCAL","YOUR SAVES")}.padding(.top,13)
                        HStack {Button {model.openSystem(.gb)} label:{Label("Explore Game Boy",systemImage:"arrow.up.right")}.buttonStyle(Tactile(primary:true));Button("Import games") {model.importPrograms()}.buttonStyle(Tactile())}.padding(.top,8)
                    }.padding(32).frame(width:430,alignment:.leading)
                    ZStack {
                        Circle().fill(Color(hex:GameSystem.gb.color).opacity(0.10)).blur(radius:55).frame(width:240,height:240)
                        Circle().stroke(.white.opacity(0.04),lineWidth:1).frame(width:270,height:270)
                        if !engine.running {HardwareViewport(system:.gb).padding(.vertical,8)}
                        else {Image(nsImage:HardwareStudio.thumbnail(.gb)).resizable().scaledToFit()}
                        VStack {HStack {Spacer();Text("HANDHELD NO. 01").font(.system(size: 10,weight:.medium,design:.monospaced)).tracking(1.8).foregroundStyle(Palette.muted)};Spacer();HStack {Text("1989").font(.system(size: 32,weight:.ultraLight,design:.rounded)).foregroundStyle(.white.opacity(0.25));Spacer();Tag(text:"DRAG TO EXPLORE",color:Color(hex:GameSystem.gb.color))}}.padding(25).allowsHitTesting(false)
                    }.frame(maxWidth:.infinity)
                }.frame(height:420).background(LinearGradient(colors:[Color(hex:0x202C29),Color(hex:0x151E22),Color(hex:0x111C1A)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26)).overlay(RoundedRectangle(cornerRadius:26).strokeBorder(.white.opacity(0.08)))
                HStack {
                    VStack(alignment:.leading,spacing:6) {Text("Choose your world.").font(.system(size: 24,weight:.medium)).tracking(-0.8);Text("Select a console to open its game collection.").font(.system(size: 13)).foregroundStyle(Palette.muted)}
                    Spacer()
                    Picker("Console collection",selection:$model.galleryFilter) {ForEach(["All systems","Handhelds","Home consoles","Nintendo","Sega","Sony"],id:\.self){Text($0)}}.labelsHidden().frame(width:160)
                }
                LazyVGrid(columns:[GridItem(.adaptive(minimum:245,maximum:380),spacing:18)],spacing:18) {
                    ForEach(systems) {s in ConsoleTile(system:s,count:model.saved.items.filter{$0.system==s && !$0.isDiagnostic}.count,ready:s == .switchSystem ? engine.available:engine.retro.available(s),selected:model.controllerNavigationActive && systems.firstIndex(of:s)==model.controllerConsoleIndex) {model.openSystem(s)}.id(s.id)}
                }
                Text("Original NEXARC studio models · Independent project · Console names belong to their respective owners.").font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top,5)
            }.padding(28)
        }.onChange(of:model.controllerConsoleIndex){_,index in if systems.indices.contains(index){withAnimation{proxy.scrollTo(systems[index].id,anchor:.center)}}}.background(GeometryReader{g in Color.clear.onAppear{model.libraryColumns=max(1,Int((g.size.width-38)/263))}.onChange(of:g.size){_,size in model.libraryColumns=max(1,Int((size.width-38)/263))}})
        }
    }
    private func stat(_ value:String,_ title:String)->some View {VStack(alignment:.leading,spacing:5){Text(value).font(.system(size: 21,weight:.light));Text(title).font(.system(size: 9,weight:.semibold)).tracking(1.5).foregroundStyle(Palette.muted)}}
}

private struct ConsoleTile:View {
    let system:GameSystem;let count:Int;let ready:Bool;var selected=false;let open:()->Void
    @ViewState private var hover=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var accent:Color {Color(hex:system.color)}
    var body:some View {
        Button(action:open) {
            VStack(alignment:.leading,spacing:0) {
                ZStack {
                    LinearGradient(colors:[accent.opacity(hover ? 0.17:0.09),Color(hex:0x131B23)],startPoint:.topLeading,endPoint:.bottomTrailing)
                    Ellipse().fill(.black.opacity(0.35)).frame(width:130,height:15).blur(radius:10).offset(y:65)
                    if system == .switchSystem {Image(nsImage:ConsoleStudio.thumbnail(.switchOriginal)).resizable().scaledToFit().padding(8)}
                    else {Image(nsImage:HardwareStudio.thumbnail(system)).resizable().scaledToFit().padding(6)}
                    VStack {HStack {Text(system.maker).font(.system(size: 9,weight:.bold)).tracking(1.8);Spacer();Text(system.year).font(.system(size: 10,design:.monospaced))};Spacer()}.foregroundStyle(accent.opacity(0.7)).padding(18)
                }.frame(height:176)
                VStack(alignment:.leading,spacing:11) {
                    HStack {Text(system.shortName).font(.system(size: 16,weight:.medium)).tracking(-0.3);Spacer();Image(systemName:"arrow.up.right").font(.system(size: 13)).foregroundStyle(accent)}
                    HStack {Text(count == 0 ? "Your next collection" : "\(count) game\(count == 1 ? "":"s") in your library").font(.system(size: 12)).foregroundStyle(Palette.muted);Spacer();Circle().fill(ready ? accent:Palette.muted).frame(width:4,height:4)}
                }.padding(18)
            }.background(Palette.surface,in:RoundedRectangle(cornerRadius:20)).clipShape(RoundedRectangle(cornerRadius:20))
                .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(accent.opacity(selected ? 1:hover ? 0.35:0.08),lineWidth:selected ? 2:1))
                .shadow(color:accent.opacity(hover ? 0.09:0),radius:20,y:5)
                .offset(y:hover && !reduceMotion ? -4:0)
        }.buttonStyle(.plain).onHover{hover=$0}.animation(reduceMotion ? nil:.spring(response:0.35,dampingFraction:0.8),value:hover)
        .accessibilityLabel("\(system.name), \(count) games. Open collection")
    }
}
