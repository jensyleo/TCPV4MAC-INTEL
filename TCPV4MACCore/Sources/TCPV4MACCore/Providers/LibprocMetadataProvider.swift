//
//  LibprocMetadataProvider.swift
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
#if canImport(Darwin)
import Darwin
#endif

/// `ProcessMetadataProvider` backed by `libproc` (`proc_pidpath` +
/// `proc_pidinfo`). Foundation/Darwin only — no AppKit — so it stays in core.
public struct LibprocMetadataProvider: ProcessMetadataProvider {

    public init() {}

    public func metadata(for pid: Int) -> ProcessMetadata {
        ProcessMetadata(
            executablePath: Self.executablePath(pid: pid),
            parentPID: Self.parentPID(pid: pid)
        )
    }

    /// `PROC_PIDPATHINFO_MAXSIZE` (= 4 * MAXPATHLEN) isn't imported into Swift
    /// as a constant, so we spell it out.
    private static let pathMaxSize = 4 * Int(MAXPATHLEN)

    static func executablePath(pid: Int) -> String? {
        var buffer = [CChar](repeating: 0, count: pathMaxSize)
        let length = proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func parentPID(pid: Int) -> Int? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, size)
        guard result == size else { return nil }
        return Int(info.pbi_ppid)
    }
}
