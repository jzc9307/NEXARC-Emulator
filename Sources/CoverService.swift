import Foundation
import AppKit

// ROMs and hashes never leave this Mac. Only the system and title are used
// to request public artwork. Cached images remain available offline.
actor CoverService {
    static let shared=CoverService()
    private var indices:[String:[String]]=[:]
    private var missed:Set<String>=[]
    static func repository(_ system:GameSystem)->String? {
        switch system{
        case .switchSystem:return nil
        case .nds:return "Nintendo_-_Nintendo_DS"
        case .n3ds:return "Nintendo_-_Nintendo_3DS"
        case .gb:return "Nintendo_-_Game_Boy"
        case .gbc:return "Nintendo_-_Game_Boy_Color"
        case .gba:return "Nintendo_-_Game_Boy_Advance"
        case .nes:return "Nintendo_-_Nintendo_Entertainment_System"
        case .snes:return "Nintendo_-_Super_Nintendo_Entertainment_System"
        case .n64:return "Nintendo_-_Nintendo_64"
        case .gamecube:return "Nintendo_-_GameCube"
        case .wii:return "Nintendo_-_Wii"
        case .genesis:return "Sega_-_Mega_Drive_-_Genesis"
        case .masterSystem:return "Sega_-_Master_System_-_Mark_III"
        case .gameGear:return "Sega_-_Game_Gear"
        case .dreamcast:return "Sega_-_Dreamcast"
        case .saturn:return "Sega_-_Saturn"
        case .ps1:return "Sony_-_PlayStation"
        case .ps2:return "Sony_-_PlayStation_2"
        case .psp:return "Sony_-_PlayStation_Portable"
        case .pcEngine:return "NEC_-_PC_Engine_-_TurboGrafx_16"
        case .atari2600:return "Atari_-_2600"
        }
    }
    private static func normalized(_ value:String)->String {
        value.replacingOccurrences(of:#"\s*[\(\[].*?[\)\]]"#,with:"",options:.regularExpression).folding(options:[.diacriticInsensitive,.caseInsensitive],locale:Locale(identifier:"en_US_POSIX")).filter{$0.isLetter||$0.isNumber}
    }
    private func download(_ url:URL) async -> Data? {
        var request=URLRequest(url:url);request.timeoutInterval=15;request.setValue("NEXARC-Cover/0.3",forHTTPHeaderField:"User-Agent")
        guard let (d,r)=try? await URLSession.shared.data(for:request),let response=r as? HTTPURLResponse,response.statusCode==200,d.count<=8_000_000 else{return nil};return d
    }
    func fetch(_ item:LibraryItem,folder:URL,retry:Bool=false) async -> URL? {
        guard !item.isBundled,let repo=Self.repository(item.system) else{return nil}
        let key=item.system.rawValue+":"+item.title
        if missed.contains(key) && !retry{return nil}
        try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let target=folder.appendingPathComponent(item.id.uuidString+"-auto.png")
        if FileManager.default.fileExists(atPath:target.path){return target}
        func url(_ name:String)->URL {URL(string:"https://raw.githubusercontent.com/libretro-thumbnails/\(repo)/master/Named_Boxarts/")!.appendingPathComponent(name)}
        var data=await download(url(item.title+".png"))
        if data == nil {
            if indices[repo] == nil {
                let cache=folder.appendingPathComponent(repo+"-index.json")
                var indexData=try? Data(contentsOf:cache)
                if indexData==nil {
                    indexData=await download(URL(string:"https://api.github.com/repos/libretro-thumbnails/\(repo)/git/trees/master?recursive=1")!)
                    if let indexData {try? indexData.write(to:cache,options:.atomic)}
                }
                if let indexData,let json=try? JSONSerialization.jsonObject(with:indexData) as? [String:Any],let tree=json["tree"] as? [[String:Any]] {
                    indices[repo]=tree.compactMap{$0["path"] as? String}.filter{$0.hasPrefix("Named_Boxarts/")&&$0.hasSuffix(".png")}.map{String($0.dropFirst("Named_Boxarts/".count))}
                }
            }
            let wanted=Self.normalized(item.title)
            let matches=(indices[repo] ?? []).filter{Self.normalized(String($0.dropLast(4)))==wanted}
            // Prefer the matching region, then English releases; never fuzzy-match
            // a similarly named sequel to avoid silently assigning the wrong art.
            let best=matches.sorted{a,b in
                func score(_ v:String)->Int{var n=0;if item.title.contains("USA")&&v.contains("USA"){n+=10};if item.title.contains("Europe")&&v.contains("Europe"){n+=5};if v.contains("USA"){n+=2};return n}
                return score(a)==score(b) ? a<b:score(a)>score(b)
            }.first
            if let best{data=await download(url(best))}
        }
        guard let data,let image=NSBitmapImageRep(data:data),image.pixelsWide>8,image.pixelsHigh>8,let png=image.representation(using:.png,properties:[:]) else{missed.insert(key);return nil}
        do{try png.write(to:target,options:.atomic);return target}catch{return nil}
    }
}
extension AppModel {
    func refreshCovers(retry:Bool=false) {
        for item in saved.items where !item.isBundled && item.coverPath==nil {fetchCover(item,retry:retry)}
    }
    func fetchCover(_ item:LibraryItem,retry:Bool=false) {
        guard !coverLoading.contains(item.id) else{return}
        coverLoading.insert(item.id)
        Task{@MainActor [weak self] in
            guard let self else{return}
            let url=await CoverService.shared.fetch(item,folder:self.dataRoot.appendingPathComponent("Covers"),retry:retry)
            self.coverLoading.remove(item.id)
            if let url,let i=self.saved.items.firstIndex(where:{$0.id==item.id}),self.saved.items[i].coverPath==nil{self.saved.items[i].coverPath=url.path;self.persist()}
            else if retry && url==nil{self.notify("No exact cover match found. You can choose your own image in Game tools.")}
        }
    }
}
