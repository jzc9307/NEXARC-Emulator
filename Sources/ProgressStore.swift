import Foundation
import CryptoKit

struct GameControllerBinding:Codable,Equatable {var player:Int;var deviceID:String;var profile:Data}
struct RetroPadMapping:Codable,Equatable {
    var buttons=Array(0..<16)
    static let labels=["B / bottom face","Y / left face","Select / −","Start / +","D-pad ↑","D-pad ↓","D-pad ←","D-pad →","A / right face","X / top face","L / L1","R / R1","ZL / L2","ZR / R2","Left stick click","Right stick click"]
}
struct GameOverrides:Codable,Equatable {
    var display:DisplayProfile?
    var keyboard:KeyboardMapping?
    var fastForwardSpeed:Int?
    var controllers:[GameControllerBinding]?
    var gamepad:RetroPadMapping?
}
struct SaveSlotInfo:Codable,Equatable,Identifiable {
    var slot:Int
    var date:Date
    var title:String
    var core:String
    var fingerprint:String
    var bytes:Int
    var checksum:String?
    var id:Int{slot}
}
struct SaveBackupInfo:Codable,Identifiable {
    var id:String
    var date:Date
    var reason:String
    var core:String
    var fingerprint:String
    var sourceName:String
    var sourceModified:Date
    var bytes:Int
    var checksum:String?
}

// This layer never launches a core. All replacement writes are atomic, and the
// source snapshot is copied before the destination changes.
struct ProgressStore {
    let root:URL
    static let slotCount=6
    static let backupLimit=10
    var slots:URL{root.appendingPathComponent("Save Slots")}
    var backups:URL{root.appendingPathComponent("Recovery Backups")}
    func state(_ slot:Int)->URL{slots.appendingPathComponent("slot-\(slot).state")}
    func thumbnail(_ slot:Int)->URL{state(slot).appendingPathExtension("png")}
    func info(_ slot:Int)->SaveSlotInfo?{guard (0..<Self.slotCount).contains(slot),let d=try? Data(contentsOf:slots.appendingPathComponent("slot-\(slot).json")) else{return nil};return try? JSONDecoder().decode(SaveSlotInfo.self,from:d)}
    func history()->[SaveBackupInfo] {
        let files=(try? FileManager.default.contentsOfDirectory(at:backups,includingPropertiesForKeys:nil)) ?? []
        return files.filter{$0.pathExtension=="json"}.compactMap{url in (try? Data(contentsOf:url)).flatMap{try? JSONDecoder().decode(SaveBackupInfo.self,from:$0)}}.sorted{$0.date>$1.date}
    }
    func backupFile(_ info:SaveBackupInfo)->URL{backups.appendingPathComponent(info.id+".state")}
    static func checksum(_ data:Data)->String{SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
    static func fingerprint(_ core:URL)throws->String {checksum(try Data(contentsOf:core,options:.mappedIfSafe))}
    static func copyAtomically(_ source:URL,to target:URL)throws {
        guard source.standardizedFileURL != target.standardizedFileURL else{return}
        let data=try Data(contentsOf:source,options:.mappedIfSafe)
        guard !data.isEmpty,data.count<=512*1024*1024 else{throw AppFailure.message("The save state is empty or too large to manage safely.")}
        try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:target,options:.atomic)
    }
    @discardableResult func backup(_ source:URL,reason:String,core:String,fingerprint:String)throws->SaveBackupInfo? {
        guard FileManager.default.fileExists(atPath:source.path) else{return nil}
        let attributes=try FileManager.default.attributesOfItem(atPath:source.path)
        let modified=attributes[.modificationDate] as? Date ?? .distantPast
        let size=(attributes[.size] as? NSNumber)?.intValue ?? 0
        if let last=history().first,last.sourceName==source.lastPathComponent,last.sourceModified==modified,last.bytes==size{return last}
        let id=UUID().uuidString,dest=backups.appendingPathComponent(id+".state")
        try Self.copyAtomically(source,to:dest)
        let snapshot=try Data(contentsOf:dest)
        let info=SaveBackupInfo(id:id,date:Date(),reason:reason,core:core,fingerprint:fingerprint,sourceName:source.lastPathComponent,sourceModified:modified,bytes:snapshot.count,checksum:Self.checksum(snapshot))
        let png=source.appendingPathExtension("png");if FileManager.default.fileExists(atPath:png.path){try Self.copyAtomically(png,to:dest.appendingPathExtension("png"))}
        try JSONEncoder().encode(info).write(to:backups.appendingPathComponent(info.id+".json"),options:.atomic)
        for old in history().dropFirst(Self.backupLimit){for ext in [".state",".state.png",".json"]{try FileManager.default.removeItemIfPresent(at:backups.appendingPathComponent(old.id+ext))}}
        return info
    }
    func store(_ source:URL,slot:Int,title:String,core:String,fingerprint:String)throws {
        guard (0..<Self.slotCount).contains(slot) else{throw AppFailure.message("Choose save slot 1–6.")}
        let target=state(slot)
        try backup(target,reason:"Before overwriting slot \(slot+1)",core:info(slot)?.core ?? core,fingerprint:info(slot)?.fingerprint ?? fingerprint)
        try Self.copyAtomically(source,to:target)
        let png=source.appendingPathExtension("png")
        if FileManager.default.fileExists(atPath:png.path){try Self.copyAtomically(png,to:thumbnail(slot))}else{try FileManager.default.removeItemIfPresent(at:thumbnail(slot))}
        let snapshot=try Data(contentsOf:target)
        let info=SaveSlotInfo(slot:slot,date:Date(),title:title,core:core,fingerprint:fingerprint,bytes:snapshot.count,checksum:Self.checksum(snapshot))
        try JSONEncoder().encode(info).write(to:slots.appendingPathComponent("slot-\(slot).json"),options:.atomic)
    }
    func validate(slot:Int,fingerprint:String)throws->URL {
        guard let saved=info(slot),FileManager.default.fileExists(atPath:state(slot).path) else{throw AppFailure.message("This save slot is empty.")}
        guard saved.fingerprint==fingerprint else{throw AppFailure.message("This snapshot was made with a different core build. Use the game's in-game save or the matching core version.")}
        let bytes=try Data(contentsOf:state(slot))
        guard !bytes.isEmpty,bytes.count==saved.bytes,saved.checksum.map({Self.checksum(bytes)==$0}) ?? true else{throw AppFailure.message("This snapshot is incomplete or damaged. Restore a recovery backup instead.")}
        return state(slot)
    }
}
private extension FileManager {func removeItemIfPresent(at url:URL)throws {if fileExists(atPath:url.path){try removeItem(at:url)}}}
