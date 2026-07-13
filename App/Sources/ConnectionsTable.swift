//
//  ConnectionsTable.swift
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

import SwiftUI
import AppKit
import TCPV4MACCore
#if canImport(Darwin)
import Darwin
#endif

/// Native `NSTableView` wrapper: unlimited columns, stable reorder/hide/show,
/// double-click-divider autofit, and full-row background colors. Replaces the
/// SwiftUI `Table` (which desynced/crashed with >10 columns + customization).
struct ConnectionsTable: NSViewRepresentable {
    let model: ConnectionsViewModel
    let rows: [Connection]
    @Binding var selection: Set<Connection.ID>
    /// Incremented by the "Restore Default View" action to reset columns + sort.
    var resetToken: Int = 0
    /// When false, the icon column shows a neutral placeholder instead of icons.
    var showIcons: Bool = true

    /// Column descriptors (id, title, width, numeric sort, monospaced).
    struct Col { let id: String; let title: String; let width: CGFloat; let numeric: Bool; let mono: Bool }
    static let columns: [Col] = [
        Col(id: "icon",          title: "",               width: 40,  numeric: false, mono: false),
        Col(id: "application",   title: "Application",    width: 150, numeric: false, mono: false),
        Col(id: "pid",           title: "PID",            width: 60,  numeric: true,  mono: true),
        Col(id: "user",          title: "User",           width: 130, numeric: false, mono: false),
        Col(id: "proto",         title: "Proto",          width: 52,  numeric: false, mono: false),
        Col(id: "state",         title: "State",          width: 110, numeric: false, mono: false),
        Col(id: "localAddress",  title: "Local Address",  width: 130, numeric: false, mono: true),
        Col(id: "localPort",     title: "Local Port",     width: 74,  numeric: true,  mono: true),
        Col(id: "remoteAddress", title: "Remote Address", width: 130, numeric: false, mono: true),
        Col(id: "remotePort",    title: "Remote Port",    width: 82,  numeric: true,  mono: true),
        Col(id: "cpu",           title: "CPU",            width: 62,  numeric: true,  mono: true),
        Col(id: "memory",        title: "Memory",         width: 84,  numeric: true,  mono: true),
        Col(id: "threads",       title: "Threads",        width: 66,  numeric: true,  mono: true),
        Col(id: "arch",          title: "Arch",           width: 66,  numeric: false, mono: false),
        Col(id: "signature",     title: "Signature",      width: 170, numeric: false, mono: false),
        Col(id: "bundleID",      title: "Bundle ID",      width: 170, numeric: false, mono: false),
        Col(id: "executable",    title: "Executable",     width: 240, numeric: false, mono: false),
        Col(id: "duration",      title: "Duration",       width: 72,  numeric: true,  mono: true),
    ]

    static let sortKeyDefault = "TCPV4MAC.sortKey"
    static let sortAscendingDefault = "TCPV4MAC.sortAscending"

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = ConnectionsNSTableView()
        table.onCopy = { [coordinator = context.coordinator] in coordinator.copySelectedRows() }
        table.doubleAction = #selector(Coordinator.tableDoubleClicked)
        table.style = .inset
        table.rowHeight = 26   // a little room for the 20px process icons
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = true
        table.allowsColumnReordering = true
        table.allowsColumnResizing = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.rowSizeStyle = .default
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.target = context.coordinator

        for col in Self.columns {
            let column = NSTableColumn(identifier: .init(col.id))
            column.title = col.title
            column.width = col.width
            column.minWidth = 40
            column.headerCell.alignment = .center
            if col.id != "icon" {
                column.sortDescriptorPrototype = NSSortDescriptor(key: col.id, ascending: true)
            }
            table.addTableColumn(column)
        }

        // Enable autosave AFTER columns exist so AppKit applies the saved order /
        // width / hidden state onto them (setting it earlier persists nothing).
        table.autosaveName = "TCPV4MAC.connectionsTable"
        table.autosaveTableColumns = true

