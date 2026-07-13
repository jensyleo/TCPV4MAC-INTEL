//
//  Connection.swift
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

/// A single network endpoint owned by a process, as observed at one point in time.
///
/// This model is intentionally AppKit-free: process icons and other UI-only
/// concerns live in the app layer, not here. That keeps the model testable and
/// lets the core package compile and run its tests headlessly.
public struct Connection: Identifiable, Sendable, Hashable {

    // MARK: Process
    public let processName: String
    public let pid: Int
    public let user: String
    /// The file descriptor number in the owning process. Part of the identity
    /// so two distinct sockets in the same process never collapse together.
    public let fileDescriptor: Int

    // MARK: Socket
    public let protocolType: ProtocolType
    public let state: TCPState?
    public let isIPv6: Bool
    public let localIP: String
    public let localPort: Int
    public let remoteIP: String?
    public let remotePort: Int?

    // MARK: Enrichment (filled in after the raw parse; optional in core)
    /// Parent process id. Filled by a `ProcessMetadataProvider` (libproc).
    public let parentPID: Int?
    public let executablePath: String?
    /// Bundle id and icon are AppKit/NSRunningApplication territory → filled in
    /// the app layer, left `nil` by the core.
    public let bundleIdentifier: String?
    public let bytesSent: UInt64?
    public let bytesReceived: UInt64?
    public let startedAt: Date?

    public init(
        processName: String,
        pid: Int,
        user: String,
        fileDescriptor: Int,
        protocolType: ProtocolType,
        state: TCPState?,
        isIPv6: Bool,
        localIP: String,
        localPort: Int,
        remoteIP: String? = nil,
        remotePort: Int? = nil,
        parentPID: Int? = nil,
        executablePath: String? = nil,
        bundleIdentifier: String? = nil,
        bytesSent: UInt64? = nil,
        bytesReceived: UInt64? = nil,
        startedAt: Date? = nil
    ) {
        self.processName = processName
        self.pid = pid
        self.user = user
        self.fileDescriptor = fileDescriptor
        self.protocolType = protocolType
        self.state = state
        self.isIPv6 = isIPv6
        self.localIP = localIP
        self.localPort = localPort
        self.remoteIP = remoteIP
        self.remotePort = remotePort
        self.parentPID = parentPID
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
        self.bytesSent = bytesSent
        self.bytesReceived = bytesReceived
        self.startedAt = startedAt
    }

    /// Stable identity across refresh snapshots. A random UUID per fetch would
    /// make every connection look "new" every second and break the diff engine,
    /// so identity is derived from the socket tuple + owning process/fd.
    public var identity: String {
        "\(pid).\(fileDescriptor).\(protocolType.rawValue).\(localIP):\(localPort)->\(remoteIP ?? "*"):\(remotePort ?? 0)"
    }

    public var id: String { identity }

    /// Returns a copy with process metadata (executable path, parent pid)
    /// merged in. Existing non-nil values are preserved.
    public func applying(_ metadata: ProcessMetadata) -> Connection {
        Connection(
            processName: processName,
            pid: pid,
            user: user,
            fileDescriptor: fileDescriptor,
            protocolType: protocolType,
            state: state,
            isIPv6: isIPv6,
            localIP: localIP,
            localPort: localPort,
            remoteIP: remoteIP,
            remotePort: remotePort,
            parentPID: parentPID ?? metadata.parentPID,
            executablePath: executablePath ?? metadata.executablePath,
            bundleIdentifier: bundleIdentifier,
            bytesSent: bytesSent,
            bytesReceived: bytesReceived,
            startedAt: startedAt
        )
    }

    // MARK: Classification helpers (used by filters and color rules)

    public var isLoopback: Bool {
        Self.isLoopbackAddress(localIP) || (remoteIP.map(Self.isLoopbackAddress) ?? false)
    }

    public var isListening: Bool { state == .listen }

    public var isEstablished: Bool { state == .established }

    static func isLoopbackAddress(_ ip: String) -> Bool {
        ip == "127.0.0.1" || ip == "::1" || ip.hasPrefix("127.") || ip == "[::1]"
    }
}
