//
//  ConnectionRepositoryTests.swift
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

final class ConnectionRepositoryTests: XCTestCase {

    func testFirstRefreshReportsAllAdded() async throws {
        let provider = MockConnectionProvider(snapshots: [[makeConn(pid: 1), makeConn(pid: 2)]])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        let diff = try await repo.refresh()
        XCTAssertEqual(diff.added.count, 2)
        let current = await repo.currentConnections
        XCTAssertEqual(current.count, 2)
    }

    func testSecondIdenticalRefreshHasNoEvents() async throws {
        let snap = [makeConn(pid: 1)]
        let provider = MockConnectionProvider(snapshots: [snap, snap])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        _ = try await repo.refresh()
        let diff = try await repo.refresh()
        XCTAssertTrue(diff.events.isEmpty)
    }

    func testRefreshDetectsStateChangeAcrossSnapshots() async throws {
        let provider = MockConnectionProvider(snapshots: [
            [makeConn(pid: 1, state: .synSent)],
            [makeConn(pid: 1, state: .established)]
        ])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        _ = try await repo.refresh()
        let diff = try await repo.refresh()
        XCTAssertEqual(diff.modified.count, 1)
        XCTAssertEqual(diff.modified.first?.connection.state, .established)
    }

    func testEnrichmentAppliesMetadata() async throws {
        let provider = MockConnectionProvider(snapshots: [[makeConn(pid: 42)]])
        let metadata = MockMetadataProvider(byPID: [
            42: ProcessMetadata(executablePath: "/usr/bin/proc42", parentPID: 1)
        ])
        let repo = ConnectionRepository(provider: provider, metadataProvider: metadata)
        let diff = try await repo.refresh()
        let conn = try XCTUnwrap(diff.current.first)
        XCTAssertEqual(conn.executablePath, "/usr/bin/proc42")
        XCTAssertEqual(conn.parentPID, 1)
    }

    func testProviderErrorPropagates() async {
        let provider = MockConnectionProvider(error: TestError.boom)
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        do {
            _ = try await repo.refresh()
            XCTFail("expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testResetBaselineMakesNextRefreshFresh() async throws {
        let snap = [makeConn(pid: 1)]
        let provider = MockConnectionProvider(snapshots: [snap, snap])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        _ = try await repo.refresh()
        await repo.resetBaseline()
        let diff = try await repo.refresh()
        XCTAssertEqual(diff.added.count, 1)
    }
}
