//
//  ContentView.swift
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
import UniformTypeIdentifiers
import TCPV4MACCore
#if canImport(Darwin)
import Darwin
#endif

struct ContentView: View {
    @ObservedObject var model: ConnectionsViewModel
    @State private var selection = Set<Connection.ID>()
    @State private var showLegend = false
    @State private var showAdminSheet = false
    @State private var resetToken = 0
    @AppStorage("showInspector") private var showInspector = true
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(SettingsKey.showProcessIcons) private var showProcessIcons = true
    @AppStorage(SettingsKey.autoRefreshOnLaunch) private var autoRefreshOnLaunch = true

    /// Rows shown: search-filtered snapshot (the native table sorts internally).
    private var rows: [Connection] { model.visibleConnections }

    private func clearFiltersAndSearch() {
        model.searchText = ""
        model.filter.reset()
    }

    /// Friendly overlay when the table has no rows to show.
    @ViewBuilder private var emptyState: some View {
        if rows.isEmpty {
            if model.lastUpdated == nil && model.lastError == nil {
                // Initial load is sub-second — show nothing (no spinner flash, and
                // no misleading "No connections") until the first snapshot lands.
                Color.clear
            } else if let error = model.lastError {
                CompatUnavailableView {
                    Label("Couldn't read connections", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { model.refreshNow() }
                }
            } else if !model.searchText.isEmpty || model.filter.isActive {
                CompatUnavailableView {
                    Label("No matching connections", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Nothing matches the current search or filters.")
                } actions: {
                    Button("Clear filters & search") { clearFiltersAndSearch() }
                }
            } else {
                CompatUnavailableView("No connections", systemImage: "network.slash")
            }
        }
    }

    /// Exports ALL connections to a CSV file chosen via a save panel.
    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "tcpv4mac-connections.csv"
        panel.title = "Export connections"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? model.csvForAllConnections().write(to: url, atomically: true, encoding: .utf8)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                if let error = model.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.orange.opacity(0.12))
                }

                DashboardView(model: model)
                Divider()
                ConnectionsTable(model: model, rows: rows, selection: $selection,
                                 resetToken: resetToken, showIcons: showProcessIcons)
                    .overlay { emptyState }
                Divider()
                statusBar
            }
            .frame(maxWidth: .infinity)

            if showInspector {
                Divider()
                InspectorView(details: model.selectedDetails)
                    .frame(width: 280)
            }
        }
        .sheet(isPresented: $showAdminSheet) { AdminPasswordSheet() }
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        .onExitCommand { clearFiltersAndSearch() }
        .onChange(of: selection) { newValue in model.setSelection(newValue) }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search process, IP, port, PID…")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.togglePause()
                } label: {
                    Label(model.isPaused ? "Resume" : "Pause",
                          systemImage: model.isPaused ? "play.fill" : "pause.fill")
                }
                .help(model.isPaused ? "Resume auto-refresh" : "Pause auto-refresh")

                Button {
                    model.refreshNow()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh now")

                Picker("Refresh rate", selection: $model.interval) {
                    ForEach(RefreshInterval.allCases, id: \.self) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                .pickerStyle(.menu)
                .help("Auto-refresh interval")

                filterMenu
                columnsMenu

                if model.filter.isActive || !model.searchText.isEmpty {
                    Button(role: .cancel) {
                        clearFiltersAndSearch()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .help("Clear search and filters")
                }

                Button {
                    showLegend.toggle()
                } label: {
                    Label("Legend", systemImage: "paintpalette")
                }
                .help("Color legend")
                .popover(isPresented: $showLegend, arrowEdge: .bottom) { legend }

                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle inspector")

                Button {
                    exportCSV()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export all connections to CSV")

                Menu {
                    if getuid() != 0 {
                        Button("Run as Administrator…") {
                            showAdminSheet = true
                        }
                    }
                    Divider()
                    Button("Uninstall TCPV4MAC…", role: .destructive) {
                        Uninstaller.confirmAndUninstall()
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .help("More actions")
            }
        }
        .task {
            model.start()
            if !autoRefreshOnLaunch { model.setPaused(true) }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            if rows.count != model.totalCount {
                Text("Showing \(rows.count) of \(model.totalCount)")
            } else {
                Text("\(model.totalCount) connections")
            }
            if !selection.isEmpty {
                Text("· \(selection.count) selected").foregroundStyle(.secondary)
            }
            if model.isPaused {
                Label("Paused", systemImage: "pause.circle.fill").foregroundStyle(.orange)
            }
            if getuid() == 0 {
                Label("Admin (all users)", systemImage: "lock.shield.fill").foregroundStyle(.blue)
            }
            Spacer()
            Text("\(model.refreshCount) refreshes").foregroundStyle(.secondary).monospacedDigit()
            if let updated = model.lastUpdated {
                Text("· updated \(updated.formatted(date: .omitted, time: .standard))")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // Top-level toolbar menu (not nested) — nesting a Menu inside the ⋯ Menu made
    // SwiftUI close it on hover. This mirrors the working filter menu.
    private var columnsMenu: some View {
        Menu {
            ForEach(ConnectionsTable.columns.filter { $0.id != "icon" }, id: \.id) { col in
                Toggle(col.title, isOn: Binding(
                    get: { !model.isColumnHidden(col.id) },
                    set: { model.setColumn(col.id, hidden: !$0) }
                ))
            }
            Divider()
            Button("Show All Columns") { model.showAllColumns() }
                .disabled(model.hiddenColumns.isEmpty)
            Button("Restore Default View") { resetToken += 1 }
                .help("Restore default column order, width, visibility and sort")
        } label: {
            Label("Columns", systemImage: "tablecells")
        }
        .menuStyle(.borderlessButton)
        .help("Show or hide columns")
    }

    private var filterMenu: some View {
        Menu {
            Section("IP version") {
                Toggle("IPv4", isOn: $model.filter.ipv4)
                Toggle("IPv6", isOn: $model.filter.ipv6)
            }
            Section("Protocol") {
                Toggle("TCP", isOn: $model.filter.tcp)
                Toggle("UDP", isOn: $model.filter.udp)
            }
            Section("State") {
                Toggle("Listening", isOn: $model.filter.listening)
                Toggle("Established", isOn: $model.filter.established)
                Toggle("Other", isOn: $model.filter.otherState)
            }
            Section("Scope") {
                Toggle("Loopback", isOn: $model.filter.loopback)
                Toggle("External", isOn: $model.filter.external)
            }
            Divider()
            Button("Reset filters") { model.filter.reset() }
                .disabled(!model.filter.isActive)
        } label: {
            Label("Filter", systemImage: model.filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .help("Filter connections")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color legend").font(.headline)
            ForEach(RowStatus.allCases, id: \.self) { status in
                swatch(status.color, status.label)
            }
        }
        .padding(14)
    }

    private func swatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label)
        }
        .font(.callout)
    }
}
