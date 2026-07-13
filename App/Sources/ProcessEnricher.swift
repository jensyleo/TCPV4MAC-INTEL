//
//  ProcessEnricher.swift
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
import Security
#if canImport(Darwin)
import Darwin
#endif

/// Code-signing status of a process's executable.
struct SignatureInfo: Sendable, Equatable {
    enum Status: Sendable, Equatable { case signed, unsigned, unknown }
    var status: Status
    var authority: String?

    var isUnsigned: Bool { status == .unsigned }
    var displayText: String {
        switch status {
        case .signed: return authority ?? "Signed"
        case .unsigned: return "Unsigned"
        case .unknown: return "Unknown"
        }
    }
    static let unknown = SignatureInfo(status: .unknown, authority: nil)
}

/// Per-process runtime metrics from libproc.
struct ProcessMetrics: Sendable, Equatable {
    var residentBytes: UInt64?
    var threadCount: Int?
    var cpuTimeNanos: UInt64?     // cumulative user + system
    var architecture: String?
}

/// App-layer enrichment (icons, bundle id, signature, metrics). Kept out of
/// `TCPV4MACCore` so the engine stays UI/AppKit-free. Icon/bundle/arch lookups
/// are cached; signature computation is a pure static that can run off-main.
@MainActor
final class ProcessEnricher {

    private var iconCache: [String: NSImage] = [:]   // keyed by executable path
    private var bundleIDCache: [Int: String?] = [:]  // keyed by pid

    func icon(forPath path: String?) -> NSImage? {
        guard let path, !path.isEmpty else { return nil }
        if let cached = iconCache[path] { return cached }
        let lookupPath = Self.appBundlePath(forExecutable: path) ?? path
        let image = NSWorkspace.shared.icon(forFile: lookupPath)
        image.size = NSSize(width: 20, height: 20)
        iconCache[path] = image
        return image
    }

    func bundleID(forPID pid: Int) -> String? {
        if let cached = bundleIDCache[pid] { return cached }
        let value = NSRunningApplication(processIdentifier: pid_t(pid))?.bundleIdentifier
        bundleIDCache[pid] = value
        return value
    }

    func architecture(forPID pid: Int) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return nil }
        switch app.executableArchitecture {
        case NSBundleExecutableArchitectureARM64: return "arm64"
        case NSBundleExecutableArchitectureX86_64: return "x86_64"
        case NSBundleExecutableArchitectureI386: return "i386"
        default: return nil
        }
    }

    func metrics(forPID pid: Int) -> ProcessMetrics {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(Int32(pid), PROC_PIDTASKINFO, 0, &info, size)
        var metrics = ProcessMetrics()
        if result == size {
            metrics.residentBytes = info.pti_resident_size
            metrics.threadCount = Int(info.pti_threadnum)
            metrics.cpuTimeNanos = info.pti_total_user &+ info.pti_total_system
        }
        metrics.architecture = architecture(forPID: pid)
        return metrics
    }

    // MARK: - Static helpers

    /// If the executable lives inside an `.app`, return the bundle path so the
    /// icon is the app icon and not a generic unix-tool icon.
    static func appBundlePath(forExecutable path: String) -> String? {
        if let range = path.range(of: ".app/Contents/MacOS/") {
            return String(path[..<range.lowerBound]) + ".app"
        }
        return nil
    }

    /// Pure, thread-safe signature check (safe to call off the main actor).
    nonisolated static func computeSignature(path: String) -> SignatureInfo {
        guard !path.isEmpty else { return .unknown }
        let url = URL(fileURLWithPath: path) as CFURL
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url, SecCSFlags(rawValue: 0), &staticCode) == errSecSuccess,
              let code = staticCode else { return .unknown }

        let validity = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), nil)
        if validity == errSecCSUnsigned {
            return SignatureInfo(status: .unsigned, authority: nil)
        }

        var infoRef: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &infoRef) == errSecSuccess,
              let dict = infoRef as? [String: Any] else {
            return SignatureInfo(status: .unsigned, authority: "Ad-hoc (unsigned)")
        }

        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        var certName: String?
        if let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let leaf = certs.first {
            var commonName: CFString?
            if SecCertificateCopyCommonName(leaf, &commonName) == errSecSuccess {
                certName = commonName as String?
            }
        }
        // No signing identity (no cert chain and no team) → ad-hoc / not trusted.
        // Only a real authority (Apple / Developer ID) counts as "signed".
        if certName == nil && team == nil {
            return SignatureInfo(status: .unsigned, authority: "Ad-hoc (unsigned)")
        }
        return SignatureInfo(status: .signed, authority: certName ?? team)
    }
}
