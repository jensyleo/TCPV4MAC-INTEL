//
//  SingleInstance.swift
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

import AppKit
#if canImport(Darwin)
import Darwin
#endif

/// Guarantees a single running instance **per user**. If another TCPV4MAC owned
/// by the same uid is already running, this instance activates it and exits.
///
/// Enforced per-uid (not globally) on purpose: the "Run as Administrator" flow
/// deliberately launches a second instance as root while the normal-user one
/// quits, and that must not be blocked.
enum SingleInstance {

    static func enforceOrExit() {
        let selfPID = getpid()
        let others = sameUserInstances().filter { $0 != selfPID }
        guard let otherPID = others.first else { return }
        NSRunningApplication(processIdentifier: otherPID)?.activate()
        exit(0)
    }

    private static func sameUserInstances() -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        // -U <uid>: only processes owned by the current user; -x: exact name.
        process.arguments = ["-x", "-U", "\(getuid())", "TCPV4MAC"]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
    }
}
