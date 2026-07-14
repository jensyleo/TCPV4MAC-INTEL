//
//  SettingsView.swift
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
import TCPV4MACCore

/// Preferences window (⌘,). Appearance / icons live in `@AppStorage`; the
/// refresh interval is owned by the shared view model.
struct SettingsView: View {
    @ObservedObject var model: ConnectionsViewModel
    @AppStorage(SettingsKey.appearance) private var appearance = AppAppearance.system.rawValue
    @AppStorage(SettingsKey.showProcessIcons) private var showProcessIcons = true
    @AppStorage(SettingsKey.autoRefreshOnLaunch) private var autoRefreshOnLaunch = true
    @AppStorage(SettingsKey.preferredTerminal) private var preferredTerminal = ""

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("Refresh") {
                Picker("Interval", selection: $model.interval) {
                    ForEach(RefreshInterval.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Auto-refresh on launch", isOn: $autoRefreshOnLaunch)
            }

            Section("Table") {
                Toggle("Show process icons", isOn: $showProcessIcons)
            }

            Section("Terminal") {
                Picker("Open Terminal in", selection: $preferredTerminal) {
                    Text("Ask each time").tag("")
                    ForEach(TerminalApps.installed()) { Text($0.name).tag($0.bundleID) }
                }
            }

            Section {
                Text("Columns, sort order, filters and window layout are remembered automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .navigationTitle("Settings")
    }
}
