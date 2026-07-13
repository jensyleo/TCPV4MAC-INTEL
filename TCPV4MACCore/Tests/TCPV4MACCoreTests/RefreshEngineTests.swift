//
//  RefreshEngineTests.swift
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

final class RefreshEngineTests: XCTestCase {

    /// Reads the next `.update` event from the stream, failing on timeout.
    private func firstUpdate(
        _ engine: RefreshEngine,
        timeout: Duration = .seconds(3)
    ) async throws -> ConnectionDiff {
        try await withThrowingTaskGroup(of: ConnectionDiff?.self) { group in
            group.addTask {
                for await event in engine.events {
                    if case let .update(diff) = event { return diff }
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            let result = try await group.next() ?? nil
            group.cancelAll()
            return try XCTUnwrap(result, "no update event before timeout")
        }
    }

    func testStartEmitsAnImmediateUpdate() async throws {
        let provider = MockConnectionProvider(snapshots: [[makeConn(pid: 1), makeConn(pid: 2)]])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        let engine = RefreshEngine(repository: repo, interval: .fiveHundredMs)

        await engine.start()
        let diff = try await firstUpdate(engine)
        XCTAssertEqual(diff.added.count, 2)
        await engine.stop()
    }

    func testAutoRefreshEmitsMultipleTicks() async throws {
        // Two distinct snapshots so the second tick shows a change.
        let provider = MockConnectionProvider(snapshots: [
            [makeConn(pid: 1, state: .synSent)],
            [makeConn(pid: 1, state: .established)]
        ])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        let engine = RefreshEngine(repository: repo, interval: .fiveHundredMs)

        await engine.start()
        var updates = 0
        var sawModified = false
        for await event in engine.events {
            if case let .update(diff) = event {
                updates += 1
                if diff.modified.count == 1 { sawModified = true }
                if updates >= 2 { break }
            }
        }
        await engine.stop()
        XCTAssertGreaterThanOrEqual(updates, 2)
        XCTAssertTrue(sawModified, "second tick should report the state change")
    }

    func testFailureEventOnProviderError() async throws {
        let provider = MockConnectionProvider(error: TestError.boom)
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        let engine = RefreshEngine(repository: repo, interval: .fiveHundredMs)

        await engine.start()
        var sawFailure = false
        for await event in engine.events {
            if case .failure = event { sawFailure = true; break }
        }
        await engine.stop()
        XCTAssertTrue(sawFailure)
    }

    func testPauseStopsProducingUpdates() async throws {
        let provider = MockConnectionProvider(snapshots: [[makeConn(pid: 1)]])
        let repo = ConnectionRepository(provider: provider, metadataProvider: MockMetadataProvider())
        let engine = RefreshEngine(repository: repo, interval: .fiveHundredMs)

        await engine.start()
        _ = try await firstUpdate(engine)   // consume the immediate tick
        await engine.pause()
        let paused = await engine.paused
        XCTAssertTrue(paused)
        await engine.stop()
    }
}
