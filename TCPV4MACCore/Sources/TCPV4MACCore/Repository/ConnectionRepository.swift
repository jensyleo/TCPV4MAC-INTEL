//
//  ConnectionRepository.swift
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

/// Central data access point (Repository Pattern): fetches raw connections from
/// a `ConnectionProvider`, enriches them with process metadata, diffs against
/// the previous snapshot, and hands back the result.
///
/// It is a plain `async` component with no timer of its own — the `RefreshEngine`
/// drives the cadence. That keeps `refresh()` deterministic and unit-testable
/// with mock providers.
public actor ConnectionRepository {

    private let provider: ConnectionProvider
    private let metadataProvider: ProcessMetadataProvider
    private let diffEngine: ConnectionDiffEngine

    private var latest: [Connection] = []

    public init(
        provider: ConnectionProvider,
        metadataProvider: ProcessMetadataProvider = LibprocMetadataProvider(),
        diffEngine: ConnectionDiffEngine = ConnectionDiffEngine()
    ) {
        self.provider = provider
        self.metadataProvider = metadataProvider
        self.diffEngine = diffEngine
    }

    /// The most recent enriched snapshot (empty until the first `refresh()`).
    public var currentConnections: [Connection] { latest }

    /// Fetch → enrich → diff. Returns the changes plus the new full snapshot.
    @discardableResult
    public func refresh() async throws -> ConnectionDiff {
        let raw = try await provider.fetchConnections()
        let enriched = enrich(raw)
        latest = enriched
        return diffEngine.apply(enriched)
    }

    /// Clears the diff baseline so the next `refresh()` reports everything as new
    /// (e.g. after resuming from a long pause).
    public func resetBaseline() {
        diffEngine.reset()
    }

    /// Enriches connections with process metadata, resolving each pid once per
    /// snapshot (many connections share a process).
    private func enrich(_ connections: [Connection]) -> [Connection] {
        var cache: [Int: ProcessMetadata] = [:]
        return connections.map { connection in
            let metadata = cache[connection.pid] ?? {
                let looked = metadataProvider.metadata(for: connection.pid)
                cache[connection.pid] = looked
                return looked
            }()
            return connection.applying(metadata)
        }
    }
}
