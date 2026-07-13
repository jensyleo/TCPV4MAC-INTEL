//
//  ConnectionDiffEngine.swift
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

/// Compares consecutive connection snapshots and emits add/remove/modify events.
///
/// The engine is deliberately a plain value-processing type (no timers, no
/// concurrency): feed it snapshots, get back a diff. That makes it trivially
/// unit-testable, which the spec requires.
public final class ConnectionDiffEngine {

    /// Keyed by `Connection.identity`.
    private var previous: [String: Connection] = [:]

    public init() {}

    /// Resets the baseline so the next `apply(_:)` reports every connection as new.
    public func reset() {
        previous.removeAll()
    }

    /// Diffs `snapshot` against the last snapshot seen and stores it as the new
    /// baseline. The first call reports every connection as `.added`.
    @discardableResult
    public func apply(_ snapshot: [Connection]) -> ConnectionDiff {
        var events: [ConnectionEvent] = []
        var next: [String: Connection] = [:]
        next.reserveCapacity(snapshot.count)

        for connection in snapshot {
            next[connection.identity] = connection
            if let old = previous[connection.identity] {
                if Self.isModified(from: old, to: connection) {
                    events.append(ConnectionEvent(kind: .modified, connection: connection, previous: old))
                }
            } else {
                events.append(ConnectionEvent(kind: .added, connection: connection))
            }
        }

        for (identity, old) in previous where next[identity] == nil {
            events.append(ConnectionEvent(kind: .removed, connection: old))
        }

        previous = next
        return ConnectionDiff(events: events, current: snapshot)
    }

    /// A connection is "modified" when an observable field changes while its
    /// identity stays the same — e.g. TCP state transitions or byte counters.
    /// Enrichment fields (bundle id, paths) are intentionally ignored so that
    /// late-arriving metadata does not masquerade as a real change.
    static func isModified(from old: Connection, to new: Connection) -> Bool {
        old.state != new.state
            || old.bytesSent != new.bytesSent
            || old.bytesReceived != new.bytesReceived
    }
}
