//
//  LsofParser.swift
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

/// Parses the machine-readable field output of `lsof -i -nP -F...`.
///
/// We deliberately use `lsof`'s `-F` (field) mode instead of scraping the
/// human-readable columns: the column layout truncates process names to ~9
/// characters (`identityservicesd` shows as `identitys`) and is whitespace-
/// fragile. Field mode emits one `<key><value>` token per line and gives full
/// command names.
///
/// Relevant field keys (see `lsof(8)`):
///   p = pid            c = command        L = login name
///   f = file descriptor  t = type (IPv4/IPv6)  P = protocol (TCP/UDP)
///   n = name (address)   T = TCP info (TST=, TQR=, TQS=)
public struct LsofParser: Sendable {

    /// The `-F` field selector this parser expects. Pair it with `-i -nP`.
    public static let fieldSelector = "pcLftPnT"

    public init() {}

    public func parse(_ output: String) -> [Connection] {
        var connections: [Connection] = []

        // Process-level context, carried across the file blocks that follow.
        var pid: Int?
        var command = ""
        var user = ""

        // Current file (fd) block being accumulated.
        var pending: PendingSocket?

        func flush() {
            guard let pending, let pid else { return }
            if let connection = pending.build(pid: pid, command: command, user: user) {
                connections.append(connection)
            }
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = Substring(rawLine)
            guard let key = line.first else { continue }
            let value = line.dropFirst()

            switch key {
            case "p":
                flush()
                pending = nil
                pid = Int(value)
                command = ""
                user = ""
            case "c":
                command = String(value)
            case "L":
                user = String(value)
            case "f":
                flush()
                pending = PendingSocket(fileDescriptor: Int(value.filter(\.isNumber)) ?? -1)
            case "t":
                pending?.isIPv6 = (value == "IPv6")
            case "P":
                pending?.protocolType = ProtocolType(lsofField: String(value))
            case "n":
                pending?.name = String(value)
            case "T":
                // e.g. "TST=LISTEN", "TQR=0", "TQS=0"
                if value.hasPrefix("ST=") {
                    pending?.state = TCPState(lsofState: String(value.dropFirst(3)))
                }
            default:
                break
            }
        }
        flush()

        return connections
    }

    // MARK: - Endpoint parsing

    /// Splits an `lsof` name field into local and optional remote endpoints.
    /// Handles `*:*`, `host:port`, `[ipv6]:port`, and `local->remote` forms.
    static func parseEndpoint(_ raw: String) -> (ip: String, port: Int?)? {
        guard !raw.isEmpty else { return nil }

        // IPv6 literal in brackets: [addr]:port  (addr may carry a %zone)
        if raw.hasPrefix("[") {
            guard let close = raw.firstIndex(of: "]") else { return nil }
            let ip = String(raw[raw.index(after: raw.startIndex)..<close])
            let after = raw[raw.index(after: close)...]
            let port = after.hasPrefix(":") ? parsePort(String(after.dropFirst())) : nil
            return (ip, port)
        }

        // IPv4 / hostname: split on the last colon.
        if let colon = raw.lastIndex(of: ":") {
            let ip = String(raw[raw.startIndex..<colon])
            let port = parsePort(String(raw[raw.index(after: colon)...]))
            return (ip.isEmpty ? "*" : ip, port)
        }

        return (raw, nil)
    }

    private static func parsePort(_ token: String) -> Int? {
        token == "*" ? nil : Int(token)
    }
}

// MARK: - Accumulator

private struct PendingSocket {
    var fileDescriptor: Int
    var isIPv6 = false
    var protocolType: ProtocolType?
    var name: String?
    var state: TCPState?

    func build(pid: Int, command: String, user: String) -> Connection? {
        guard let protocolType, let name else { return nil }

        let (localRaw, remoteRaw) = Self.splitLocalRemote(name)
        guard let local = LsofParser.parseEndpoint(localRaw) else { return nil }
        let remote = remoteRaw.flatMap(LsofParser.parseEndpoint)

        return Connection(
            processName: command,
            pid: pid,
            user: user,
            fileDescriptor: fileDescriptor,
            protocolType: protocolType,
            state: state,
            isIPv6: isIPv6,
            localIP: local.ip,
            localPort: local.port ?? 0,
            remoteIP: remote?.ip,
            remotePort: remote?.port
        )
    }

    private static func splitLocalRemote(_ name: String) -> (String, String?) {
        if let range = name.range(of: "->") {
            return (String(name[..<range.lowerBound]), String(name[range.upperBound...]))
        }
        return (name, nil)
    }
}
