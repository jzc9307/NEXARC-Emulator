import Foundation

@main struct SuiteTests {
 static func main() throws {
  func check(_ condition:@autoclosure()->Bool,_ message:String){precondition(condition(),message)}
  check(GameSystem.allCases.count==21,"21 stable console IDs")
  check(GameSystem.detect("test.gba")==[.gba],"GBA detection")
  check(GameSystem.detect("test.3ds")==[.n3ds],"3DS detection")
  check(GameSystem.detect("test.iso").count>1,"Disc formats require console selection")
  let legacy=Data(#"{"id":"7B772050-03B5-420F-AB3F-F3CC6FE65FB8","title":"Keep me","path":"/old/game.xci","favorite":true,"playSeconds":42,"isDiagnostic":false}"#.utf8)
  let old=try JSONDecoder().decode(LibraryItem.self,from:legacy)
  check(old.system == .switchSystem && old.favorite && old.playSeconds==42,"Existing Switch libraries survive migration")
  let a=LibraryItem(title:"Same",path:"/a/Same.gb",systemID:"gb"),b=LibraryItem(title:"Same",path:"/b/Same.gb",systemID:"gb")
  check(RetroRuntime.saves(a,dataRoot:URL(fileURLWithPath:"/tmp/test")) != RetroRuntime.saves(b,dataRoot:URL(fileURLWithPath:"/tmp/test")),"Same-name games have isolated saves")
  let oldState=Data(#"{"items":[],"sessions":[],"preferences":{"resolution":1,"docked":false,"fullscreen":false,"hypervisor":true,"volume":0.8,"showIntro":true}}"#.utf8)
  let migrated=try JSONDecoder().decode(SavedState.self,from:oldState)
  check(migrated.displays==nil && migrated.keyboard==nil,"Optional player settings preserve old library")
  let name=LibraryItem(title:"Pokemon - White Version (USA, Europe) (NDSi Enhanced)",path:"/x.nds")
  check(name.displayTitle=="Pokemon: White Version","Region tags remain metadata, not display clutter")
  var display=DisplayProfile();display.layout = .sideBySide
  check(display.layout.dsValue=="left-right" && display.aspect(.nds)>2.6,"DS horizontal layout uses both screens")
  var window=DisplayProfile();check(window.selectedWindowPreset == .standard,"Existing default window selects Standard")
  window.applyWindowPreset(.small);check(window.windowWidth==800 && window.windowHeight==600,"Small preset applies both dimensions")
  window.applyWindowPreset(.fitDisplay,availableWidth:1440,availableHeight:900);check(window.windowWidth==1360 && window.windowHeight==820,"Fit respects display margins")
  window.applyWindowPreset(.custom);check(window.windowWidth==1360 && window.windowHeight==820,"Custom keeps existing dimensions")
  let restoredWindow=try JSONDecoder().decode(DisplayProfile.self,from:JSONEncoder().encode(window));check(restoredWindow.selectedWindowPreset == .custom,"Explicit custom selection persists")
  let fixture=FileManager.default.temporaryDirectory.appendingPathComponent("nexarc-config-test-"+UUID().uuidString)
  defer{try? FileManager.default.removeItem(at:fixture)}
  let helper=fixture.appendingPathComponent("Contents/Helpers/RetroArch.app/Contents/MacOS/RetroArch"),core=fixture.appendingPathComponent("Contents/Resources/Cores/melondsds_libretro.dylib")
  for file in [helper,core]{try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true);try Data().write(to:file)}
  try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:helper.path)
  let game=LibraryItem(title:"Test",path:"/local/Test.nds",systemID:"nds")
  var keys=KeyboardMapping();keys.bindings["a"]="c"
  _=try RetroRuntime(bundle:fixture).prepare(game,dataRoot:fixture,preferences:Preferences(),resume:false,commandPort:55555,display:display,keyboard:keys)
  let cfg=try String(contentsOf:RetroRuntime.gameRoot(game,dataRoot:fixture).appendingPathComponent("session.cfg"),encoding:.utf8)
  check(cfg.contains("audio_sync = \"false\""),"A stopped audio route cannot block the emulation loop")
  check(cfg.contains("global_core_options = \"true\""),"Use the actual upstream global-options setting; otherwise layouts silently stay at defaults")
  check(cfg.contains("input_exit_emulator = \"nul\"") && cfg.contains("input_player1_a = \"c\""),"Escape is reserved for our menu and custom bindings reach the core")
  let coreCfg=try String(contentsOf:RetroRuntime.gameRoot(game,dataRoot:fixture).appendingPathComponent("core-options.cfg"),encoding:.utf8)
  check(coreCfg.contains("melonds_screen_layout1 = \"left-right\""),"DS layout reaches the selected core")
  var custom=CustomConsoleSkin(name:"My DS",file:"Skins/nds/test.png",imageAspect:1.5)
  custom.screen=SkinScreenArea(x:0.9,y:0.95,width:0.7,height:0.6).fitted
  check(custom.screen.x+custom.screen.width<=1 && custom.screen.y+custom.screen.height<=1,"Custom screen area stays inside the image")
  var customProfile=DisplayProfile();customProfile.customSkins=[custom];customProfile.selectedCustomSkin=custom.id;customProfile.skin = .custom
  let restored=try JSONDecoder().decode(DisplayProfile.self,from:JSONEncoder().encode(customProfile))
  check(restored.customAsset==custom && restored.skin == .custom,"Uploaded skin and screen placement survive restart")
  let profiles=["nds":customProfile,"gba":DisplayProfile()]
  check(profiles["nds"]?.customAsset != nil && profiles["gba"]?.customAsset == nil,"Console skin collections are independent")
  let ips=Data([UInt8]("PATCH".utf8)+[0,0,1,0,2,9,8]+[UInt8]("EOF".utf8))
  let ipsResult=try ROMPatch.apply(source:Data([1,2,3,4]),patch:ips)
  check(ipsResult==Data([1,9,8,4]),"IPS overwrite")
  let rle=Data([UInt8]("PATCH".utf8)+[0,0,4,0,0,0,3,7]+[UInt8]("EOF".utf8))
  let rleResult=try ROMPatch.apply(source:Data([1]),patch:rle)
  check(rleResult==Data([1,0,0,0,7,7,7]),"IPS expansion and RLE")
  func varint(_ value:Int)->[UInt8]{var v=value,out=[UInt8]();while true{let x=v&127;v>>=7;if v==0{out.append(UInt8(x|128));return out};out.append(UInt8(x));v-=1}}
  func le(_ v:UInt32)->[UInt8]{(0..<4).map{UInt8(truncatingIfNeeded:v>>($0*8))}}
  let source:[UInt8]=[1,2,3,4],target:[UInt8]=[1,2,9,8]
  var bps=[UInt8]("BPS1".utf8)+varint(4)+varint(4)+varint(0)
  bps += varint(4) // SourceRead two bytes.
  bps += varint(5)+[9,8] // TargetRead two bytes.
  bps += le(ROMPatch.crc(source))+le(ROMPatch.crc(target));bps += le(ROMPatch.crc(bps))
  let bpsResult=try ROMPatch.apply(source:Data(source),patch:Data(bps))
  check(bpsResult==Data(target),"BPS actions and checksums")
  do{_ = try ROMPatch.apply(source:Data([0,2,3,4]),patch:Data(bps));fatalError("Wrong source accepted")}catch{}
  for malformed in [Data(),Data("PATCH".utf8),Data("BPS1".utf8),Data([UInt8]("PATCH".utf8)+[0,0,0,0,4,1])] {
   do{_ = try ROMPatch.apply(source:Data(source),patch:malformed);fatalError("Malformed patch accepted")}catch{}
  }
  check(ROMPatch.crc(Array("123456789".utf8))==0xCBF43926,"Known CRC32 vector")
  print("Suite tests passed: routing, legacy library, isolated saves, IPS, BPS, corrupted input.")
 }
}
