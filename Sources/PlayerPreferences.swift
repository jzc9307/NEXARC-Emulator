import Foundation

// Coordinates are fractions of the uploaded image, measured from its top left.
struct SkinScreenArea:Codable,Equatable {
    var x=0.10, y=0.10, width=0.80, height=0.80
    var fitted:Self {
        var area=self
        area.width=max(0.05,min(1,width));area.height=max(0.05,min(1,height))
        area.x=max(0,min(1-area.width,x));area.y=max(0,min(1-area.height,y))
        return area
    }
}
struct CustomConsoleSkin:Codable,Equatable,Identifiable {
    var id=UUID().uuidString
    var name:String
    var file:String
    var imageAspect:Double
    var screen=SkinScreenArea()
    var secondaryScreen:SkinScreenArea?
}


// Optional fields in SavedState keep pre-NEXARC libraries readable.
enum ScreenLayout:String,Codable,CaseIterable,Identifiable {
    case stacked="Stacked",sideBySide="Side by side",largeTop="Large top screen",largeBottom="Large touch screen",topOnly="Top screen only",bottomOnly="Touch screen only"
    var id:String{rawValue}
    var dsValue:String {switch self{case .stacked:return "top-bottom";case .sideBySide:return "left-right";case .largeTop:return "largescreen-top";case .largeBottom:return "largescreen-bottom";case .topOnly:return "top";case .bottomOnly:return "bottom"}}
    var citraValue:String {switch self{case .stacked:return "default";case .sideBySide:return "side_by_side";case .largeTop,.largeBottom:return "large_screen";case .topOnly,.bottomOnly:return "single_screen"}}
}
enum ConsoleSkin:String,Codable,CaseIterable,Identifiable {case none="Screen only",classic="Classic shell",neon="Neon shell",custom="Uploaded skin",hardware="Console hardware";var id:String{rawValue}}
enum WindowSizePreset:String,Codable,CaseIterable,Identifiable {
    case small,standard,large,fitDisplay,custom
    var id:String{rawValue}
    var label:String{switch self{case .small:return "Small · 800 × 600";case .standard:return "Standard · 1100 × 760";case .large:return "Large · 1440 × 900";case .fitDisplay:return "Fit to display";case .custom:return "Custom size…"}}
}
struct DisplayProfile:Codable,Equatable {
    var windowPreset:WindowSizePreset?
    var customSkins:[CustomConsoleSkin]?
    var selectedCustomSkin:String?
    var customAsset:CustomConsoleSkin?{customSkins?.first{$0.id==selectedCustomSkin} ?? customSkins?.first}
    var layout:ScreenLayout = .stacked
    var skin:ConsoleSkin = .none
    var sizing="Fit"
    var windowWidth=1100
    var windowHeight=760
    var fullscreen=false
    var smooth=false
    var gap=0
    var effectiveGap:Int{if skin == .custom && customAsset?.secondaryScreen != nil{return 0};return skin == .none ? gap:max(16,gap)}
    func aspect(_ system:GameSystem)->Double {
        if [.nds,.n3ds].contains(system){switch layout{case .stacked:return system == .nds ? 256.0/Double(384+effectiveGap):400.0/480;case .sideBySide:return system == .nds ? 512.0/192:720.0/240;case .largeTop:return system == .nds ? 768.0/384:1120.0/480;case .largeBottom:return system == .nds ? 768.0/384:1040.0/480;case .topOnly:return system == .nds ? 4.0/3:5.0/3;case .bottomOnly:return 4.0/3}}
        switch system{case .gb,.gbc:return 160.0/144;case .gba:return 1.5;case .psp,.switchSystem:return 16.0/9;case .gameGear:return 160.0/144;default:return 4.0/3}
    }
}
struct KeyboardMapping:Codable,Equatable {
    var bindings:[String:String]=["up":"up","down":"down","left":"left","right":"right","a":"x","b":"z","x":"s","y":"a","l":"q","r":"w","l2":"1","r2":"2","l3":"3","r3":"4","start":"enter","select":"rshift"]
    static let actions:[(String,String)]=[("up","D-pad ↑"),("down","D-pad ↓"),("left","D-pad ←"),("right","D-pad →"),("a","A / right face"),("b","B / bottom face"),("x","X / top face"),("y","Y / left face"),("l","L / L1"),("r","R / R1"),("l2","ZL / L2"),("r2","ZR / R2"),("l3","Left stick click"),("r3","Right stick click"),("start","Start / +"),("select","Select / −")]
    static let keys=Array("abcdefghijklmnopqrstuvwxyz").map(String.init)+Array(0...9).map(String.init)+["up","down","left","right","enter","rshift","lshift","backspace","nul"]
    static func label(_ key:String)->String {switch key{case "up":return "↑";case "down":return "↓";case "left":return "←";case "right":return "→";case "enter":return "Return";case "rshift":return "Right Shift";case "lshift":return "Left Shift";case "nul":return "Unbound";default:return key.uppercased()}}
}


struct HardwareSkinCatalog {
    static let assets:[String:CustomConsoleSkin] = {
        guard let url=Bundle.main.url(forResource:"catalog",withExtension:"json",subdirectory:"Skins/Hardware"),let data=try? Data(contentsOf:url) else{return [:]}
        return (try? JSONDecoder().decode([String:CustomConsoleSkin].self,from:data)) ?? [:]
    }()
    static func asset(for system:GameSystem)->CustomConsoleSkin?{assets[system.rawValue]}
    static func image(for asset:CustomConsoleSkin)->URL{Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Skins/Hardware").appendingPathComponent(asset.file)}
}
extension DisplayProfile {
    static func defaultProfile(for system:GameSystem)->Self {var p=Self();p.skin=HardwareSkinCatalog.asset(for:system) == nil ? .none:.hardware;return p}
}

extension DisplayProfile {
    var selectedWindowPreset:WindowSizePreset {
        if let windowPreset{return windowPreset}
        switch (windowWidth,windowHeight){case (800,600):return .small;case (1100,760):return .standard;case (1440,900):return .large;default:return .custom}
    }
    mutating func applyWindowPreset(_ preset:WindowSizePreset,availableWidth:Int=1280,availableHeight:Int=800){
        windowPreset=preset
        switch preset {
        case .small:windowWidth=800;windowHeight=600
        case .standard:windowWidth=1100;windowHeight=760
        case .large:windowWidth=1440;windowHeight=900
        case .fitDisplay:windowWidth=max(480,min(3840,availableWidth-80));windowHeight=max(360,min(2160,availableHeight-80))
        case .custom:break
        }
    }
}
