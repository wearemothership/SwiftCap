//
//  Preferences.swift
//  SwiftCap
//
//  Created by Martin Persson on 2022-12-27.
//

import SwiftUI
import AVFAudio
import AVFoundation
import KeyboardShortcuts
import ServiceManagement

struct Preferences: View {
    static let updateCheck = "updateCheck"
    static let frontAppKey = "frontAppOnly"
    static let fileName = "outputFileName"
    
    @State private var selectedTab: Tab = .video
    
    enum Tab: String, CaseIterable {
        case video = "Video"
        case audio = "Audio"
        case destination = "Destination"
        case shortcuts = "Shortcuts"
        case other = "Other"
    }
    
    var body: some View {
        HStack {
            List(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(7)
                        .background(selectedTab == tab ? Color.accentColor.opacity(1) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 200)
            .listStyle(SidebarListStyle())
            
            VStack {
                switch selectedTab {
                case .video:
                    VideoSettings()
                case .audio:
                    AudioSettings()
                case .destination:
                    OutputSettings()
                case .shortcuts:
                    ShortcutSettings()
                case .other:
                    OtherSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 700)
    }

    struct VideoSettings: View {
        @AppStorage("frameRate")    private var frameRate: Int = 60
        @AppStorage("videoQuality") private var videoQuality: Double = 1.0
        @AppStorage("videoFormat")  private var videoFormat: VideoFormat = .mp4
        @AppStorage("encoder")      private var encoder: Encoder = .h264
        @AppStorage("highRes")      private var highRes: Bool = true
        @AppStorage(frontAppKey)    private var frontApp: Bool = false
        @AppStorage("hideSelf")     private var hideSelf: Bool = false
        @AppStorage("showMouse")    private var showMouse: Bool = true
        @AppStorage("resizeWindow") private var resizeWindow: Bool = true
        @AppStorage("windowWidth")  private var windowWidth: String = "2000"
        @AppStorage("windowHeight") private var windowHeight: String = "1400"

        var body: some View {
            ScrollView {
                Form {
                        Picker("FPS", selection: $frameRate) {
                            Text("60").tag(60)
                            Text("30").tag(30)
                            Text("25").tag(25)
                            Text("24").tag(24)
                            Text("15").tag(15)
                        }
                        Picker("Resolution", selection: $highRes) {
                            Text("Auto").tag(true)
                            Text("Low (1x)").tag(false)
                        }
                        Picker("Quality", selection: $videoQuality) {
                            Text("Low").tag(0.3)
                            Text("Medium").tag(0.7)
                            Text("High").tag(1.0)
                        }
                        Picker("Format", selection: $videoFormat) {
                            Text("MOV").tag(VideoFormat.mov)
                            Text("MP4").tag(VideoFormat.mp4)
                        }
                        Picker("Encoder", selection: $encoder) {
                            Text("H.264").tag(Encoder.h264)
                            Text("H.265").tag(Encoder.h265)
                        }
                    }
                    .toggleStyle(.switch)
                    .formStyle(.grouped)
                
                Form {
                      Toggle(isOn: $resizeWindow) {
                        Text("Set window size")
                      }
                        TextField("Width", text: $windowWidth)
                        .disabled(!resizeWindow)
                        TextField("Height", text: $windowHeight)
                        .disabled(!resizeWindow)
                    }
                    .toggleStyle(.switch)
                    .formStyle(.grouped)
                
                Form {
                      Toggle(isOn: $showMouse) {
                        Text("Show mouse cursor")
                      }
                    }
                    .toggleStyle(.switch)
                    .formStyle(.grouped)
                
                Form {
                      Toggle(isOn: $hideSelf) {
                        Text("Exclude SwiftCap")
                      }
                      Toggle(isOn: $frontApp) {
                        Text("Only list focused windows")
                      }
                    }
                    .toggleStyle(.switch)
                    .formStyle(.grouped)
            }
        }
    }

    struct AudioSettings: View {
        @AppStorage("audioFormat")  private var audioFormat: AudioFormat = .aac
        @AppStorage("audioQuality") private var audioQuality: AudioQuality = .high
        @AppStorage("recordMic")    private var recordMic: Bool = false

        var body: some View {
            ScrollView {
                Form {
                    Picker("Format", selection: $audioFormat) {
                        Text("AAC").tag(AudioFormat.aac)
                        Text("ALAC (Lossless)").tag(AudioFormat.alac)
                        Text("FLAC (Lossless)").tag(AudioFormat.flac)
                        Text("Opus").tag(AudioFormat.opus)
                    }.padding([.leading, .trailing], 10)
                    Picker("Quality", selection: $audioQuality) {
                        if audioFormat == .alac || audioFormat == .flac {
                            Text("Lossless").tag(audioQuality)
                        }
                        Text("Normal - 128Kbps").tag(AudioQuality.normal)
                        Text("Good - 192Kbps").tag(AudioQuality.good)
                        Text("High - 256Kbps").tag(AudioQuality.high)
                        Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                    }.padding([.leading, .trailing], 10).disabled(audioFormat == .alac || audioFormat == .flac)
                }
                .toggleStyle(.switch)
                .formStyle(.grouped)
                
                Text("These settings are also used when recording video. If set to Opus, MP4 will fall back to AAC.")
                .font(.footnote).foregroundColor(Color.gray)
                .padding(20.0)
                
                Form {
                    if #available(macOS 14, *) { // apparently they changed onChange in Sonoma
                        Toggle(isOn: $recordMic) {
                            Text("Record microphone")
                        }.onChange(of: recordMic) {
                            Task { await performMicCheck() }
                        }
                    } else {
                        Toggle(isOn: $recordMic) {
                            Text("Record microphone")
                        }.onChange(of: recordMic) { _ in
                            Task { await performMicCheck() }
                        }
                    }
                }
                .toggleStyle(.switch)
                .formStyle(.grouped)
                
                Text("Doesn't apply to system audio-only recordings. The currently set input device will be used, and will be written as a separate audio track.")
                .font(.footnote).foregroundColor(Color.gray)
                .padding(20.0)
            }
        }
        
        func performMicCheck() async {
            guard recordMic == true else { return }
            if await AVCaptureDevice.requestAccess(for: .audio) { return }

            recordMic = false
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "SwiftCap needs permissions!".local
                alert.informativeText = "SwiftCap needs permission to record your microphone to do this.".local
                alert.addButton(withTitle: "Open Settings".local)
                alert.addButton(withTitle: "No thanks".local)
                alert.alertStyle = .warning
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                }
            }
        }
    }
     
     
    struct OutputSettings: View {
        @AppStorage("saveDirectory") private var saveDirectory: String?
        @AppStorage(fileName) private var _fileName: String = "Recording at %t"
        @State private var fileNameLength = 0
        private let dateFormatter = DateFormatter()

