import Foundation

@main
struct ModelsTests {
    static func main() throws {
        var prefs = Preferences()
        let odd = "/tmp/My game's $(not-a-shell); test.nro"
        var args = LaunchPlan.arguments(file: odd, root: "/tmp/Helio Root", preferences: prefs, diagnostic: true)
        precondition(args.last == odd)
        precondition(args.contains("--disable-main-input-config"))
        precondition(args[args.firstIndex(of: "--docked-mode")!+1] == "false")
        precondition(!args.contains("--fullscreen"))
        prefs.fullscreen = true; prefs.resolution = 2
        args = LaunchPlan.arguments(file: odd, root: "/tmp/Helio Root", preferences: prefs, diagnostic: false)
        precondition(args.contains("--fullscreen"))
        precondition(args[args.firstIndex(of: "--resolution-scale")!+1] == "2")
        let encoded = try JSONEncoder().encode(SavedState(items: [LibraryItem(title: "Test", path: odd)], preferences: prefs))
        let decoded = try JSONDecoder().decode(SavedState.self, from: encoded)
        precondition(decoded.preferences == prefs && decoded.items[0].path == odd)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let empty = dir.appendingPathComponent("empty.nro"); try Data().write(to: empty)
        do { try ImportRules.validate(empty); preconditionFailure("Empty NRO accepted") } catch {}
        let invalid = dir.appendingPathComponent("invalid.nro"); try Data(repeating: 0, count: 128).write(to: invalid)
        do { try ImportRules.validate(invalid); preconditionFailure("Invalid NRO accepted") } catch {}
        let wrong = dir.appendingPathComponent("program.txt"); try Data("hello".utf8).write(to: wrong)
        do { try ImportRules.validate(wrong); preconditionFailure("Unsupported file accepted") } catch {}
        if CommandLine.arguments.count > 1 { try ImportRules.validate(URL(fileURLWithPath: CommandLine.arguments[1])) }
        for family in ControllerFamily.allCases {
            let profile=ControllerProfile(family:family)
            let json=profile.coreJSON()
            let right=json["right_joycon"] as! [String:String]
            precondition(right["button_a"] == (family == .nintendo ? "A":"B"))
            precondition(right["button_b"] == (family == .nintendo ? "B":"A"))
            precondition(profile.arguments.isEmpty)
            var assigned=profile; assigned.deviceID="device with spaces"; assigned.player=2
            precondition(assigned.arguments == ["--input-id-2","device with spaces","--input-profile-2","NEXARC-Player2"])
            precondition(ControllerFamily.detect("Microsoft Xbox Wireless") == .xbox)
            precondition(ControllerFamily.detect("Sony DualSense") == .playstation)
            if CommandLine.arguments.count > 2 {
                let folder=URL(fileURLWithPath:CommandLine.arguments[2]);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                try JSONSerialization.data(withJSONObject:json,options:.prettyPrinted).write(to:folder.appendingPathComponent(family.rawValue+".json"))
            }
        }
        print("PASS: launch arguments, path isolation, preferences persistence, and program validation")
        print("PASS: Xbox, PlayStation, Nintendo and generic button translation and controller profile export")
    }
}
