//
//  Uninstaller.swift
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

import AppKit

/// Full self-uninstall: removes the app's traces (preferences, saved state,
/// caches, privacy/TCC grants) and moves the bundle to the Trash. The app is
/// not sandboxed, so this can clean everything it leaves behind.
@MainActor
enum Uninstaller {

    static func confirmAndUninstall() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Uninstall TCPV4MAC?"
        alert.informativeText = """
        This will move TCPV4MAC to the Trash and remove everything it leaves on \
        this Mac: its preferences (columns, filters, window), saved state, caches, \
        and its Privacy & Security permissions. This cannot be undone.
        """
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        perform()
    }

    private static func perform() {
        let bundleIDs = [Bundle.main.bundleIdentifier ?? "com.jensyleo.tcpv4mac"]
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        for bundleID in bundleIDs {
            // 1. Reset Privacy & Security (TCC) grants.
            runToCompletion("/usr/bin/tccutil", ["reset", "All", bundleID])
            // 2. Saved state + caches (no cfprefsd race here).
            for path in ["Library/Saved Application State/\(bundleID).savedState",
                         "Library/Caches/\(bundleID)",
                         "Library/HTTPStorages/\(bundleID)"] {
                try? fm.removeItem(at: home.appendingPathComponent(path))
            }
        }

        // 3. Preferences: delete AFTER we quit. Doing it in-process fails because
        //    cfprefsd flushes the domain back to disk on termination, recreating
        //    the .plist. A detached shell waits for quit, then `defaults delete`
        //    clears the daemon's cache and removes the file for good.
        let prefsCleanup = "sleep 2\n" + bundleIDs.map { id in
            """
            /usr/bin/defaults delete \(id) 2>/dev/null
            /bin/rm -f "$HOME/Library/Preferences/\(id).plist"
            """
        }.joined(separator: "\n")
        let sh = Process()
        sh.executableURL = URL(fileURLWithPath: "/bin/sh")
        sh.arguments = ["-c", prefsCleanup]
        try? sh.run()   // detached — do not wait; it outlives us

        // 4. Move the app bundle to the Trash.
        try? fm.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)

        // 5. Quit (lets the detached cleanup finish the prefs removal).
        NSApp.terminate(nil)
    }

    private static func runToCompletion(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
