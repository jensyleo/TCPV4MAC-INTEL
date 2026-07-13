//
//  ConnectionDiffEngineTests.swift
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

import XCTest
@testable import TCPV4MACCore

final class ConnectionDiffEngineTests: XCTestCase {

    private func makeConnection(
        pid: Int = 100,
        fd: Int = 3,
        proto: ProtocolType = .tcp,
        state: TCPState? = .established,
        localIP: String = "192.168.0.2",
        localPort: Int = 50000,
        remoteIP: String? = "1.1.1.1",
        remotePort: Int? = 443,
        bytesSent: UInt64? = nil
    ) -> Connection {
        Connection(
            processName: "test",
            pid: pid,
            user: "me",
            fileDescriptor: fd,
            protocolType: proto,
            state: state,
            isIPv6: false,
            localIP: localIP,
            localPort: localPort,
            remoteIP: remoteIP,
            remotePort: remotePort,
            bytesSent: bytesSent
        )
    }

    func testFirstSnapshotReportsEverythingAsAdded() {
        let engine = ConnectionDiffEngine()
        let diff = engine.apply([makeConnection(pid: 1), makeConnection(pid: 2)])
        XCTAssertEqual(diff.added.count, 2)
        XCTAssertTrue(diff.removed.isEmpty)
        XCTAssertTrue(diff.modified.isEmpty)
    }

    func testIdenticalSnapshotProducesNoEvents() {
        let engine = ConnectionDiffEngine()
        let snapshot = [makeConnection()]
        engine.apply(snapshot)
        let diff = engine.apply(snapshot)
        XCTAssertTrue(diff.events.isEmpty)
    }

    func testStateTransitionIsModified() {
        let engine = ConnectionDiffEngine()
        engine.apply([makeConnection(state: .synSent)])
        let diff = engine.apply([makeConnection(state: .established)])
        XCTAssertEqual(diff.modified.count, 1)
        XCTAssertEqual(diff.modified.first?.previous?.state, .synSent)
        XCTAssertEqual(diff.modified.first?.connection.state, .established)
    }

    func testByteCounterChangeIsModified() {
        let engine = ConnectionDiffEngine()
        engine.apply([makeConnection(bytesSent: 0)])
        let diff = engine.apply([makeConnection(bytesSent: 1024)])
        XCTAssertEqual(diff.modified.count, 1)
    }

    func testDisappearingConnectionIsRemoved() {
        let engine = ConnectionDiffEngine()
        engine.apply([makeConnection(pid: 1), makeConnection(pid: 2)])
        let diff = engine.apply([makeConnection(pid: 1)])
        XCTAssertEqual(diff.removed.count, 1)
        XCTAssertEqual(diff.removed.first?.connection.pid, 2)
    }

    func testNewConnectionInSecondSnapshotIsAdded() {
        let engine = ConnectionDiffEngine()
        engine.apply([makeConnection(pid: 1)])
        let diff = engine.apply([makeConnection(pid: 1), makeConnection(pid: 2)])
        XCTAssertEqual(diff.added.count, 1)
        XCTAssertEqual(diff.added.first?.connection.pid, 2)
    }

    func testResetTreatsNextSnapshotAsFresh() {
        let engine = ConnectionDiffEngine()
        let snapshot = [makeConnection()]
        engine.apply(snapshot)
        engine.reset()
        let diff = engine.apply(snapshot)
        XCTAssertEqual(diff.added.count, 1)
    }
}
