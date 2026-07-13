//
//  ProcessDetails.swift
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
import TCPV4MACCore

/// Everything the inspector shows for the selected connection's process.
struct ProcessDetails {
    let connection: Connection
    let icon: NSImage?
    let bundleID: String?
    let signature: SignatureInfo
    let metrics: ProcessMetrics
    let cpuPercent: Double?
    let connectionCount: Int

    var memoryText: String {
        guard let bytes = metrics.residentBytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    var threadsText: String { metrics.threadCount.map(String.init) ?? "—" }
    var architectureText: String { metrics.architecture ?? "—" }
    var cpuText: String { cpuPercent.map { String(format: "%.1f %%", $0) } ?? "—" }
}
