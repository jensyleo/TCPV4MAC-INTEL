//
//  main.swift
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

// Headless smoke tool: exercises the real pipeline end-to-end —
// LsofProvider + LibprocMetadataProvider + ConnectionRepository + diff engine —
// without any UI. Useful for validating the data layer from the terminal.

let repository = ConnectionRepository(provider: LsofProvider())

// First refresh: everything is "added".
let first = try await repository.refresh()
let connections = first.current

let tcp = connections.filter { $0.protocolType == .tcp }
let udp = connections.filter { $0.protocolType == .udp }
let listening = connections.filter(\.isListening)
let established = connections.filter(\.isEstablished)
let processes = Set(connections.map(\.pid))
let enriched = connections.filter { $0.executablePath != nil }

print("=== TCPV4MAC core smoke test ===")
print("Total connections : \(connections.count)")
print("  TCP             : \(tcp.count)")
print("  UDP             : \(udp.count)")
print("  Listening       : \(listening.count)")
print("  Established     : \(established.count)")
print("Distinct processes: \(processes.count)")
print("With exec path    : \(enriched.count)/\(connections.count) (libproc enrichment)")
print("First refresh events (all added): \(first.added.count)")
print("")

func pad(_ s: String, _ n: Int) -> String {
    s.count >= n ? String(s.prefix(n)) : s + String(repeating: " ", count: n - s.count)
}

print(pad("PROCESS", 20) + pad("PID", 7) + pad("PPID", 7) + pad("PROTO", 6)
    + pad("STATE", 12) + pad("LOCAL", 22) + "EXECUTABLE")
for c in connections.prefix(20) {
    let local = "\(c.localIP):\(c.localPort)"
    let state = c.state?.displayName ?? "-"
    print(pad(c.processName, 20) + pad("\(c.pid)", 7) + pad(c.parentPID.map(String.init) ?? "-", 7)
        + pad(c.protocolType.rawValue, 6) + pad(state, 12) + pad(local, 22)
        + (c.executablePath ?? "-"))
}
if connections.count > 20 {
    print("... and \(connections.count - 20) more")
}

// Second refresh a moment later: show what the diff engine detects.
try await Task.sleep(for: .seconds(1))
let second = try await repository.refresh()
print("")
print("Second refresh (1s later): +\(second.added.count) added  "
    + "~\(second.modified.count) modified  -\(second.removed.count) removed")
