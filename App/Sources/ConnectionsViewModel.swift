//
//  ConnectionsViewModel.swift
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
import Combine
import Foundation
import TCPV4MACCore

/// MVVM view model: subscribes to the core `RefreshEngine` and republishes the
/// current connection snapshot for SwiftUI. UI-facing only — all data work lives
/// in `TCPV4MACCore`.
@MainActor
final class ConnectionsViewModel: ObservableObject {

    @Published private(set) var connections: [Connection] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?
    /// Number of refresh ticks this session — a visible proof the interval works.
    @Published private(set) var refreshCount = 0

    /// IDs to tint as added / modified (row color rules). Kept for a short window
    /// so the flash is visible across several fast refreshes, not just one tick.
    @Published private(set) var addedIDs: Set<Connection.ID> = []
    @Published private(set) var modifiedIDs: Set<Connection.ID> = []
    private var addedAt: [Connection.ID: Date] = [:]
    private var modifiedAt: [Connection.ID: Date] = [:]
    private let highlightWindow: TimeInterval = 2.5

    /// First time each connection (by identity) was seen this session, backing
    /// the table's live "Duration" column.
    private var firstSeen: [Connection.ID: Date] = [:]

    private static let intervalKey = "TCPV4MAC.refreshInterval"

    @Published var interval: RefreshInterval {
        didSet {
            let e = engine, i = interval
            Task { await e.setInterval(i) }
            UserDefaults.standard.set(i.persistentID, forKey: Self.intervalKey)
        }
    }

    /// Free-text search applied to the table (dashboard counts stay on the full set).
    @Published var searchText: String = ""

    /// Toggle-style filters (protocol, IP version, state, loopback). Persisted.
    @Published var filter = ConnectionFilter() {
        didSet { filter.saveToDefaults() }
    }

    /// Column ids currently hidden (single source of truth; persisted).
    private static let hiddenColumnsKey = "TCPV4MAC.hiddenColumns"
    @Published private(set) var hiddenColumns: Set<String> = []

    func isColumnHidden(_ id: String) -> Bool { hiddenColumns.contains(id) }

    func setColumn(_ id: String, hidden: Bool) {
        if hidden { hiddenColumns.insert(id) } else { hiddenColumns.remove(id) }
        UserDefaults.standard.set(Array(hiddenColumns), forKey: Self.hiddenColumnsKey)
    }

    func showAllColumns() {
        hiddenColumns = []
        UserDefaults.standard.set([String](), forKey: Self.hiddenColumnsKey)
    }

    @Published private(set) var isPaused = false

    /// Details for the single selected connection (nil when 0 or >1 selected).
    @Published private(set) var selectedDetails: ProcessDetails?

    /// Recently-removed connections kept visible (red) for a short window.
    @Published private(set) var removedIDs: Set<Connection.ID> = []

    private let engine: RefreshEngine
    private var consumeTask: Task<Void, Never>?

    // Enrichment (icons / bundle id / signature / metrics).
    private let enricher = ProcessEnricher()
    private var signatureCache: [String: SignatureInfo] = [:]

    // Removed-row ghosts: last-known connection + when it vanished.
    private var ghosts: [Connection.ID: (connection: Connection, at: Date)] = [:]
    private let removedWindow: TimeInterval = 1.5

