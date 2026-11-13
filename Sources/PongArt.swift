import SwiftUI

struct PongArt: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors:[Color(hex:0x183D39),Color(hex:0x13302D),Color(hex:0x10211F)],startPoint:.topLeading,endPoint:.bottomTrailing)
                ForEach(0..<9) { i in Rectangle().fill(.white.opacity(0.08)).frame(width:2,height:8).position(x:g.size.width*0.7,y:CGFloat(i)*22) }
                RoundedRectangle(cornerRadius:2).fill(Palette.mint).frame(width:6,height:40).position(x:g.size.width*0.53,y:74)
                RoundedRectangle(cornerRadius:2).fill(Palette.coral).frame(width:6,height:40).position(x:g.size.width*0.90,y:109)
                Circle().fill(.white).frame(width:9,height:9).position(x:g.size.width*0.76,y:90)
                VStack(alignment:.leading,spacing:12) {
                    Text("NEXARC HOMEBREW").font(.system(size: 9,weight:.semibold)).tracking(1.5).foregroundStyle(Palette.mint)
                    Spacer()
                    Text("ORBIT\nPONG").font(.system(size: 29,weight:.black,design:.rounded)).tracking(-1).fixedSize(horizontal:false,vertical:true)
                    Text("A LITTLE FRIENDLY COMPETITION.").font(.system(size: 8,weight:.medium)).tracking(0.7).foregroundStyle(Palette.muted)
                }.padding(22).frame(maxWidth:.infinity,alignment:.leading)
            }.clipped()
        }
    }
}