        // Restore the last-used sort (autosave covers columns, not sort).
        let savedKey = UserDefaults.standard.string(forKey: Self.sortKeyDefault) ?? "application"
        let savedAscending = UserDefaults.standard.object(forKey: Self.sortAscendingDefault) as? Bool ?? true
        context.coordinator.setInitialSort(key: savedKey, ascending: savedAscending)
        table.sortDescriptors = [NSSortDescriptor(key: savedKey, ascending: savedAscending)]

        // Header: double-click divider to autofit + right-click menu to hide/show.
        let header = AutofitHeaderView()
        header.onAutofit = { [weak table] index in
            guard let table else { return }
            context.coordinator.autofit(column: index, in: table)
        }
        table.headerView = header
        // Right-click header → show/hide columns (native menu, model-driven).
        let headerMenu = NSMenu()
        headerMenu.delegate = context.coordinator
        context.coordinator.headerMenu = headerMenu
        header.menu = headerMenu

        // Right-click context menu (built per clicked row / selection).
        let menu = NSMenu()
        menu.delegate = context.coordinator
        table.menu = menu

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        context.coordinator.tableView = table
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            context.coordinator.restoreDefaults()
        }
        context.coordinator.apply(rows: rows, selection: selection)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        var parent: ConnectionsTable
        weak var tableView: NSTableView?
        private(set) var sorted: [Connection] = []
        private var sortKey = "application"
        private var ascending = true
        private var isProgrammaticSelection = false
        var lastResetToken = 0

        init(_ parent: ConnectionsTable) { self.parent = parent }

        func setInitialSort(key: String, ascending: Bool) {
            sortKey = key
            self.ascending = ascending
        }

        /// Resets columns (all visible, default order + width) and sort to defaults.
        func restoreDefaults() {
            guard let table = tableView else { return }
            parent.model.showAllColumns()   // clear hidden state (model is source of truth)
            for col in ConnectionsTable.columns {
                if let column = table.tableColumn(withIdentifier: .init(col.id)) {
                    column.isHidden = false
                    column.width = col.width
                }
            }
            for (target, col) in ConnectionsTable.columns.enumerated() {
                let current = table.column(withIdentifier: .init(col.id))
                if current >= 0, current != target { table.moveColumn(current, toColumn: target) }
            }
            sortKey = "application"; ascending = true
            UserDefaults.standard.set("application", forKey: ConnectionsTable.sortKeyDefault)
            UserDefaults.standard.set(true, forKey: ConnectionsTable.sortAscendingDefault)
            table.sortDescriptors = [NSSortDescriptor(key: "application", ascending: true)]
        }

        func apply(rows: [Connection], selection: Set<Connection.ID>) {
            sorted = sortRows(rows)
            guard let table = tableView else { return }
            // Column visibility is model-driven (single source of truth).
            for column in table.tableColumns {
                let hidden = parent.model.isColumnHidden(column.identifier.rawValue)
                if column.isHidden != hidden { column.isHidden = hidden }
            }
            table.reloadData()
            isProgrammaticSelection = true
            let indexes = IndexSet(sorted.indices.filter { selection.contains(sorted[$0].id) })
            table.selectRowIndexes(indexes, byExtendingSelection: false)
            isProgrammaticSelection = false
        }

        // MARK: Data source
        func numberOfRows(in tableView: NSTableView) -> Int { sorted.count }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let d = tableView.sortDescriptors.first, let key = d.key else { return }
            sortKey = key; ascending = d.ascending
            UserDefaults.standard.set(key, forKey: ConnectionsTable.sortKeyDefault)
            UserDefaults.standard.set(d.ascending, forKey: ConnectionsTable.sortAscendingDefault)
            // `apply` re-sorts from the live rows and reloads — no need to sort or
            // reload here first (that was doing the work twice per sort change).
            apply(rows: parent.rows, selection: parent.selection)
        }

        /// Columns rendered in a secondary (dimmed) color when the row has no status.
        static let secondaryColumns: Set<String> = ["user", "executable", "bundleID", "duration"]

        // MARK: Delegate
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn else { return nil }
            let id = tableColumn.identifier.rawValue
            let connection = sorted[row]
            let col = ConnectionsTable.columns.first { $0.id == id }

            if id == "icon" {
                let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView ?? Self.makeIconCell(id: tableColumn.identifier)
                cell.imageView?.image = parent.showIcons ? parent.model.icon(for: connection) : nil
                return cell
            }

            // Personal style: everything centered except the Application column.
            let cell = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as? NSTableCellView
                ?? Self.makeTextCell(id: tableColumn.identifier, mono: col?.mono ?? false,
                                     alignment: id == "application" ? .left : .center)
            let value = cellText(connection, id)
            cell.textField?.stringValue = value
            cell.toolTip = value   // full value on hover (handy for long paths/IPs)
            // Color rule → text tint (falls back to secondary/label when no status).
            if let status = parent.model.status(for: connection) {
                cell.textField?.textColor = status.textColor
            } else {
                cell.textField?.textColor = Self.secondaryColumns.contains(id) ? .secondaryLabelColor : .labelColor
            }
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isProgrammaticSelection, let table = tableView else { return }
            let ids = Set(table.selectedRowIndexes.compactMap { sorted.indices.contains($0) ? sorted[$0].id : nil })
            parent.selection = ids
        }

        // MARK: Cell text
        func cellText(_ c: Connection, _ id: String) -> String {
            switch id {
            case "application": return c.processName
            case "pid": return "\(c.pid)"
            case "user": return c.user
            case "proto": return c.protocolType.rawValue
            case "state": return c.state?.displayName ?? "—"
            case "localAddress": return c.localIP
            case "localPort": return "\(c.localPort)"
            case "remoteAddress": return c.remoteIP ?? "—"
            case "remotePort": return c.remotePort.map(String.init) ?? "—"
            case "cpu": return parent.model.cpuText(for: c)
            case "memory": return parent.model.memoryText(for: c)
            case "threads": return parent.model.threadsText(for: c)
            case "arch": return parent.model.architectureText(for: c)
            case "signature": return parent.model.signatureText(for: c)
            case "bundleID": return parent.model.bundleID(for: c) ?? "—"
            case "executable": return c.executablePath ?? "—"
            case "duration": return parent.model.durationText(for: c)
            default: return ""
            }
        }

        // MARK: Sorting
        private func sortRows(_ rows: [Connection]) -> [Connection] {
            let key = sortKey, asc = ascending
            let model = parent.model
            return rows.sorted { a, b in
                let result: Bool
                switch key {
                case "pid": result = a.pid < b.pid
                case "localPort": result = a.localPort < b.localPort
                case "remotePort": result = (a.remotePort ?? -1) < (b.remotePort ?? -1)
                case "cpu": result = (model.cpuValue(for: a) ?? -1) < (model.cpuValue(for: b) ?? -1)
                case "memory": result = (model.memoryValue(for: a) ?? 0) < (model.memoryValue(for: b) ?? 0)
                case "threads": result = (model.threadsValue(for: a) ?? -1) < (model.threadsValue(for: b) ?? -1)
                case "duration": result = model.durationSeconds(for: a) < model.durationSeconds(for: b)
                default: result = cellText(a, key).localizedCaseInsensitiveCompare(cellText(b, key)) == .orderedAscending
                }
                return asc ? result : !result
            }
        }

        // MARK: Autofit
        func autofit(column index: Int, in table: NSTableView) {
            guard table.tableColumns.indices.contains(index) else { return }
            let column = table.tableColumns[index]
            let id = column.identifier.rawValue
            guard id != "icon" else { return }
            let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            var maxWidth = (column.title as NSString).size(withAttributes: attrs).width
            for connection in sorted.prefix(1000) {
                let w = (cellText(connection, id) as NSString).size(withAttributes: attrs).width
                if w > maxWidth { maxWidth = w }
            }
            // Fit the widest cell. The upper bound is generous so long values
            // (full executable paths, bundle ids) expand fully instead of being
            // clipped at a narrow cap.
            column.width = min(max(maxWidth + 18, column.minWidth), 2000)
        }

        // MARK: Context menu
        private var contextTargets: [Connection] = []
        private var contextColumnID: String?
        private var contextClicked: Connection?
        weak var headerMenu: NSMenu?

        /// Rows the menu acts on: the selection if the click was inside it, else
        /// just the clicked row.
        private func currentTargets() -> [Connection] {
            guard let table = tableView, table.clickedRow >= 0,
                  sorted.indices.contains(table.clickedRow) else { return [] }
            if table.selectedRowIndexes.contains(table.clickedRow) {
                return table.selectedRowIndexes.compactMap { sorted.indices.contains($0) ? sorted[$0] : nil }
            }
            return [sorted[table.clickedRow]]
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            if menu === headerMenu { buildColumnMenu(menu); return }
            menu.removeAllItems()
            contextTargets = currentTargets()
            guard let first = contextTargets.first else { return }

            // Which cell was right-clicked (for "Copy Cell").
            if let table = tableView, table.clickedRow >= 0, sorted.indices.contains(table.clickedRow) {
                contextClicked = sorted[table.clickedRow]
                let clickedCol = table.clickedColumn
                contextColumnID = (clickedCol >= 0) ? table.tableColumns[clickedCol].identifier.rawValue : nil
            } else {
                contextClicked = nil; contextColumnID = nil
            }

            func add(_ title: String, _ action: Selector) {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }

            if let colID = contextColumnID, colID != "icon",
               let title = ConnectionsTable.columns.first(where: { $0.id == colID })?.title {
                add("Copy \(title) Cell", #selector(copyCellFromMenu))
            }
            add(contextTargets.count > 1 ? "Copy Rows" : "Copy Row", #selector(copyRowFromMenu))
            let copyAs = NSMenu()
            let csvItem = NSMenuItem(title: "CSV", action: #selector(copyCSVFromMenu), keyEquivalent: "")
            csvItem.target = self; copyAs.addItem(csvItem)
            let jsonItem = NSMenuItem(title: "JSON", action: #selector(copyJSONFromMenu), keyEquivalent: "")
            jsonItem.target = self; copyAs.addItem(jsonItem)
            let copyAsParent = NSMenuItem(title: "Copy as", action: nil, keyEquivalent: "")
            copyAsParent.submenu = copyAs
            menu.addItem(copyAsParent)
            menu.addItem(.separator())
            add("Copy Local Address", #selector(copyLocalAddress))
            if contextTargets.contains(where: { $0.remoteIP != nil }) {
                add("Copy Remote Address", #selector(copyRemoteAddress))
            }
            add("Copy PID", #selector(copyPID))
            if parent.model.bundleID(for: first) != nil {
                add("Copy Bundle ID", #selector(copyBundleID))
            }
            if first.executablePath != nil {
                add("Copy Executable Path", #selector(copyExecutablePath))
            }
            if first.executablePath != nil {
                menu.addItem(.separator())
                add("Reveal in Finder", #selector(revealInFinder))
                addTerminalMenu(to: menu)
            }
            menu.addItem(.separator())
            let count = Set(contextTargets.map(\.pid)).count
            add(count > 1 ? "Kill \(count) Processes…" : "Kill Process…", #selector(killProcess))
        }

        // MARK: Copy full rows / double-click

        /// Copies the given connections as tab-separated rows (all data columns).
        func copyRows(_ connections: [Connection]) {
            guard !connections.isEmpty else { return }
            let columns = ConnectionsTable.columns.filter { $0.id != "icon" }
            let text = connections
                .map { conn in columns.map { cellText(conn, $0.id) }.joined(separator: "\t") }
                .joined(separator: "\n")
            copyToPasteboard(text)
        }

        /// ⌘C: copy the current selection.
        func copySelectedRows() {
            guard let table = tableView else { return }
            let rows = table.selectedRowIndexes.compactMap { sorted.indices.contains($0) ? sorted[$0] : nil }
            copyRows(rows)
        }

        // MARK: Header column show/hide menu (model-driven)
        private func buildColumnMenu(_ menu: NSMenu) {
            menu.removeAllItems()
            for col in ConnectionsTable.columns where col.id != "icon" {
                let item = NSMenuItem(title: col.title, action: #selector(toggleColumnMenu(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = col.id
                item.state = parent.model.isColumnHidden(col.id) ? .off : .on
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let showAll = NSMenuItem(title: "Show All Columns", action: #selector(showAllColumnsMenu), keyEquivalent: "")
            showAll.target = self
            menu.addItem(showAll)
        }

        @objc private func toggleColumnMenu(_ sender: NSMenuItem) {
            guard let id = sender.representedObject as? String else { return }
            parent.model.setColumn(id, hidden: !parent.model.isColumnHidden(id))
            if let table = tableView, let column = table.tableColumn(withIdentifier: .init(id)) {
                column.isHidden = parent.model.isColumnHidden(id)   // immediate feedback
            }
        }

        @objc private func showAllColumnsMenu() {
            parent.model.showAllColumns()
            tableView?.tableColumns.forEach { $0.isHidden = false }
        }

        @objc private func copyRowFromMenu() { copyRows(contextTargets) }

        @objc private func copyCellFromMenu() {
            guard let colID = contextColumnID, let conn = contextClicked else { return }
            copyToPasteboard(cellText(conn, colID))
        }

        @objc private func copyCSVFromMenu() {
            let cols = ConnectionsTable.columns.filter { $0.id != "icon" }
            let header = cols.map { Self.csvEscape($0.title) }.joined(separator: ",")
            let rows = contextTargets.map { c in cols.map { Self.csvEscape(cellText(c, $0.id)) }.joined(separator: ",") }
            copyToPasteboard(([header] + rows).joined(separator: "\n"))
        }

        @objc private func copyJSONFromMenu() {
            let cols = ConnectionsTable.columns.filter { $0.id != "icon" }
            let objects = contextTargets.map { c in
                Dictionary(uniqueKeysWithValues: cols.map { ($0.id, cellText(c, $0.id)) })
            }
            if let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                copyToPasteboard(text)
            }
        }

        private static func csvEscape(_ s: String) -> String {
            guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        /// Double-click a row → reveal the inspector (which follows the selection).
        @objc func tableDoubleClicked() {
            guard let table = tableView, table.clickedRow >= 0 else { return }
            UserDefaults.standard.set(true, forKey: "showInspector")
        }

        private func copyToPasteboard(_ string: String) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(string, forType: .string)
        }

        @objc private func copyLocalAddress() {
            copyToPasteboard(contextTargets.map { "\($0.localIP):\($0.localPort)" }.joined(separator: "\n"))
        }
        @objc private func copyRemoteAddress() {
            copyToPasteboard(contextTargets.compactMap { c in c.remoteIP.map { "\($0):\(c.remotePort ?? 0)" } }.joined(separator: "\n"))
        }
        @objc private func copyPID() {
            copyToPasteboard(contextTargets.map { "\($0.pid)" }.joined(separator: "\n"))
        }
        @objc private func copyBundleID() {
            copyToPasteboard(contextTargets.compactMap { parent.model.bundleID(for: $0) }.joined(separator: "\n"))
        }
        @objc private func copyExecutablePath() {
            copyToPasteboard(contextTargets.compactMap(\.executablePath).joined(separator: "\n"))
        }
        @objc private func revealInFinder() {
            guard let path = contextTargets.first?.executablePath else { return }
            let target = ProcessEnricher.appBundlePath(forExecutable: path) ?? path
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: target)])
        }
        private func terminalItem(title: String, bundleID: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(openInTerminal(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = bundleID
            return item
        }

        private func addTerminalMenu(to menu: NSMenu) {
            let terminals = TerminalApps.installed()
            guard !terminals.isEmpty else { return }
            let preferred = UserDefaults.standard.string(forKey: SettingsKey.preferredTerminal) ?? ""

            // Fixed choice (from Settings or a previous pick) → single item, no submenu.
            if let chosen = terminals.first(where: { $0.bundleID == preferred }) {
                menu.addItem(terminalItem(title: "Open in \(chosen.name)", bundleID: chosen.bundleID))
            } else if terminals.count == 1 {
                menu.addItem(terminalItem(title: "Open in \(terminals[0].name)", bundleID: terminals[0].bundleID))
            } else {
                // Ask: submenu of all installed terminals.
                let parent = NSMenuItem(title: "Open Terminal Here", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                for term in terminals {
                    submenu.addItem(terminalItem(title: term.name, bundleID: term.bundleID))
                }
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        @objc private func openInTerminal(_ sender: NSMenuItem) {
            guard let bundleID = sender.representedObject as? String,
                  let appURL = TerminalApps.url(forBundleID: bundleID),
                  let path = contextTargets.first?.executablePath else { return }
            // Remember the choice → next time it's a single item, not the submenu.
            UserDefaults.standard.set(bundleID, forKey: SettingsKey.preferredTerminal)
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
            NSWorkspace.shared.open([dir], withApplicationAt: appURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        }
        @objc private func killProcess() {
            let pids = Set(contextTargets.map(\.pid))
            guard !pids.isEmpty else { return }
            let names = Set(contextTargets.map(\.processName)).sorted().joined(separator: ", ")
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = pids.count > 1 ? "Kill \(pids.count) processes?" : "Kill “\(names)”?"
            alert.informativeText = "This sends SIGTERM to: \(names). Unsaved work may be lost."
            alert.addButton(withTitle: "Kill")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            let nameByPID = Dictionary(contextTargets.map { ($0.pid, $0.processName) },
                                       uniquingKeysWith: { first, _ in first })
            var failed: [String] = []
            var permissionDenied = false
            for pid in pids where kill(Int32(pid), SIGTERM) != 0 {
                if errno == EPERM { permissionDenied = true }
                failed.append(nameByPID[pid] ?? "\(pid)")
            }
            guard !failed.isEmpty else { return }

            let err = NSAlert()
            err.alertStyle = .warning
            err.messageText = failed.count > 1
                ? "Couldn't kill \(failed.count) processes"
                : "Couldn't kill “\(failed[0])”"
            err.informativeText = (permissionDenied && getuid() != 0)
                ? "Permission denied — \(failed.joined(separator: ", ")) belong to root or another "
                    + "user. Use the ⋯ menu → “Run as Administrator…” to signal them."
                : "The signal could not be sent to: \(failed.joined(separator: ", ")). "
                    + "They may have already exited."
            err.runModal()
        }

        // MARK: Cell factories
        static func makeTextCell(id: NSUserInterfaceItemIdentifier, mono: Bool,
                                 alignment: NSTextAlignment = .left) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.lineBreakMode = .byTruncatingTail
            tf.alignment = alignment
            tf.font = mono ? .monospacedDigitSystemFont(ofSize: 13, weight: .regular) : .systemFont(ofSize: 13)
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }

        static func makeIconCell(id: NSUserInterfaceItemIdentifier) -> NSTableCellView {
            let cell = NSTableCellView()
            cell.identifier = id
            let iv = NSImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(iv)
            cell.imageView = iv
            NSLayoutConstraint.activate([
                iv.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                iv.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 20),
                iv.heightAnchor.constraint(equalToConstant: 20),
            ])
            return cell
        }
    }
}

/// NSTableView that forwards the standard Copy command (⌘C / Edit ▸ Copy) so the
/// selected rows can be copied.
final class ConnectionsNSTableView: NSTableView {
    var onCopy: (() -> Void)?
    @objc func copy(_ sender: Any?) { onCopy?() }
}

/// Header that autofits a column on a double-click near its divider.
final class AutofitHeaderView: NSTableHeaderView {
    var onAutofit: ((Int) -> Void)?
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let col = column(at: point)
            if col >= 0 {
                let rect = headerRect(ofColumn: col)
                if abs(point.x - rect.maxX) <= 6 { onAutofit?(col); return }
                if col > 0, abs(point.x - rect.minX) <= 6 { onAutofit?(col - 1); return }
            }
        }
        super.mouseDown(with: event)
    }
}
