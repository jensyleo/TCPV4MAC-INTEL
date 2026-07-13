//
//  ConnectionProvider.swift
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

/// Abstracts the source of connection data so the UI never depends on `lsof`
/// (or any other specific backend). Future providers: nettop, libproc, sysctl,
/// Network.framework, Endpoint Security.
public protocol ConnectionProvider: Sendable {
    func fetchConnections() async throws -> [Connection]
}

public enum ConnectionProviderError: Error, Sendable {
    /// The backend tool was not found at the expected path.
    case toolNotFound(String)
    /// The backend exited with a non-zero status.
    case commandFailed(status: Int32, stderr: String)
    /// The backend output could not be decoded as UTF-8.
    case decodingFailed
}