    // Per-process metrics (all visible pids), refreshed each tick.
    private var metricsByPID: [Int: ProcessMetrics] = [:]
    private var cpuByPID: [Int: Double] = [:]
    private var cpuSampleByPID: [Int: (nanos: UInt64, at: Date)] = [:]
    private let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)

    // Selection for the inspector.
    private var selectedID: Connection.ID?

    init() {
        let savedInterval = UserDefaults.standard.string(forKey: Self.intervalKey)
            .flatMap(RefreshInterval.from(persistentID:)) ?? .default
        self.interval = savedInterval  // no didSet during init
        let repository = ConnectionRepository(provider: LsofProvider())
        self.engine = RefreshEngine(repository: repository, interval: savedInterval)
        self.filter = ConnectionFilter.loadFromDefaults()
        self.hiddenColumns = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenColumnsKey) ?? [])
    }

    /// Connections shown in the table: current snapshot + recently-removed
    /// ghosts, passed through the toggle filters and the free-text search.
    var visibleConnections: [Connection] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        // Avoid copying the snapshot when there are no removed-row ghosts (the
        // common case); only concatenate when something actually vanished.
        let base = ghosts.isEmpty ? connections : connections + ghosts.values.map(\.connection)
        return base.filter { c in
            filter.matches(c) && (query.isEmpty || c.matches(query))
        }
    }

    // MARK: Enrichment accessors (for the table)

    func icon(for c: Connection) -> NSImage? { enricher.icon(forPath: c.executablePath) }
    func bundleID(for c: Connection) -> String? { enricher.bundleID(forPID: c.pid) }
    func isUnsigned(_ c: Connection) -> Bool {
        guard let path = c.executablePath else { return false }
        return signatureCache[path]?.isUnsigned ?? false
    }

    // MARK: Controls

    func togglePause() { setPaused(!isPaused) }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        let e = engine
        Task { paused ? await e.pause() : await e.resume() }
    }

    func refreshNow() {
        let e = engine
        Task { await e.refreshNow() }
    }


    // MARK: Summary (dashboard)
    var totalCount: Int { connections.count }   // O(1)

    /// Dashboard counts computed in one pass instead of eight separate scans.
    struct Summary {
        var tcp = 0, udp = 0, listening = 0, established = 0
        var ipv4 = 0, ipv6 = 0, loopback = 0, external = 0, processes = 0
    }

    var summary: Summary {
        var s = Summary()
        var pids = Set<Int>()
        pids.reserveCapacity(connections.count)
        for c in connections {
            if c.protocolType == .tcp { s.tcp += 1 } else { s.udp += 1 }
            if c.isIPv6 { s.ipv6 += 1 } else { s.ipv4 += 1 }
            if c.isLoopback { s.loopback += 1 } else { s.external += 1 }
            if c.isListening { s.listening += 1 }
            if c.isEstablished { s.established += 1 }
            pids.insert(c.pid)
        }
        s.processes = pids.count
        return s
    }

    /// Starts consuming the engine's event stream. Idempotent.
    func start() {
        guard consumeTask == nil else { return }
        consumeTask = Task { [engine] in
            await engine.start()
            for await event in engine.events {
                switch event {
                case .update(let diff):
                    // Don't flash the whole table green on the very first snapshot.
                    let firstSnapshot = (self.lastUpdated == nil)
                    self.updateFirstSeen(for: diff.current)
                    self.updateHighlights(
                        added: firstSnapshot ? [] : diff.added.map(\.connection.id),
                        modified: diff.modified.map(\.connection.id)
                    )
                    self.updateGhosts(removed: diff.removed.map(\.connection), current: diff.current)
                    self.refreshMetrics(for: diff.current)
                    self.connections = diff.current
                    self.warmSignatures(for: diff.current)
                    self.lastError = nil
                    self.lastUpdated = Date()
                    self.refreshCount += 1
                    self.recomputeSelectedDetails()
                case .failure(let message):
                    self.lastError = message
                }
            }
        }
    }

    func stop() {
        let e = engine
        Task { await e.stop() }
        consumeTask?.cancel()
        consumeTask = nil
    }

    // MARK: Duration

    private func updateHighlights(added: [Connection.ID], modified: [Connection.ID]) {
        let now = Date()
        for id in added { addedAt[id] = now }
        for id in modified { modifiedAt[id] = now }
        addedAt = addedAt.filter { now.timeIntervalSince($0.value) <= highlightWindow }
        modifiedAt = modifiedAt.filter { now.timeIntervalSince($0.value) <= highlightWindow }
        addedIDs = Set(addedAt.keys)
        modifiedIDs = Set(modifiedAt.keys)
    }

    private func updateFirstSeen(for current: [Connection]) {
        let now = Date()
        var next: [Connection.ID: Date] = [:]
        next.reserveCapacity(current.count)
        for connection in current {
            next[connection.id] = firstSeen[connection.id] ?? now
        }
        firstSeen = next
    }

    /// Compact elapsed-time text (e.g. `4s`, `12m`, `1h03m`) since a connection
    /// was first seen this session. `—` if unknown.
    func durationSeconds(for connection: Connection) -> Int {
        guard let start = firstSeen[connection.id] else { return -1 }
        return Int(Date().timeIntervalSince(start))
    }

    func durationText(for connection: Connection) -> String {
        guard let start = firstSeen[connection.id] else { return "—" }
        let seconds = Int(Date().timeIntervalSince(start))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return String(format: "%dh%02dm", hours, minutes)
    }

    // MARK: Removed-row ghosts

    private func updateGhosts(removed: [Connection], current: [Connection]) {
        let now = Date()
        for connection in removed { ghosts[connection.id] = (connection, now) }
        let currentIDs = Set(current.map(\.id))
        ghosts = ghosts.filter { id, value in
            now.timeIntervalSince(value.at) <= removedWindow && !currentIDs.contains(id)
        }
        removedIDs = Set(ghosts.keys)
    }

    // MARK: Signatures (warmed off-main, cached by executable path)

    private func warmSignatures(for current: [Connection]) {
        let paths = Set(current.compactMap(\.executablePath)).filter { signatureCache[$0] == nil }
        guard !paths.isEmpty else { return }
        Task.detached { [paths] in
            var results: [String: SignatureInfo] = [:]
            for path in paths { results[path] = ProcessEnricher.computeSignature(path: path) }
            await MainActor.run { [results] in
                self.signatureCache.merge(results) { _, new in new }
            }
        }
    }

    /// Cache-only read (never computes on the main thread — that caused UI
    /// hangs). `warmSignatures` fills the cache off-main; results show next tick.
    func signature(for c: Connection) -> SignatureInfo {
        guard let path = c.executablePath, let cached = signatureCache[path] else { return .unknown }
        return cached
    }

    // MARK: Selection & inspector details

    func setSelection(_ ids: Set<Connection.ID>) {
        selectedID = (ids.count == 1) ? ids.first : nil
        recomputeSelectedDetails()
    }

    private func recomputeSelectedDetails() {
        guard let id = selectedID,
              let connection = connections.first(where: { $0.id == id })
                ?? ghosts[id]?.connection else {
            selectedDetails = nil
            return
        }
        selectedDetails = ProcessDetails(
            connection: connection,
            icon: enricher.icon(forPath: connection.executablePath),
            bundleID: enricher.bundleID(forPID: connection.pid),
            signature: signature(for: connection),
            metrics: metricsByPID[connection.pid] ?? enricher.metrics(forPID: connection.pid),
            cpuPercent: cpuByPID[connection.pid],
            connectionCount: connections.filter { $0.pid == connection.pid }.count
        )
    }

    // MARK: Per-process metrics (for the metric columns + inspector)

    private func refreshMetrics(for current: [Connection]) {
        let now = Date()
        let pids = Set(current.map(\.pid))
        var metrics: [Int: ProcessMetrics] = [:]
        var cpu: [Int: Double] = [:]
        for pid in pids {
            let m = enricher.metrics(forPID: pid)
            metrics[pid] = m
            if let nanos = m.cpuTimeNanos {
                if let last = cpuSampleByPID[pid] {
                    let deltaCPU = Double(nanos &- last.nanos)
                    let deltaWall = now.timeIntervalSince(last.at) * 1_000_000_000
                    if deltaWall > 0 {
                        cpu[pid] = min(max(deltaCPU / deltaWall * 100, 0), 100 * coreCount)
                    }
                }
                cpuSampleByPID[pid] = (nanos, now)
            }
        }
        cpuSampleByPID = cpuSampleByPID.filter { pids.contains($0.key) }
        metricsByPID = metrics
        cpuByPID = cpu
    }

    func cpuValue(for c: Connection) -> Double? { cpuByPID[c.pid] }
    func cpuText(for c: Connection) -> String {
        cpuValue(for: c).map { String(format: "%.1f%%", $0) } ?? "—"
    }
    func memoryValue(for c: Connection) -> UInt64? { metricsByPID[c.pid]?.residentBytes }
    func memoryText(for c: Connection) -> String {
        memoryValue(for: c).map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .memory) } ?? "—"
    }
    func threadsValue(for c: Connection) -> Int? { metricsByPID[c.pid]?.threadCount }
    func threadsText(for c: Connection) -> String { threadsValue(for: c).map(String.init) ?? "—" }
    func architectureText(for c: Connection) -> String { metricsByPID[c.pid]?.architecture ?? "—" }
    func signatureText(for c: Connection) -> String { signature(for: c).displayText }

    // MARK: CSV export (all connections)

    func csvForAllConnections() -> String {
        let headers = ["Application", "PID", "PPID", "User", "Protocol", "State",
                       "Local Address", "Local Port", "Remote Address", "Remote Port",
                       "CPU %", "Memory (bytes)", "Threads", "Arch", "Signature",
                       "Bundle ID", "Executable", "Duration"]
        var lines = [headers.map(Self.csvEscape).joined(separator: ",")]
        for c in connections {
            var fields: [String] = []
            fields.append(c.processName)
            fields.append("\(c.pid)")
            fields.append(c.parentPID.map { "\($0)" } ?? "")
            fields.append(c.user)
            fields.append(c.protocolType.rawValue)
            fields.append(c.state?.displayName ?? "")
            fields.append(c.localIP)
            fields.append("\(c.localPort)")
            fields.append(c.remoteIP ?? "")
            fields.append(c.remotePort.map { "\($0)" } ?? "")
            fields.append(cpuValue(for: c).map { String(format: "%.1f", $0) } ?? "")
            fields.append(memoryValue(for: c).map { "\($0)" } ?? "")
            fields.append(threadsValue(for: c).map { "\($0)" } ?? "")
            fields.append(architectureText(for: c))
            fields.append(signatureText(for: c))
            fields.append(bundleID(for: c) ?? "")
            fields.append(c.executablePath ?? "")
            fields.append(durationText(for: c))
            lines.append(fields.map(Self.csvEscape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Row status (color)

    func status(for c: Connection) -> RowStatus? {
        if removedIDs.contains(c.id) { return .removed }
        if addedIDs.contains(c.id) { return .added }
        if modifiedIDs.contains(c.id) { return .modified }
        if isUnsigned(c) { return .unsigned }
        if c.isLoopback { return .loopback }
        if c.isListening { return .listening }
        if c.user == "root" { return .root }
        return nil
    }
}
