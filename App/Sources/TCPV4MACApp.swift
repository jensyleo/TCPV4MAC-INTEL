//
//  TCPV4MACApp.swift
//  TCPV4MAC — real-time TCP/UDP connection inspector for macOS
//
//  Copyright (C) 2026 Jensy Leonardo Martínez Cruz
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftUI
import AppKit
#if canImport(Darwin)
import Darwin
#endif

@main
struct TCPV4MACApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Shared so both the main window and the Settings window use one instance.
    @State private var model = ConnectionsViewModel()
    @AppStorage("showInspector") private var showInspector = true

    init() {
        // Bail out early if another instance for this user is already running.
        SingleInstance.enforceOrExit()
    }

    var body: some Scene {
        // `Window` (not `WindowGroup`) → a single unique window. This also removes
        // the "New Window" command, so ⌘N can't spawn a second window.
        Window("TCPV4MAC", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 960, minHeight: 540)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About TCPV4MAC") { showAboutPanel() }
            }
            CommandGroup(replacing: .help) {
                Button("TCPV4MAC Help") { showHelp() }
            }
            CommandMenu("Connections") {
                Button("Refresh Now") { model.refreshNow() }
                    .keyboardShortcut("r", modifiers: .command)
                Button(model.isPaused ? "Resume Auto-Refresh" : "Pause Auto-Refresh") {
                    model.togglePause()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Button(showInspector ? "Hide Inspector" : "Show Inspector") {
                    showInspector.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

/// Concise technical help shown from the Help menu.
@MainActor
func showHelp() {
    let alert = NSAlert()
    alert.messageText = "How TCPV4MAC works"
    alert.informativeText = """
    TCPV4MAC lists every TCP/UDP socket on the system and the process that owns it \
    (via lsof), refreshing on the interval you choose.

    • It shows only your user's connections unless you choose “Run as Administrator”.
    • Row colors: green = new · amber = changed · red = closing · blue = listening \
    · purple = loopback · gray = root · orange = unsigned.
    • CLOSED sockets linger while the owning app keeps the file descriptor open \
    (e.g. browser connection pools); they disappear when the app releases them.
    • Right-click the header to show/hide columns; right-click a row to copy or \
    act on it (Reveal in Finder, Open Terminal, Kill Process).

    Free software under the GNU GPL v3.0 — with no warranty.
    """
    alert.runModal()
}

/// Standard About panel with a GPLv3 notice + license link in the credits.
/// (Name, version and copyright come from the Info.plist automatically.)
@MainActor
func showAboutPanel() {
    let credits = NSMutableAttributedString(
        string: "A real-time TCP/UDP connection inspector for macOS.\n\nInspired by Sysinternals TCPView for Windows.\n\nFree software under the GNU General Public License v3.0 — with NO WARRANTY.\n",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
    )
    credits.append(NSAttributedString(
        string: "gnu.org/licenses/gpl-3.0",
        attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .link: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!,
        ]
    ))
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    NSApp.activate(ignoringOtherApps: true)
}

/// When the app runs as root (launched directly by the "Run as Administrator"
/// flow, not via LaunchServices), it doesn't grab focus on its own — pull it to
/// the front a few times once the normal instance has quit.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard getuid() == 0 else { return }
        for delay in [0.2, 1.0, 2.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // `ignoringOtherApps:` is deprecated but it's the only reliable
                // way to force a directly-launched root app to the foreground.
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Quit the whole app when its window is closed (it's a single-window utility,
    /// so lingering with no window serves no purpose).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
