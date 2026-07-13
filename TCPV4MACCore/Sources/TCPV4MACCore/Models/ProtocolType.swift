//
//  ProtocolType.swift
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

import Foundation

/// Transport protocol of a socket. Kept AppKit-free so the model layer stays
/// testable and UI-agnostic.
public enum ProtocolType: String, Sendable, Hashable, CaseIterable {
    case tcp = "TCP"
    case udp = "UDP"

    /// Parses the value reported by `lsof -FP` (the `P` field), e.g. `TCP` / `UDP`.
    public init?(lsofField: String) {
        switch lsofField.uppercased() {
        case "TCP": self = .tcp
        case "UDP": self = .udp
        default: return nil
        }
    }
}
