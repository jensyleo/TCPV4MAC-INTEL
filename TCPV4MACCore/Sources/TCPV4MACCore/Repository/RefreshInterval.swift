//
//  RefreshInterval.swift
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

/// The user-selectable auto-refresh cadence. Default is `.oneSecond`.
public enum RefreshInterval: Sendable, Hashable, CaseIterable {
    case fiveHundredMs
    case oneSecond
    case twoSeconds
    case fiveSeconds
    case tenSeconds

    public static let `default` = RefreshInterval.oneSecond

    public var duration: Duration {
        switch self {
        case .fiveHundredMs: return .milliseconds(500)
        case .oneSecond: return .seconds(1)
        case .twoSeconds: return .seconds(2)
        case .fiveSeconds: return .seconds(5)
        case .tenSeconds: return .seconds(10)
        }
    }

    public var displayName: String {
        switch self {
        case .fiveHundredMs: return "500 ms"
        case .oneSecond: return "1 s"
        case .twoSeconds: return "2 s"
        case .fiveSeconds: return "5 s"
        case .tenSeconds: return "10 s"
        }
    }

    /// Stable identifier for persistence (not the localized display name).
    public var persistentID: String {
        switch self {
        case .fiveHundredMs: return "500ms"
        case .oneSecond: return "1s"
        case .twoSeconds: return "2s"
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        }
    }

    public static func from(persistentID: String) -> RefreshInterval? {
        allCases.first { $0.persistentID == persistentID }
    }
}
