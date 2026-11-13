import SwiftUI

struct SessionsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var engine: EngineBridge
    @ViewState private var selected: UUID?
    @ViewState private var savedLog = ""
    @ViewState private var showRaw = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behind every session.").font(.system(size: 30, weight: .light)).tracking(-1)
                    Text("Real output from the emulation core. Nothing simulated.").font(.system(size: 13)).foregroundStyle(Palette.muted)
                }
                Spacer()
                if engine.diagnosticPassed { Tag(text: "ARM64 DIAGNOSTIC PASSED", color: Palette.mint, dot: true) }
                if engine.running { Button("Stop session", role: .destructive) { engine.stop() }.buttonStyle(Tactile()) }
            }
            if engine.diagnosticPassed && selected == nil {
                GlassPanel(padding:18) {
                    HStack(spacing:16) {
                        Image(systemName:"checkmark.seal.fill").font(.system(size: 28)).foregroundStyle(Palette.mint)
                        VStack(alignment:.leading,spacing:7) {
                            Text("Your first Switch instructions ran.").font(.system(size: 16,weight:.medium))
                            Text("Arithmetic 42 · Loop 10 · Memory 42 · System calls passed").font(.system(size: 13)).foregroundStyle(Palette.muted)
                            Text("This CPU test has no graphics. Choose Orbit Pong in Library for a playable game.").font(.system(size: 12)).foregroundStyle(Palette.coral)
                        }
                        Spacer()
                    }
                }
            }
            HStack(alignment: .top, spacing: 18) {
                ScrollView {
                    VStack(spacing: 8) {
                        Button { selected = nil } label: {
                            sessionRow(engine.running ? engine.currentTitle : "Latest output", subtitle: engine.running ? "Running now" : "Current app session", icon: engine.running ? "waveform" : "terminal", chosen: selected == nil)
                        }.buttonStyle(.plain)
                        ForEach(model.saved.sessions) { record in
                            Button {
                                selected = record.id
                                savedLog = (try? String(contentsOfFile: record.logPath, encoding: .utf8)) ?? "This session log is no longer available."
                            } label: {
                                sessionRow(record.title, subtitle: "\(record.started.formatted(date: .abbreviated, time: .shortened)) · \(Int(record.duration))s · \(record.verifiedDiagnostic ? "PASS" : record.stoppedByUser ? "Stopped" : "Exit \(record.exitCode)")", icon: record.verifiedDiagnostic ? "checkmark.circle" : "clock", chosen: selected == record.id)
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(width: 242)
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Circle().fill(engine.running && selected == nil ? Palette.mint : Palette.muted).frame(width: 6, height: 6); Text(selected == nil ? "LIVE CONSOLE" : "SAVED SESSION").font(.system(size: 11, weight: .semibold)).tracking(1.2); Spacer(); Toggle("Raw output",isOn:$showRaw).font(.system(size: 11)).toggleStyle(.checkbox); Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(selected == nil ? engine.output : savedLog, forType: .string); model.notify("Console output copied.") } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy console output") }.foregroundStyle(Palette.muted).padding(15)
                    Divider().overlay(Palette.line)
                    ScrollView([.vertical, .horizontal]) {
                        Text(consoleText).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color(hex: 0xBECCC8)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(18)
                    }
                }.background(Color(hex: 0x0A0E12), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.line))
            }
        }.padding(28)
    }
    private var consoleText: String {
        let text = selected != nil ? savedLog : engine.output
        if text.isEmpty { return "Ready when you are.\n\nPlay Orbit Pong from Library, or run the First Light CPU self-test.\nActual guest output will appear here." }
        if showRaw || engine.isRetro { return text }
        let important = text.split(separator:"\n").filter { $0.contains("NEXARC_") || $0.contains("Gpu PrintGpuInformation") || $0.contains("Application Loaded:") || ($0.contains("|E|") && !$0.contains("mvk-") && !$0.contains("\t")) }
        return important.isEmpty ? "Starting the emulation core…\n\nEnable Raw output to inspect all startup messages." : important.joined(separator:"\n\n")
    }
    private func sessionRow(_ title: String, subtitle: String, icon: String, chosen: Bool) -> some View {
        HStack(spacing: 11) { Image(systemName: icon).foregroundStyle(chosen ? Palette.coral : Palette.muted); VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 13, weight: .medium)).lineLimit(1); Text(subtitle).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(2) }; Spacer(minLength: 0) }
            .padding(13).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(chosen ? 0.07 : 0.02), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LearnView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Tag(text: "CURIOUS BY DESIGN", color: Palette.mint)
                Text("Open the hood.").font(.system(size: 40, weight: .light)).tracking(-1.7)
                Text("Follow one tiny program from your library to the Switch CPU.").font(.system(size: 14)).foregroundStyle(Palette.muted)
                HStack(spacing: 12) {
                    step("01", "Load", "Read the NRO header and map code and data into guest memory.", "shippingbox")
                    step("02", "Execute", "Run ARM64 instructions using the core's CPU backend.", "cpu")
                    step("03", "Respond", "Handle Switch system calls and return results to the program.", "arrow.triangle.branch")
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Text("FIRST LIGHT / THE IMPORTANT PART").font(.system(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(Palette.coral); Spacer(); Tag(text: "AARCH64 ASSEMBLY") }
                        Text("mov x9, #21           // Put 21 in a CPU register.\nadd x9, x9, x9        // Double it: we expect 42.\ncmp x9, #42           // Compare the actual result.\nb.ne failure          // Report failure if it differs.\n\nadr x0, success       // Address of our success message.\nmov x1, #message_size // Number of bytes to print.\nsvc #0x27             // Switch OutputDebugString.\nsvc #0x07             // Switch ExitProcess.")
                            .font(.system(size: 14, design: .monospaced)).lineSpacing(8).foregroundStyle(Color(hex: 0xC7D6CF)).textSelection(.enabled)
                        Text("The complete diagnostic also checks a loop and a memory load/store. Passing proves those instructions and system calls ran; it does not prove commercial-game or graphics compatibility.").font(.system(size: 13)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                        Button { model.launch(model.diagnostic); model.section = "Sessions" } label: { Label("Run it and read the output", systemImage: "play.fill") }.buttonStyle(Tactile(primary: true)).disabled(model.engine.running)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GlassPanel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Where your code ends, and the core begins.").font(.system(size: 16, weight: .medium))
                        Text("NEXARC owns your console gallery, imports, per-game folders, saves, patches and process bridge. Switch uses the source-built Ryujinx-derived engine; the other systems use RetroArch with individual libretro cores. Gameplay opens in a separate engine window. Start with GameSystem.swift and RetroRuntime.swift to follow the new architecture.").font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                        HStack {
                            Link("Core source ↗", destination: URL(string: "https://github.com/wangxiaoming1988/Ryujinx-fork")!)
                            Button("Open learning guide") {
                                if let guide=Bundle.main.url(forResource:"START-HERE",withExtension:"md",subdirectory:"Guides") { NSWorkspace.shared.open(guide) }
                            }.buttonStyle(.plain)
                            Spacer()
                            Link("3D model: HarrisonHag1 · CC BY 4.0 ↗", destination: URL(string: "https://sketchfab.com/3d-models/nintendo-switch-c73fadccfdc547f9958fd8a1cdbe4811")!)
                        }.font(.system(size: 12)).foregroundStyle(Palette.coral)
                    }
                }
            }.padding(28)
        }
    }
    private func step(_ number: String, _ title: String, _ text: String, _ icon: String) -> some View {
        GlassPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 13) {
                HStack { Text(number).font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.coral); Spacer(); Image(systemName: icon).foregroundStyle(Palette.mint) }
                Text(title).font(.system(size: 19, weight: .medium))
                Text(text).font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4).frame(height: 52, alignment: .top)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
