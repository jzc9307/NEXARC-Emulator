import AppKit
import UniformTypeIdentifiers


extension AppModel {
    func importSkin(for system:GameSystem) {
        let panel=NSOpenPanel();panel.title="Upload a skin for \(system.shortName)"
        panel.allowedContentTypes=[.png,.jpeg,.tiff,UTType.webP];panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let url=panel.url else{return}
        do {
            let size=(try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
            guard size>0 && size<=32*1024*1024 else{throw AppFailure.message("Choose a skin image smaller than 32 MB.")}
            let bytes=try Data(contentsOf:url)
            guard let bitmap=NSBitmapImageRep(data:bytes),bitmap.pixelsWide>0,bitmap.pixelsHigh>0,bitmap.pixelsWide<=8192,bitmap.pixelsHigh<=8192,
                  let png=bitmap.representation(using:.png,properties:[:]) else{throw AppFailure.message("Choose a readable image up to 8192 × 8192 pixels.")}
            var asset=CustomConsoleSkin(name:url.deletingPathExtension().lastPathComponent,file:"",imageAspect:Double(bitmap.pixelsWide)/Double(bitmap.pixelsHigh))
            asset.file="Skins/\(system.rawValue)/\(asset.id).png"
            let destination=dataRoot.appendingPathComponent(asset.file)
            try FileManager.default.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true)
            try png.write(to:destination,options:.atomic)
            var profile=saved.displays?[system.rawValue] ?? DisplayProfile.defaultProfile(for:system)
            if profile.customSkins==nil{profile.customSkins=[]};profile.customSkins?.append(asset)
            profile.selectedCustomSkin=asset.id;profile.skin = .custom
            if saved.displays==nil{saved.displays=[:]};saved.displays?[system.rawValue]=profile
            persist();notify("Skin added for \(system.shortName). Adjust its screen area in the preview.")
        }catch{self.error=error.localizedDescription}
    }
    func removeSkin(for system:GameSystem) {
        guard var profile=saved.displays?[system.rawValue],let asset=profile.customAsset else{return}
        // Uploaded artwork is a managed copy; the original image is kept at its source.
        let root=dataRoot.appendingPathComponent("Skins").standardizedFileURL.path+"/"
        let file=dataRoot.appendingPathComponent(asset.file).standardizedFileURL
        let usedByGame=saved.items.contains{($0.overrides?.display?.customSkins ?? []).contains{$0.file==asset.file}}
        let usedByConsole=(saved.displays ?? [:]).contains{key,value in key != system.rawValue && (value.customSkins ?? []).contains{$0.file==asset.file}}
        if file.path.hasPrefix(root) && !usedByGame && !usedByConsole{try? FileManager.default.removeItem(at:file)}
        profile.customSkins?.removeAll{$0.id==asset.id};profile.selectedCustomSkin=profile.customSkins?.first?.id
        if profile.customSkins?.isEmpty != false{profile.skin = DisplayProfile.defaultProfile(for:system).skin}
        saved.displays?[system.rawValue]=profile;persist()
        if usedByGame{notify("Removed from console defaults. Artwork is kept for games that use it.")}
    }
}

extension GameSystem {
    var shellColor:UInt32 {
        switch self {
        case .switchSystem:return 0x343A45;case .nds:return 0x8294AC;case .n3ds:return 0x327CBA
        case .gb:return 0xC7C8B1;case .gbc:return 0x7551A4;case .gba:return 0x6452A0
        case .psp:return 0x282D36;case .gameGear:return 0x353D4B
        case .nes:return 0xC6C2B9;case .snes:return 0xA79AB7;case .n64:return 0x384C40
        case .gamecube:return 0x655298;case .wii:return 0xD5E5EB
        case .genesis:return 0x292C35;case .masterSystem:return 0x54464A;case .dreamcast:return 0xCEC9C0
        case .saturn:return 0x454957;case .ps1:return 0xABB2B4;case .ps2:return 0x233C61
        case .pcEngine:return 0xD4C4A8;case .atari2600:return 0x8D6245
        }
    }
    var skinDesign:String {
        switch self {case .gb,.gbc:return "portrait";case .nds,.n3ds:return "dual";case .gba,.gameGear,.psp,.switchSystem:return "landscape";default:return "television"}
    }
}
