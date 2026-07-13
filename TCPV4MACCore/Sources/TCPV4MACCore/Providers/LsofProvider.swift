//
//  LsofProvider.swift
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

/// `ConnectionProvider` backed by the `lsof` command-line tool.
///
/// Requires the app to run **without** the App Sandbox: sandboxed apps cannot
/// spawn `lsof` nor inspect other processes' sockets.
public struct LsofProvider: ConnectionProvider {

    private let launchPath: String
    private let parser: LsofParser

    public init(launchPath: String = "/usr/sbin/lsof", parser: LsofParser = LsofParser()) {
        self.launchPath = launchPath
        self.parser = parser
    }

    public func fetchConnections() async throws -> [Connection] {
        let output = try await runLsof()
        return parser.parse(output)
    }

    private func runLsof() async throws -> String {
        let launchPath = launchPath
        return try await withCheckedThrowingContinuation { continuation in
            // Run the blocking Process work off the cooperative thread pool.
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.isExecutableFile(atPath: launchPath) else {
                    continuation.resume(throwing: ConnectionProviderError.toolNotFound(launchPath))
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = ["-i", "-nP", "-F\(LsofParser.fieldSelector)"]

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // Drain stdout before waiting to avoid a full-pipe deadlock on
                // large connection counts.
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                guard let text = String(data: outData, encoding: .utf8) else {
                    continuation.resume(throwing: ConnectionProviderError.decodingFailed)
                    return
                }

                // lsof exits non-zero when it can't stat *some* fds, which is
                // routine. Only treat it as a failure when we got nothing back.
                if process.terminationStatus != 0 && text.isEmpty {
                    let stderrText = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: ConnectionProviderError.commandFailed(
                        status: process.terminationStatus,
                        stderr: stderrText
                    ))
                    return
                }

                continuation.resume(returning: text)
            }
        }
    }
}
