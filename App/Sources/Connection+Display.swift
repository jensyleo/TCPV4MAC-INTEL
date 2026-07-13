//
//  Connection+Display.swift
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

/// App-layer display/sort helpers so the core `Connection` stays UI-free.
/// The `…SortKey` values are non-optional so they can back sortable columns.
extension Connection {
    var displayState: String { state?.displayName ?? "—" }
    var displayRemoteIP: String { remoteIP ?? "—" }
    var displayRemotePortText: String { remotePort.map(String.init) ?? "—" }
    var displayBundleID: String { bundleIdentifier ?? "" }
    var displayExecutable: String { executablePath ?? "—" }

    /// Sort key that keeps rows without a remote port grouped together.
    var remotePortSortKey: Int { remotePort ?? -1 }
    var protocolSortKey: String { protocolType.rawValue }

    /// Case-insensitive match of an already-lowercased query across the fields a
    /// single search box should cover (process, PID, IP, port, executable, user,
    /// state, bundle id).
    func matches(_ loweredQuery: String) -> Bool {
        if processName.lowercased().contains(loweredQuery) { return true }
        if String(pid).contains(loweredQuery) { return true }
        if user.lowercased().contains(loweredQuery) { return true }
        if protocolType.rawValue.lowercased().contains(loweredQuery) { return true }
        if (state?.displayName.lowercased().contains(loweredQuery) ?? false) { return true }
        if localIP.lowercased().contains(loweredQuery) { return true }
        if String(localPort).contains(loweredQuery) { return true }
        if (remoteIP?.lowercased().contains(loweredQuery) ?? false) { return true }
        if let rp = remotePort, String(rp).contains(loweredQuery) { return true }
        if (executablePath?.lowercased().contains(loweredQuery) ?? false) { return true }
        if (bundleIdentifier?.lowercased().contains(loweredQuery) ?? false) { return true }
        return false
    }
}
