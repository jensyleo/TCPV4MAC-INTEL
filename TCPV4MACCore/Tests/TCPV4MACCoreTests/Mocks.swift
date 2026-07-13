//
//  Mocks.swift
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
@testable import TCPV4MACCore

/// A `ConnectionProvider` that returns canned snapshots, one per `fetch`, and
/// records how many times it was called. Thread-safe via a small lock.
final class MockConnectionProvider: ConnectionProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [[Connection]]
    private let errorToThrow: Error?
    private(set) var fetchCount = 0

    init(snapshots: [[Connection]] = [], error: Error? = nil) {
        self.snapshots = snapshots
        self.errorToThrow = error
    }

    func fetchConnections() async throws -> [Connection] {
        if let errorToThrow { throw errorToThrow }
        return lock.withLock {
            fetchCount += 1
            // After the scripted snapshots run out, keep returning the last one.
            let index = min(fetchCount - 1, snapshots.count - 1)
            return snapshots.isEmpty ? [] : snapshots[max(0, index)]
        }
    }
}

/// A `ProcessMetadataProvider` returning fixed metadata per pid.
struct MockMetadataProvider: ProcessMetadataProvider {
    var byPID: [Int: ProcessMetadata] = [:]
    func metadata(for pid: Int) -> ProcessMetadata {
        byPID[pid] ?? .empty
    }
}

enum TestError: Error { case boom }

/// Small connection factory for tests.
func makeConn(
    pid: Int = 100,
    fd: Int = 3,
    state: TCPState? = .established,
    localPort: Int = 50000
) -> Connection {
    Connection(
        processName: "proc\(pid)",
        pid: pid,
        user: "me",
        fileDescriptor: fd,
        protocolType: .tcp,
        state: state,
        isIPv6: false,
        localIP: "192.168.0.2",
        localPort: localPort,
        remoteIP: "1.1.1.1",
        remotePort: 443
    )
}
