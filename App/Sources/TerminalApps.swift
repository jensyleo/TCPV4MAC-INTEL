//
//  TerminalApps.swift
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

/// Detects installed terminal emulators. Shared by the context menu and Settings.
enum TerminalApps {
    struct Terminal: Identifiable, Hashable {
        let name: String
        let bundleID: String
        var id: String { bundleID }
    }

    static let known: [Terminal] = [
        Terminal(name: "Terminal", bundleID: "com.apple.Terminal"),
        Terminal(name: "iTerm", bundleID: "com.googlecode.iterm2"),
        Terminal(name: "Warp", bundleID: "dev.warp.Warp-Stable"),
        Terminal(name: "Ghostty", bundleID: "com.mitchellh.ghostty"),
        Terminal(name: "kitty", bundleID: "net.kovidgoyal.kitty"),
        Terminal(name: "WezTerm", bundleID: "com.github.wez.wezterm"),
        Terminal(name: "Alacritty", bundleID: "io.alacritty"),
        Terminal(name: "Hyper", bundleID: "co.zeit.hyper"),
    ]

    static func installed() -> [Terminal] {
        known.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    static func url(forBundleID bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
}