        var body: some View {
            ScrollView {
                Form {
                    HStack() {
                        Text("File Name")
                        Spacer()
                        TextField("", text: $_fileName).frame(maxWidth: 250)
                            .onChange(of: _fileName) { newText in
                                fileNameLength = getFileNameLength(newText)
                            }
                            .onAppear() {
                                dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
                                fileNameLength = getFileNameLength(_fileName)
                            }
                    }
                }
                .formStyle(.grouped)
                
                Text("\"%t\" will be replaced with the recording's start time.")
                    .font(.subheadline).foregroundColor(Color.gray)
                    .padding(20.0)
                
                Form {
                    HStack() {
                        Text("Save to")
                        Spacer()
                        Button(String(format: "%@".local, URL(fileURLWithPath: saveDirectory!).lastPathComponent), action: updateOutputDirectory)
                    }
                }.formStyle(.grouped)
            }.onTapGesture {
                DispatchQueue.main.async { // because the textfield likes focus..
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }

        func getFileNameLength(_ fileName: String) -> Int {
            return fileName.replacingOccurrences(of: "%t", with: dateFormatter.string(from: Date())).count
        }

        func updateOutputDirectory() { // todo: re-sandbox?
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowedContentTypes = []
            openPanel.allowsOtherFileTypes = false
            if openPanel.runModal() == NSApplication.ModalResponse.OK {
                saveDirectory = openPanel.urls.first?.path
            }
        }
    }
    
    struct ShortcutSettings: View {
        var thing: [(String, KeyboardShortcuts.Name)] = [
            ("Record system audio".local, .recordSystemAudio),
            ("Record current display".local, .recordCurrentDisplay),
            ("Record focused window".local, .recordCurrentWindow)
        ]
        var body: some View {
            ScrollView {
                Form() {
                    ForEach(thing, id: \.1) { shortcut in
                        KeyboardShortcuts.Recorder(shortcut.0, name: shortcut.1)
                    }
                }
                Text("Recordings can be stopped with the same shortcut.")
                    .font(.subheadline).foregroundColor(Color.gray)
                    .padding(20.00)
            }.formStyle(.grouped)
        }
    }
    
    struct OtherSettings: View {
        @AppStorage(updateCheck) private var _updateCheck: Bool = true
        @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

        var body: some View {
            ScrollView {
                Form {
                      Toggle(isOn: $launchAtLogin) {
                        Text("Launch at login")
                      }.onChange(of: launchAtLogin) { newValue in
                          do {
                              if newValue {
                                  try SMAppService.mainApp.register()
                              } else {
                                  try SMAppService.mainApp.unregister()
                              }
                          } catch {
                              print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                          }
                      }
                      Toggle(isOn: $_updateCheck) {
                        Text("Check for updates at launch")
                      }
                    }
                    .toggleStyle(.switch)
                    .formStyle(.grouped)
                
                Text("SwiftCap will check [GitHub](https://github.com/wearemothership/SwiftCap/releases) for new updates.")
                    .font(.footnote).foregroundColor(Color.gray)
                    .padding(20.00)
                
                Form {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(getVersion()) (\(getBuild()))")
                    }
                    HStack {
                        Text("Made by")
                        Spacer()
                        Text("[Mothership](https://wearemothership.com)")
                    }
                }
                .toggleStyle(.switch)
                .formStyle(.grouped)
                
                Text("SwiftCap is based on the great app [Azayaka](https://github.com/Mnpn/Azayaka)")
                    .font(.footnote).foregroundColor(Color.gray)
                    .padding(20.00)
            }
        }

        func getVersion() -> String {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown".local
        }

        func getBuild() -> String {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown".local
        }
    }

    struct VisualEffectView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView { return NSVisualEffectView() }
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }
}

#Preview {
    Preferences()
}

extension AppDelegate {
    @objc func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.mainMenu?.items.first?.submenu?.item(at: 2)?.performAction()
        } else if #available(macOS 13, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        for w in NSApplication.shared.windows {
            if w.level.rawValue == 0 || w.level.rawValue == 3 { w.level = .floating }
        }
    }
}

extension NSMenuItem {
    func performAction() {
        guard let menu else {
            return
        }
        menu.performActionForItem(at: menu.index(of: self))
    }
}
