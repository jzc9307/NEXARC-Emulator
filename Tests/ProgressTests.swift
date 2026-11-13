import Foundation
@main struct ProgressTests {
 static func main()throws {
  func check(_ value:@autoclosure()->Bool,_ message:String){precondition(value(),message)}
  let root=FileManager.default.temporaryDirectory.appendingPathComponent("nexarc-progress-"+UUID().uuidString)
  defer{try? FileManager.default.removeItem(at:root)}
  try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
  let source=root.appendingPathComponent("source.state"),store=ProgressStore(root:root.appendingPathComponent("game"))
  try Data([1,2,3,4]).write(to:source)
  try store.store(source,slot:0,title:"First",core:"test",fingerprint:"core-A")
  let first=try Data(contentsOf:store.validate(slot:0,fingerprint:"core-A"));check(first==Data([1,2,3,4]),"Slot reads the copied bytes")
  try Data([8,9,10,11]).write(to:source)
  try store.store(source,slot:0,title:"Second",core:"test",fingerprint:"core-A")
  let history=store.history();check(history.count==1,"Overwrite creates recovery copy")
  let prior=try Data(contentsOf:store.backupFile(history[0]));check(prior==Data([1,2,3,4]),"Recovery copy preserves overwritten state")
  do{_ = try store.validate(slot:0,fingerprint:"core-B");fatalError("Different core build accepted")}catch{}
  do{try store.store(source,slot:9,title:"Bad",core:"test",fingerprint:"core-A");fatalError("Invalid slot accepted")}catch{}
  for n in 0..<15{let f=root.appendingPathComponent("source-\(n).state");try Data([UInt8(n),1]).write(to:f);try store.backup(f,reason:"Test",core:"test",fingerprint:"core-A")}
  check(store.history().count==ProgressStore.backupLimit,"Rolling history stays bounded")
  let latest=try Data(contentsOf:store.backupFile(store.history()[0]));check(latest==Data([14,1]),"Newest backup is retained")
  let empty=root.appendingPathComponent("empty.state");try Data().write(to:empty)
  do{try ProgressStore.copyAtomically(empty,to:store.state(0));fatalError("Empty state replaced a slot")}catch{}
  let retained=try Data(contentsOf:store.state(0));check(retained==Data([8,9,10,11]),"Failed write keeps existing slot")
  try Data([0,0,0,0]).write(to:store.state(0))
  do{_ = try store.validate(slot:0,fingerprint:"core-A");fatalError("Damaged state accepted")}catch{}
  let original=LibraryItem(title:"Game",path:"/game.nds",systemID:"nds")
  var custom=original;custom.overrides=GameOverrides(display:DisplayProfile(),keyboard:KeyboardMapping(),fastForwardSpeed:4,controllers:[GameControllerBinding(player:1,deviceID:"controller",profile:Data("{}".utf8))],gamepad:RetroPadMapping())
  let decoded=try JSONDecoder().decode(LibraryItem.self,from:JSONEncoder().encode(custom));check(decoded.overrides==custom.overrides,"Per-game settings survive restart")
  check(original.overrides==nil,"Another game keeps defaults")
  var skin=CustomConsoleSkin(name:"Dual",file:"a.png",imageAspect:1)
  skin.secondaryScreen=SkinScreenArea(x:0.2,y:0.55,width:0.6,height:0.4)
  let skinCopy=try JSONDecoder().decode(CustomConsoleSkin.self,from:JSONEncoder().encode(skin));check(skinCopy.secondaryScreen==skin.secondaryScreen,"Independent touch-screen placement persists")
  print("PASS: atomic save slots, overwrite backups, bounded recovery history, core compatibility checks, per-game settings, independent screen placement")
 }
}
