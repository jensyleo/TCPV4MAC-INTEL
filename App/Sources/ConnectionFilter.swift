//
//  ConnectionFilter.swift
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
import TCPV4MACCore

/// Toggle-style filters applied on top of the free-text search. Everything on =
/// show all. (Internet vs Local-Network scope is deferred to a later pass.)
struct ConnectionFilter: Equatable, Codable {
    var tcp = true
    var udp = true
    var ipv4 = true
    var ipv6 = true
    var listening = true
    var established = true
    var otherState = true      // UDP (no state), closed, time_wait, etc.
    // Scope: loopback (localhost) vs external (everything else). Both on = all.
    var loopback = true
    var external = true

    /// True when at least one toggle is off (something is being hidden).
    var isActive: Bool {
        !(tcp && udp && ipv4 && ipv6 && listening && established && otherState && loopback && external)
    }

    mutating func reset() { self = ConnectionFilter() }

    // MARK: Persistence
    private static let defaultsKey = "TCPV4MAC.filter"

    static func loadFromDefaults() -> ConnectionFilter {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let filter = try? JSONDecoder().decode(ConnectionFilter.self, from: data)
        else { return ConnectionFilter() }
        return filter
    }

    func saveToDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    func matches(_ c: Connection) -> Bool {
        switch c.protocolType {
        case .tcp: if !tcp { return false }
        case .udp: if !udp { return false }
        }
        if c.isIPv6 { if !ipv6 { return false } } else { if !ipv4 { return false } }
        if c.isLoopback { if !loopback { return false } } else { if !external { return false } }
        // `c.state` is optional; compare with `==` (a `switch` with bare enum
        // cases does not match the wrapped value here).
        if c.state == .listen {
            if !listening { return false }
        } else if c.state == .established {
            if !established { return false }
        } else {
            if !otherState { return false }
        }
        return true
    }
}
