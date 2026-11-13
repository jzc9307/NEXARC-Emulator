import Foundation

enum ControllerFamily: String, Codable, CaseIterable {
    case xbox = "Xbox Wireless", playstation = "DualSense", nintendo = "Nintendo Pro", generic = "Generic gamepad"
    static func detect(_ name: String) -> Self {
        let name = name.lowercased()
        if name.contains("xbox") || name.contains("microsoft") { return .xbox }
        if name.contains("dualsense") || name.contains("dualshock") || name.contains("playstation") { return .playstation }
        if name.contains("nintendo") || name.contains("joy-con") || name.contains("switch") || name.contains("pro controller") { return .nintendo }
        return .generic
    }
    var modelFile: String? { switch self { case .xbox: return "xbox-controller"; case .playstation: return "dualsense"; default: return nil } }
    var credit: String {
        switch self {
        case .xbox:return "Chistodrako._. · CC BY 4.0"
        case .playstation:return "Taohid Animation · CC BY 4.0"
        case .nintendo:return "NEXARC studio mesh · Nintendo Pro layout"
        case .generic:return "NEXARC studio mesh · Generic layout"
        }
    }
    func label(_ physical: String) -> String {
        let face: [String: String]
        switch self {
        case .nintendo: face = ["South":"B", "East":"A", "West":"Y", "North":"X"]
        case .playstation: face = ["South":"Cross ×", "East":"Circle ○", "West":"Square □", "North":"Triangle △"]
        default: face = ["South":"A", "East":"B", "West":"X", "North":"Y"]
        }
        if let label = face[physical] { return label }
        let names: [String:String]
        switch self {
        case .xbox:
            names=["LeftShoulder":"LB","RightShoulder":"RB","LeftTrigger":"LT","RightTrigger":"RT","Minus":"View","Plus":"Menu"]
        case .playstation:
            names=["LeftShoulder":"L1","RightShoulder":"R1","LeftTrigger":"L2","RightTrigger":"R2","Minus":"Create","Plus":"Options"]
        case .nintendo:
            names=["LeftShoulder":"L","RightShoulder":"R","LeftTrigger":"ZL","RightTrigger":"ZR","Minus":"−","Plus":"+"]
        case .generic:
            names=["LeftShoulder":"L1","RightShoulder":"R1","LeftTrigger":"L2","RightTrigger":"R2","Minus":"Select","Plus":"Start"]
        }
        let common=["LeftStick":"Left stick click","RightStick":"Right stick click","DpadUp":"D-pad ↑","DpadDown":"D-pad ↓","DpadLeft":"D-pad ←","DpadRight":"D-pad →","Unbound":"Unbound"]
        return names[physical] ?? common[physical] ?? physical
    }
    // The bundled SDL driver maps face inputs by the controller's printed labels.
    // Native GameController reports positions. Translate between those conventions.
    func coreButton(_ physical: String) -> String {
        switch physical {
        case "South": return self == .nintendo ? "B" : "A"
        case "East": return self == .nintendo ? "A" : "B"
        case "West": return self == .nintendo ? "Y" : "X"
        case "North": return self == .nintendo ? "X" : "Y"
        default: return physical
        }
    }
}

struct ControllerProfile: Codable, Equatable {
    var player = 1
    var deviceID = ""
    var family: ControllerFamily = .xbox
    var bindings = Self.defaults
    var deadzone = 0.10
    var triggerThreshold = 0.50
    var invertLeftY = false
    var invertRightY = false
    static let targets: [(String, String)] = [("a","A"),("b","B"),("x","X"),("y","Y"),("l","L"),("r","R"),("zl","ZL"),("zr","ZR"),("minus","−"),("plus","+"),("ls","L stick"),("rs","R stick"),("up","D-pad ↑"),("down","D-pad ↓"),("left","D-pad ←"),("right","D-pad →")]
    static let sources = ["South","East","West","North","LeftShoulder","RightShoulder","LeftTrigger","RightTrigger","Minus","Plus","LeftStick","RightStick","DpadUp","DpadDown","DpadLeft","DpadRight","Unbound"]
    static let defaults = ["a":"East", "b":"South", "x":"North", "y":"West", "l":"LeftShoulder", "r":"RightShoulder", "zl":"LeftTrigger", "zr":"RightTrigger", "minus":"Minus", "plus":"Plus", "ls":"LeftStick", "rs":"RightStick", "up":"DpadUp", "down":"DpadDown", "left":"DpadLeft", "right":"DpadRight"]
    var profileName: String { "NEXARC-Player\(player)" }
    var arguments: [String] { deviceID.isEmpty ? [] : ["--input-id-\(player)",deviceID,"--input-profile-\(player)",profileName] }
    func coreJSON() -> [String: Any] {
        func button(_ target: String) -> String { family.coreButton(bindings[target] ?? "Unbound") }
        return ["version":1,"backend":"GamepadSDL3","id":deviceID,"name":profileName,"controller_type":"ProController","player_index":"Player\(player)",
            "deadzone_left":deadzone,"deadzone_right":deadzone,"range_left":1.0,"range_right":1.0,"trigger_threshold":triggerThreshold,
            "left_joycon":["button_minus":button("minus"),"button_l":button("l"),"button_zl":button("zl"),"button_sl":"Unbound","button_sr":"Unbound","dpad_up":button("up"),"dpad_down":button("down"),"dpad_left":button("left"),"dpad_right":button("right")],
            "right_joycon":["button_a":button("a"),"button_b":button("b"),"button_x":button("x"),"button_y":button("y"),"button_plus":button("plus"),"button_r":button("r"),"button_zr":button("zr"),"button_sl":"Unbound","button_sr":"Unbound"],
            "left_joycon_stick":["joystick":"Left","stick_button":button("ls"),"invert_stick_x":false,"invert_stick_y":invertLeftY,"rotate90_cw":false],
            "right_joycon_stick":["joystick":"Right","stick_button":button("rs"),"invert_stick_x":false,"invert_stick_y":invertRightY,"rotate90_cw":false],
            "motion":["motion_backend":"GamepadDriver","enable_motion":false,"sensitivity":100,"gyro_deadzone":1],
            "rumble":["enable_rumble":false,"use_hd_rumble":false,"strong_rumble":1,"weak_rumble":1],
            "led":["enable_led":false,"turn_off_led":false,"use_rainbow":false,"led_color":0]]
    }
}
