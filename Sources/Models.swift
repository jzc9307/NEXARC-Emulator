import Foundation

// These names are shared with the offline model reader reused from Dockside.
enum Console: String, CaseIterable { case switchOriginal, switch2, ps5, ps4, xbox
    var name: String { self == .switchOriginal ? "Nintendo Switch" : rawValue }
}

struct LibraryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var path: String
    var favorite = false
    var lastPlayed: Date?
    var playSeconds: Double = 0
    var coverPath: String?
    var isDiagnostic = false
    var bundledName: String?
    var systemID: String?
    var patchedFrom: String?
    var cheatPath: String?
    var overrides: GameOverrides?
    var system: GameSystem { GameSystem(rawValue: systemID ?? "") ?? GameSystem.detect(path).first ?? .switchSystem }
    var displayTitle: String {
        title.replacingOccurrences(of: #"\s*[\(\[].*?[\)\]]"#, with: "", options: .regularExpression).replacingOccurrences(of:" - ",with:": ").trimmingCharacters(in:.whitespaces)
    }
    var isBundled: Bool { isDiagnostic || bundledName != nil }
    var format: String { URL(fileURLWithPath: path).pathExtension.uppercased() }
}

struct SessionRecord: Identifiable, Codable {
    var id = UUID()
    var itemID: UUID?
    var title: String
    var started: Date
    var duration: Double
    var exitCode: Int32
    var verifiedDiagnostic: Bool
    var stoppedByUser: Bool
    var logPath: String
}

struct Preferences: Codable, Equatable {
    var resolution = 1
    var docked = false
    var fullscreen = false
    var hypervisor = true
    var volume = 0.8
    var showIntro = true
    var discordClientID: String?
    var discordPresenceEnabled: Bool?
}

struct SavedState: Codable {
    var items: [LibraryItem] = []
    var sessions: [SessionRecord] = []
    var displays: [String:DisplayProfile]?
    var keyboard: KeyboardMapping?
    var fastForwardSpeed:Int?
    var preferences = Preferences()
}

// Pure launch planning is kept separate from Process so we can test it.
enum LaunchPlan {
    static func arguments(file: String, root: String, preferences: Preferences, diagnostic: Bool) -> [String] {
        var args = ["--no-gui", "--hide-cursor", "Never", "--root-data-dir", root,
                    "--graphics-backend", "Vulkan", "--resolution-scale", String(preferences.resolution),
                    "--audio-volume", String(preferences.volume),
                    "--use-hypervisor", preferences.hypervisor ? "true" : "false"]
        // The built-in test uses no controller. Other homebrew can use the core's saved profiles.
        if diagnostic { args += ["--disable-main-input-config", "--backend-threading", "Off"] }
        else { args += ["--use-main-config"] }
        args += ["--docked-mode", preferences.docked ? "true" : "false"]
        if preferences.fullscreen && !diagnostic { args.append("--fullscreen") }
        args.append(file)
        return args
    }
}

enum ImportRules {
    static let extensions: Set<String> = Set(GameSystem.allCases.flatMap { $0.extensions })
    static func validate(_ url: URL) throws {
        guard extensions.contains(url.pathExtension.lowercased()) else { throw AppFailure.message("Choose a supported game file. Extract ZIP archives first; CIA packages must be installed using a compatible 3DS tool.") }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { throw AppFailure.message("This file is empty or unavailable.") }
        // NRO is unencrypted, so check its magic before giving it to the core.
        if url.pathExtension.lowercased() == "nro" {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let prefix = try handle.read(upToCount: 0x80) ?? Data()
            guard prefix.count >= 0x80, prefix.subdata(in: 0x10..<0x14) == Data("NRO0".utf8) else {
                throw AppFailure.message("This file does not contain a valid NRO header.")
            }
        }
    }
}

enum AppFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}
