//
//  ProcessMetadataProvider.swift
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

/// Process-level details that are not available from `lsof` and are looked up
/// separately (executable path, parent pid). AppKit-derived data (icon, bundle
/// id, signature) belongs in the app layer, not here.
public struct ProcessMetadata: Sendable, Hashable {
    public let executablePath: String?
    public let parentPID: Int?

    public init(executablePath: String? = nil, parentPID: Int? = nil) {
        self.executablePath = executablePath
        self.parentPID = parentPID
    }

    public static let empty = ProcessMetadata()
}

/// Resolves `ProcessMetadata` for a pid. Abstracted so the repository can be
/// unit-tested with a mock instead of hitting the live system.
public protocol ProcessMetadataProvider: Sendable {
    func metadata(for pid: Int) -> ProcessMetadata
}
