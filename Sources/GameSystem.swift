import Foundation

// A system is library metadata, not a promise that every title will work.
// Keep these stable IDs: saves and existing library entries refer to them.
enum GameSystem: String, CaseIterable, Identifiable, Codable {
    case switchSystem = "switch", n3ds, nds, gb, gbc, gba, nes, snes, n64, gamecube, wii
    case genesis, masterSystem, gameGear, dreamcast, saturn, ps1, ps2, psp, pcEngine, atari2600
    var id: String { rawValue }
    var name: String {
        switch self {
        case .switchSystem: return "Nintendo Switch"
        case .n3ds: return "Nintendo 3DS"
        case .nds: return "Nintendo DS"
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .n64: return "Nintendo 64"
        case .gamecube: return "Nintendo GameCube"
        case .wii: return "Nintendo Wii"
        case .genesis: return "Sega Mega Drive"
        case .masterSystem: return "Sega Master System"
        case .gameGear: return "Sega Game Gear"
        case .dreamcast: return "Sega Dreamcast"
        case .saturn: return "Sega Saturn"
        case .ps1: return "PlayStation"
        case .ps2: return "PlayStation 2"
        case .psp: return "PlayStation Portable"
        case .pcEngine: return "PC Engine"
        case .atari2600: return "Atari 2600"
        }
    }
    var shortName: String {
        switch self { case .switchSystem: return "Switch"; case .nes: return "NES"; case .psp: return "PSP"; case .masterSystem: return "Master System"; default: return name.replacingOccurrences(of:"Nintendo ",with:"").replacingOccurrences(of:"Sega ",with:"") }
    }
    var maker: String {
        switch self { case .genesis,.masterSystem,.gameGear,.dreamcast,.saturn: return "SEGA"; case .ps1,.ps2,.psp: return "SONY"; case .pcEngine: return "NEC"; case .atari2600: return "ATARI"; default: return "NINTENDO" }
    }
    var year: String {
        switch self { case .switchSystem:return "2017";case .n3ds:return "2011";case .nds:return "2004";case .gb:return "1989";case .gbc:return "1998";case .gba:return "2001";case .nes:return "1983";case .snes:return "1990";case .n64:return "1996";case .gamecube:return "2001";case .wii:return "2006";case .genesis:return "1988";case .masterSystem:return "1985";case .gameGear:return "1990";case .dreamcast:return "1998";case .saturn:return "1994";case .ps1:return "1994";case .ps2:return "2000";case .psp:return "2004";case .pcEngine:return "1987";case .atari2600:return "1977" }
    }
    var color: UInt32 {
        switch self {case .switchSystem:return 0xFF8F86;case .n3ds:return 0x73D4FA;case .nds:return 0xB9C9EB;case .gb:return 0xCBE88F;case .gbc:return 0xD0A0FF;case .gba:return 0xADA1FF;case .nes:return 0xEF8F89;case .snes:return 0xBDA9F5;case .n64:return 0x70D4A4;case .gamecube:return 0xB3A2FF;case .wii:return 0x9CEBFF;case .genesis:return 0x7EB5FF;case .masterSystem:return 0xEF9A9A;case .gameGear:return 0x76D4DC;case .dreamcast:return 0xFFB27C;case .saturn:return 0xA3A9FF;case .ps1:return 0xABD6E2;case .ps2:return 0x709EFF;case .psp:return 0x9FC2DD;case .pcEngine:return 0xEDB889;case .atari2600:return 0xD9AE83}
    }
    var tagline: String {
        switch self {case .gb,.gbc:return "Small screen. Endless possibility.";case .gba:return "A pocket full of adventures.";case .n3ds:return "Two screens. Another dimension.";case .nds:return "A different way to play.";case .switchSystem:return "Your next escape.";case .nes,.snes:return "The games that started it all.";case .n64,.gamecube:return "A new dimension of play.";case .ps1,.ps2:return "Great stories live here.";case .psp:return "Big adventures. Anywhere.";default:return "A classic world, rediscovered."}
    }
    var family: String { [.n3ds,.nds,.gb,.gbc,.gba,.gameGear,.psp].contains(self) ? "Handhelds" : "Home consoles" }
    var core: String? {
        switch self {case .switchSystem:return nil;case .gb,.gbc:return "gambatte";case .gba:return "mgba";case .nes:return "fceumm";case .snes:return "snes9x";case .n64:return "parallel_n64";case .nds:return "melondsds";case .n3ds:return "azahar";case .gamecube,.wii:return "dolphin";case .genesis,.masterSystem,.gameGear:return "genesis_plus_gx";case .dreamcast:return "flycast";case .saturn:return "mednafen_saturn";case .ps1:return "pcsx_rearmed";case .ps2:return "play";case .psp:return "ppsspp";case .pcEngine:return "mednafen_pce_fast";case .atari2600:return "stella"}
    }
    var engineLabel: String {
        switch self {case .switchSystem:return "Ryujinx-derived";case .gb,.gbc:return "Gambatte";case .gba:return "mGBA";case .nes:return "FCEUmm";case .snes:return "Snes9x";case .n64:return "ParaLLEl N64";case .nds:return "melonDS DS";case .n3ds:return "Azahar";case .gamecube,.wii:return "Dolphin";case .genesis,.masterSystem,.gameGear:return "Genesis Plus GX";case .dreamcast:return "Flycast";case .saturn:return "Beetle Saturn";case .ps1:return "PCSX ReARMed";case .ps2:return "Play! · Experimental";case .psp:return "PPSSPP";case .pcEngine:return "Beetle PCE Fast";case .atari2600:return "Stella"}
    }
    var extensions: [String] {
        switch self {case .switchSystem:return ["nro","nso","nsp","xci","nca"];case .gb:return ["gb"];case .gbc:return ["gbc"];case .gba:return ["gba"];case .nes:return ["nes","unf","unif"];case .snes:return ["sfc","smc"];case .n64:return ["n64","z64","v64"];case .nds:return ["nds"];case .n3ds:return ["3ds","3dsx","cci","cxi"];case .gamecube:return ["iso","gcm","rvz","dol"];case .wii:return ["iso","wbfs","rvz"];case .genesis:return ["md","gen","smd","bin"];case .masterSystem:return ["sms"];case .gameGear:return ["gg"];case .dreamcast:return ["gdi","cdi","chd"];case .saturn:return ["cue","chd"];case .ps1:return ["cue","chd","pbp","bin"];case .ps2:return ["iso","chd"];case .psp:return ["iso","cso","pbp"];case .pcEngine:return ["pce"];case .atari2600:return ["a26","bin"]}
    }
    static func detect(_ path: String) -> [GameSystem] { let ext=URL(fileURLWithPath:path).pathExtension.lowercased();return allCases.filter{$0.extensions.contains(ext)} }
    var supportsStates: Bool { self != .switchSystem }
    var supportsCheats: Bool { ![.switchSystem,.n3ds,.gamecube,.wii,.ps2].contains(self) }
    var supportsPatches: Bool { [.gb,.gbc,.gba,.nes,.snes,.n64,.genesis,.masterSystem,.gameGear,.pcEngine,.atari2600].contains(self) }
    var requirement: String {
        switch self {case .switchSystem:return "Encrypted games need your console keys and firmware. Switch support is preserved.";case .n3ds:return "Use decrypted games or homebrew. Software graphics is the default for stability; performance varies. Some titles need system files from your 3DS.";case .ps1:return "For best compatibility, add your PlayStation BIOS to the System Files folder.";case .saturn:return "Requires your Saturn BIOS in System Files. Disc games must include all referenced tracks.";case .ps2:return "Experimental Play! core. Performance and game compatibility vary substantially.";case .gamecube,.wii:return "Dolphin core. Wii games may need additional system data and controller setup.";case .dreamcast:return "Some games require your Dreamcast BIOS in System Files/dc.";default:return "Import your game files. Saves stay on this Mac, separately from your ROMs."}
    }
}
