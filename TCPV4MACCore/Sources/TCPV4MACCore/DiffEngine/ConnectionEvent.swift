//
//  ConnectionEvent.swift
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

/// The kind of change detected between two consecutive snapshots.
public enum ConnectionChangeKind: Sendable, Hashable {
    case added
    case removed
    case modified
}

/// A single change produced by the diff engine, carrying enough context for the
/// UI to highlight rows (green/yellow/red) and for future history logging.
public struct ConnectionEvent: Sendable, Hashable, Identifiable {
    public let kind: ConnectionChangeKind
    /// The connection as it appears in the new snapshot (for `.removed` this is
    /// the last-known state from the previous snapshot).
    public let connection: Connection
    /// Populated only for `.modified`: the previous version of the connection.
    public let previous: Connection?

    public var id: String { "\(kind).\(connection.identity)" }

    public init(kind: ConnectionChangeKind, connection: Connection, previous: Connection? = nil) {
        self.kind = kind
        self.connection = connection
        self.previous = previous
    }
}

/// Result of diffing two snapshots: the events plus the full current set.
public struct ConnectionDiff: Sendable {
    public let events: [ConnectionEvent]
    public let current: [Connection]

    public var added: [ConnectionEvent] { events.filter { $0.kind == .added } }
    public var removed: [ConnectionEvent] { events.filter { $0.kind == .removed } }
    public var modified: [ConnectionEvent] { events.filter { $0.kind == .modified } }

    public init(events: [ConnectionEvent], current: [Connection]) {
        self.events = events
        self.current = current
    }
}
