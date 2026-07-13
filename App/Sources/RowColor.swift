//
//  RowColor.swift
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

/// Connection color rules (spec §Color Rules). Transient states (added /
/// modified / removed) take precedence over persistent attributes (unsigned,
/// listening, loopback, root). Rendered as a subtle full-row background in the
/// native table, so the text stays readable.
enum RowStatus: CaseIterable {
    case added, modified, removed, unsigned, listening, loopback, root

    var label: String {
        switch self {
        case .added: return "Added (new this refresh)"
        case .modified: return "Modified (state/bytes changed)"
        case .removed: return "Removed (closing)"
        case .unsigned: return "Unsigned process"
        case .listening: return "Listening"
        case .loopback: return "Loopback"
        case .root: return "Root process"
        }
    }

    /// Legend swatch color (SwiftUI).
    var color: Color {
        switch self {
        case .added: return .green
        case .modified: return Color(red: 0.85, green: 0.6, blue: 0.1)
        case .removed: return .red
        case .unsigned: return .orange
        case .listening: return .blue
        case .loopback: return .purple
        case .root: return Color(white: 0.45)
        }
    }

    /// Row text tint for the native table (readable in light and dark).
    var textColor: NSColor {
        switch self {
        case .added: return .systemGreen
        case .modified: return NSColor(srgbRed: 0.85, green: 0.6, blue: 0.1, alpha: 1) // amber
        case .removed: return .systemRed
        case .unsigned: return .systemOrange
        case .listening: return .systemBlue
        case .loopback: return .systemPurple
        case .root: return .systemGray
        }
    }
}
