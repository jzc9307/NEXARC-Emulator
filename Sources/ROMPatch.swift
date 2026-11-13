import Foundation

// IPS and BPS patch data are interpreted as bytes, never executed as programs.
enum ROMPatch {
    static let limit=256 * 1024 * 1024
    static func apply(source:Data,patch:Data)throws->Data {
        guard source.count <= limit,patch.count <= 32*1024*1024 else {throw AppFailure.message("This patch tool supports ROMs up to 256 MB and patches up to 32 MB.")}
        let p=[UInt8](patch),s=[UInt8](source)
        if p.starts(with:Array("PATCH".utf8)) {return try ips(s,p)}
        if p.starts(with:Array("BPS1".utf8)) {return try bps(s,p)}
        throw AppFailure.message("Choose a valid IPS or BPS patch.")
    }
    static func crc(_ data:[UInt8])->UInt32 {
        var crc:UInt32=0xFFFFFFFF
        for b in data {crc ^= UInt32(b);for _ in 0..<8 {crc=(crc>>1) ^ (crc&1 == 1 ? 0xEDB88320:0)}}
        return ~crc
    }
    private static func ips(_ source:[UInt8],_ p:[UInt8])throws->Data {
        var output=source,i=5
        func number(_ count:Int)throws->Int {guard i+count<=p.count else {throw AppFailure.message("Truncated IPS patch.")};var v=0;for _ in 0..<count {v=v*256+Int(p[i]);i+=1};return v}
        while true {
            let offset=try number(3)
            if offset==0x454F46 {
                if p.count-i==3 {let size=try number(3);if size<output.count {output.removeLast(output.count-size)}else {output += repeatElement(0,count:size-output.count)}}
                guard i==p.count else {throw AppFailure.message("Unexpected data after the IPS footer.")};return Data(output)
            }
            let size=try number(2);let bytes:[UInt8]
            if size==0 {let count=try number(2),value=try number(1);bytes=Array(repeating:UInt8(value),count:count)}
            else {guard i+size<=p.count else {throw AppFailure.message("Truncated IPS record.")};bytes=Array(p[i..<i+size]);i+=size}
            guard offset+bytes.count<=limit else {throw AppFailure.message("Patched ROM exceeds the size limit.")}
            if output.count<offset+bytes.count {output += repeatElement(0,count:offset+bytes.count-output.count)}
            output.replaceSubrange(offset..<offset+bytes.count,with:bytes)
        }
    }
    private static func bps(_ source:[UInt8],_ p:[UInt8])throws->Data {
        guard p.count>=16 else {throw AppFailure.message("Truncated BPS patch.")}
        func le(_ offset:Int)->UInt32 {UInt32(p[offset]) | UInt32(p[offset+1])<<8 | UInt32(p[offset+2])<<16 | UInt32(p[offset+3])<<24}
        guard crc(Array(p.dropLast(4)))==le(p.count-4),crc(source)==le(p.count-12) else {throw AppFailure.message("BPS checksum mismatch. This patch may require a different version of the original ROM.")}
        var i=4
        func number()throws->Int {
            var result=0,shift=1
            for _ in 0..<8 {
                guard i<p.count-12 else {throw AppFailure.message("Truncated BPS command.")};let x=Int(p[i]);i+=1
                guard shift <= Int.max/256, result <= Int.max-shift*128 else {throw AppFailure.message("Invalid BPS number.")}
                result += (x&127)*shift;if x&128 != 0 {return result};shift <<= 7;result += shift
            };throw AppFailure.message("Invalid BPS number.")
        }
        let sourceSize=try number(),targetSize=try number(),metadata=try number()
        guard sourceSize==source.count,targetSize<=limit,metadata<=p.count-12-i else {throw AppFailure.message("BPS patch does not match this ROM, or has invalid lengths.")}
        i+=metadata;var output=[UInt8]();output.reserveCapacity(targetSize);var sourceOffset=0,targetOffset=0
        while output.count<targetSize {
            let command=try number(),mode=command&3,length=(command>>2)+1
            guard length<=targetSize-output.count else {throw AppFailure.message("BPS write exceeds the target ROM.")}
            switch mode {
            case 0:
                guard output.count+length<=source.count else {throw AppFailure.message("BPS source read is out of bounds.")};output += source[output.count..<output.count+length]
            case 1:
                guard length<=p.count-12-i else {throw AppFailure.message("Truncated BPS target data.")};output += p[i..<i+length];i+=length
            case 2,3:
                let encoded=try number(),delta=(encoded&1 == 1 ? -1:1)*(encoded>>1)
                if mode==2 {
                    sourceOffset += delta
                    guard sourceOffset>=0,sourceOffset<=source.count,length<=source.count-sourceOffset else {throw AppFailure.message("BPS source copy is out of bounds.")};output += source[sourceOffset..<sourceOffset+length];sourceOffset+=length
                } else {
                    targetOffset += delta
                    guard targetOffset>=0,targetOffset<output.count else {throw AppFailure.message("BPS target copy is out of bounds.")}
                    for _ in 0..<length {guard targetOffset<output.count else {throw AppFailure.message("Invalid BPS overlapping copy.")};output.append(output[targetOffset]);targetOffset+=1}
                }
            default:break
            }
        }
        guard i==p.count-12,crc(output)==le(p.count-8) else {throw AppFailure.message("Patched ROM failed its BPS checksum.")}
        return Data(output)
    }
}
