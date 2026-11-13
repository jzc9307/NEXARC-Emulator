import Foundation

struct RetroRuntime {
    let bundle: URL
    var app: URL { bundle.appendingPathComponent("Contents/Helpers/RetroArch.app") }
    var executable: URL { app.appendingPathComponent("Contents/MacOS/RetroArch") }
    var cores: URL { bundle.appendingPathComponent("Contents/Resources/Cores") }
    func core(_ system: GameSystem) -> URL { cores.appendingPathComponent((system.core ?? "missing") + "_libretro.dylib") }
    func available(_ system: GameSystem) -> Bool { FileManager.default.isExecutableFile(atPath:executable.path) && FileManager.default.fileExists(atPath:core(system).path) }
    static func gameRoot(_ item: LibraryItem, dataRoot: URL) -> URL { dataRoot.appendingPathComponent("Games/\(item.id.uuidString)") }
    static func saves(_ item: LibraryItem, dataRoot: URL) -> URL { gameRoot(item,dataRoot:dataRoot).appendingPathComponent("Saves") }
    static func states(_ item: LibraryItem, dataRoot: URL) -> URL { gameRoot(item,dataRoot:dataRoot).appendingPathComponent("States") }
    static func quote(_ value: String) -> String { "\"" + value.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:" ").replacingOccurrences(of:"\r",with:" ") + "\"" }

    func prepare(_ item: LibraryItem, dataRoot: URL, preferences: Preferences, resume: Bool, commandPort: Int = 55355, display: DisplayProfile = DisplayProfile(), keyboard: KeyboardMapping = KeyboardMapping()) throws -> [String] {
        guard available(item.system) else { throw AppFailure.message("The \(item.system.engineLabel) core is missing from this build.") }
        let fm=FileManager.default, root=Self.gameRoot(item,dataRoot:dataRoot)
        let save=Self.saves(item,dataRoot:dataRoot), state=Self.states(item,dataRoot:dataRoot)
        let system=dataRoot.appendingPathComponent("System Files")
        let screenshots=root.appendingPathComponent("Screenshots"), cheats=root.appendingPathComponent("Cheats")
        for dir in [root,save,state,system,screenshots,cheats] { try fm.createDirectory(at:dir,withIntermediateDirectories:true) }
        let assets=bundle.appendingPathComponent("Contents/Resources/SystemAssets")
        for name in ["PPSSPP","dolphin-emu"] {
            let target=system.appendingPathComponent(name),source=assets.appendingPathComponent(name)
            if !fm.fileExists(atPath:target.path),fm.fileExists(atPath:source.path) {try fm.copyItem(at:source,to:target)}
        }
        let options=root.appendingPathComponent("core-options.cfg")
        if !fm.fileExists(atPath:options.path) {
            try Data("citra_graphics_api = \"Software\"\nparallel-n64-gfxplugin = \"parallel\"\nparallel-n64-rspplugin = \"parallel\"\n".utf8).write(to:options,options:.atomic)
        }
        var coreText=(try? String(contentsOf:options,encoding:.utf8)) ?? ""
        var overrides:[String:String]=[:]
        if item.system == .nds {
            overrides=["melonds_number_of_screen_layouts":"1","melonds_screen_layout1":display.layout.dsValue,"melonds_screen_gap":String(display.skin == .hardware ? 8:display.effectiveGap),"melonds_hybrid_ratio":"2","melonds_touch_mode":"touch","melonds_show_cursor":"timeout"]
        } else if item.system == .n3ds {
            overrides=["citra_layout_option":display.layout.citraValue,"citra_swap_screen":[ScreenLayout.largeBottom,.bottomOnly].contains(display.layout) ? "Bottom":"Top","citra_enable_mouse_touchscreen":"enabled","citra_large_screen_proportion":"2.00"]
        }
        if item.system == .n3ds,display.skin == .custom,display.customAsset?.secondaryScreen != nil{overrides["citra_graphics_api"]="Software"}
        for (key,value) in overrides {
            coreText=coreText.components(separatedBy:"\n").filter{!$0.hasPrefix(key+" ") && !$0.hasPrefix(key+"=")}.joined(separator:"\n")
            coreText += "\n\(key) = \(Self.quote(value))\n"
        }
        try Data(coreText.utf8).write(to:options,options:.atomic)
        var values: [String:String] = [
            // Vsync owns pacing. Nonblocking CoreAudio avoids freezing the main
            // emulation loop when a macOS audio route stops consuming samples.
            "audio_sync":"false", "content_runtime_log":"false", "content_runtime_log_aggregate":"false",
            "playlist_directory":root.appendingPathComponent("Playlists").path,
            "video_driver":"metal", "audio_driver":"coreaudio", "input_driver":"cocoa", "input_joypad_driver":"mfi",
            "video_fullscreen":display.fullscreen ? "true":"false", "video_windowed_fullscreen":"false",
            "video_window_width":String(max(480,min(3840,display.windowWidth))), "video_window_height":String(max(360,min(2160,display.windowHeight))), "video_window_save_positions":"true", "video_scale_integer":"false", "video_smooth":display.smooth ? "true":"false", "video_vsync":"true", "video_swap_interval":"1",
            // RetroArch's generic OSD leaks setup, extraction, layout, and resume
            // messages into gameplay. NEXARC owns the visible session UI.
            "video_font_enable":"false",
            "audio_volume":preferences.volume <= 0 ? "-80":String(20 * log10(preferences.volume)),
            "menu_driver":"rgui", "config_save_on_exit":"false", "stdin_cmd_enable":"false", "network_cmd_enable":"true", "network_cmd_port":String(commandPort), "core_info_cache_enable":"false", "history_list_enable":"false", "microphone_enable":"false", "quit_press_twice":"false",
            "pause_nonactive":"false", "autosave_interval":"10", "savestate_auto_save":"true", "savestate_auto_load":resume ? "true":"false",
            "savestate_file_compression":"true", "savestate_thumbnail_enable":"true", "state_slot":"0",
            "sort_savefiles_enable":"false", "sort_savestates_enable":"false", "sort_savefiles_by_content_enable":"false", "sort_savestates_by_content_enable":"false",
            "savefile_directory":save.path, "savestate_directory":state.path, "system_directory":system.path,
            "screenshot_directory":screenshots.path, "cheat_database_path":cheats.path,
            "libretro_directory":cores.path, "libretro_info_path":bundle.appendingPathComponent("Contents/Resources/CoreInfo").path,
            "core_options_path":root.appendingPathComponent("core-options.cfg").path,
            "content_history_path":root.appendingPathComponent("history.lpl").path, "content_favorites_path":root.appendingPathComponent("favorites.lpl").path,
            "rgui_config_directory":root.appendingPathComponent("Configuration").path, "input_remapping_directory":root.appendingPathComponent("Remaps").path, "global_core_options":"true", "game_specific_options":"false",
            "menu_show_online_updater":"false", "cheevos_enable":"false", "apply_cheats_after_load":"true",
            "input_exit_emulator":"nul", "input_menu_toggle":"f1", "input_save_state":"nul", "input_load_state":"nul",
            "input_toggle_fast_forward":"nul", "input_hold_fast_forward":"nul", "fastforward_ratio":"2.0", "input_auto_mouse_grab":"false", "input_grab_mouse_toggle":"nul", "input_pause_toggle":"nul", "input_screenshot":"f6",
            "input_player1_a":"x", "input_player1_b":"z", "input_player1_x":"s", "input_player1_y":"a",
            "input_player1_l":"q", "input_player1_r":"w", "input_player1_start":"enter", "input_player1_select":"rshift",
            "input_player1_up":"up", "input_player1_down":"down", "input_player1_left":"left", "input_player1_right":"right"
        ]
        for (action,key) in keyboard.bindings { values["input_player1_"+action]=key }
        // Hardware-rendered cores need Vulkan rather than the Metal 2D frontend.
        if [.n64,.gamecube,.wii,.dreamcast,.ps2,.psp].contains(item.system) { values["video_driver"]="vulkan" }
        // RetroArch resolves per-game cheats as <database>/<core name>/<ROM basename>.cht.
        if let path=item.cheatPath, fm.fileExists(atPath:path) {
            let metadata=bundle.appendingPathComponent("Contents/Resources/core-metadata.json")
            let names=(try? JSONDecoder().decode([String:String].self,from:Data(contentsOf:metadata))) ?? [:]
            if let coreName=names[item.system.core ?? ""] {
                let dir=cheats.appendingPathComponent(coreName); try fm.createDirectory(at:dir,withIntermediateDirectories:true)
                let target=dir.appendingPathComponent(URL(fileURLWithPath:item.path).deletingPathExtension().lastPathComponent + ".cht")
                try Data(contentsOf:URL(fileURLWithPath:path)).write(to:target,options:.atomic)
            }
        }
        let config=root.appendingPathComponent("session.cfg")
        let text=values.keys.sorted().map { "\($0) = \(Self.quote(values[$0]!))" }.joined(separator:"\n") + "\n"
        try Data(text.utf8).write(to:config,options:.atomic)
        return ["--verbose","--config",config.path,"-L",core(item.system).path,item.path]
    }
}
