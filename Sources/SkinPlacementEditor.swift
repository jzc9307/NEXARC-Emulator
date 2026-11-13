import SwiftUI

struct SkinPlacementEditor:View {
    let system:GameSystem
    let dataRoot:URL
    @Binding var asset:CustomConsoleSkin
    @ViewState private var selected=0
    @ViewState private var dragStart:SkinScreenArea?
    @ViewState private var resizeStart:SkinScreenArea?
    @ViewState private var image:NSImage?
    private var separate:Bool{asset.secondaryScreen != nil}
    private var dualSystem:Bool{[.nds,.n3ds].contains(system)}
    private var area:SkinScreenArea{selected==1 ? asset.secondaryScreen ?? asset.screen:asset.screen}
    var body:some View {
        VStack(alignment:.leading,spacing:10){
            if dualSystem {
                Toggle("Place screens separately",isOn:Binding(get:{separate},set:{enabled in
                    if enabled {asset.screen=SkinScreenArea(x:0.1,y:0.08,width:0.8,height:0.38);asset.secondaryScreen=SkinScreenArea(x:system == .n3ds ? 0.18:0.1,y:0.54,width:system == .n3ds ? 0.64:0.8,height:0.38)}
                    else{asset.screen=SkinScreenArea();asset.secondaryScreen=nil;selected=0}
                })).font(.system(size:12)).toggleStyle(.switch).controlSize(.small)
                if separate{Picker("Screen",selection:$selected){Text("Top screen").tag(0);Text("Touch screen").tag(1)}.pickerStyle(.segmented)}
            }
            GeometryReader{g in
                let width=min(g.size.width,g.size.height*asset.imageAspect),height=width/asset.imageAspect
                let canvas=CGRect(x:(g.size.width-width)/2,y:(g.size.height-height)/2,width:width,height:height)
                ZStack(alignment:.topLeading){
                    Color.black.opacity(0.25)
                    if let image{Image(nsImage:image).resizable().frame(width:canvas.width,height:canvas.height).position(x:canvas.midX,y:canvas.midY)}
                    screenBox(0,canvas:canvas)
                    if separate{screenBox(1,canvas:canvas)}
                }.coordinateSpace(name:"skinCanvas").clipShape(RoundedRectangle(cornerRadius:12))
            }.frame(minHeight:210,maxHeight:.infinity)
            Text("Drag a screen to move it. Drag its corner to resize.").font(.system(size:11)).foregroundStyle(Palette.muted)
            DisclosureGroup("Fine adjustment"){
                HStack(spacing:12){adjustment("Left",\.x);adjustment("Top",\.y)}
                HStack(spacing:12){adjustment("Width",\.width);adjustment("Height",\.height)}
            }.font(.system(size:11))
            if separate{Text("Uses stacked software output. The lower screen keeps mouse / touch input at its new position.").font(.system(size:10)).foregroundStyle(Palette.muted).fixedSize(horizontal:false,vertical:true)}
        }.task(id:asset.file){image=NSImage(contentsOf:dataRoot.appendingPathComponent(asset.file))}
    }
    private func setArea(_ area:SkinScreenArea,index:Int){if index==1{asset.secondaryScreen=area.fitted}else{asset.screen=area.fitted}}
    private func screenBox(_ index:Int,canvas:CGRect)->some View {
        let a=(index==1 ? asset.secondaryScreen ?? asset.screen:asset.screen).fitted
        let focused=index==selected
        return ZStack(alignment:.bottomTrailing){
            RoundedRectangle(cornerRadius:4).fill(Palette.mint.opacity(focused ? 0.20:0.08)).overlay(RoundedRectangle(cornerRadius:4).strokeBorder(focused ? Palette.mint:.white.opacity(0.6),lineWidth:focused ? 2:1))
            Text(separate ? index==0 ? "TOP":"TOUCH":"GAME").font(.system(size:9,weight:.bold)).foregroundStyle(Palette.mint).frame(maxWidth:.infinity,maxHeight:.infinity)
            RoundedRectangle(cornerRadius:3).fill(Palette.mint).frame(width:15,height:15).padding(2).contentShape(Rectangle()).highPriorityGesture(DragGesture(minimumDistance:0,coordinateSpace:.named("skinCanvas")).onChanged{value in
                selected=index;if resizeStart==nil{resizeStart=a};guard var next=resizeStart else{return};next.width=max(0.05,min(1-next.x,next.width+value.translation.width/max(1,canvas.width)));next.height=max(0.05,min(1-next.y,next.height+value.translation.height/max(1,canvas.height)));setArea(next,index:index)
            }.onEnded{_ in resizeStart=nil})
        }.frame(width:canvas.width*a.width,height:canvas.height*a.height).position(x:canvas.minX+canvas.width*(a.x+a.width/2),y:canvas.minY+canvas.height*(a.y+a.height/2))
            .gesture(DragGesture(minimumDistance:1,coordinateSpace:.named("skinCanvas")).onChanged{value in
                selected=index;if dragStart==nil{dragStart=a};guard var next=dragStart else{return};next.x += value.translation.width/max(1,canvas.width);next.y += value.translation.height/max(1,canvas.height);setArea(next,index:index)
            }.onEnded{_ in dragStart=nil})
            .onTapGesture{selected=index}.accessibilityLabel(separate ? index==0 ? "Top screen placement":"Touch screen placement":"Game screen placement")
    }
    private func adjustment(_ title:String,_ key:WritableKeyPath<SkinScreenArea,Double>)->some View {
        let binding=Binding<Double>(get:{area[keyPath:key]},set:{number in var next=area;next[keyPath:key]=number;setArea(next,index:selected)})
        return VStack(spacing:3){HStack{Text(title);Spacer();Text("\(Int(binding.wrappedValue*100))%").monospacedDigit()};Slider(value:binding,in:(title=="Width" || title=="Height") ? 0.05...1:0...0.95).tint(Palette.mint)}
    }
}
