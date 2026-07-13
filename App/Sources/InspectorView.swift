//
//  InspectorView.swift
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

/// Trailing inspector: process detail for the selected connection.
struct InspectorView: View {
    let details: ProcessDetails?

    var body: some View {
        Group {
            if let details {
                content(details)
            } else {
                ContentUnavailableView("No selection",
                                       systemImage: "sidebar.right",
                                       description: Text("Select a single connection to see process details."))
            }
        }
        .frame(minWidth: 260)
    }

    private func content(_ d: ProcessDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    if let icon = d.icon {
                        Image(nsImage: icon).resizable().frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "app.dashed").font(.largeTitle).foregroundStyle(.tertiary)
                    }
                    VStack(alignment: .leading) {
                        Text(d.connection.processName).font(.headline)
                        Text(d.bundleID ?? "—").font(.caption).foregroundStyle(.secondary)
                    }
                }

                section("Process") {
                    row("PID", "\(d.connection.pid)")
                    row("Parent PID", d.connection.parentPID.map { "\($0)" } ?? "—")
                    row("User", d.connection.user)
                    row("Architecture", d.architectureText)
                    row("Signature", d.signature.displayText,
                        tint: d.signature.isUnsigned ? .orange : nil)
                    row("Executable", d.connection.executablePath ?? "—", mono: true)
                }

                section("Resources") {
                    row("CPU", d.cpuText)
                    row("Memory", d.memoryText)
                    row("Threads", d.threadsText)
                    row("Connections", "\(d.connectionCount)")
                }

                section("Selected connection") {
                    row("Protocol", d.connection.protocolType.rawValue)
                    row("State", d.connection.state?.displayName ?? "—")
                    row("Local", "\(d.connection.localIP):\(d.connection.localPort)", mono: true)
                    row("Remote", d.connection.remoteIP.map { "\($0):\(d.connection.remotePort ?? 0)" } ?? "—", mono: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ label: String, _ value: String, tint: Color? = nil, mono: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value)
                .foregroundStyle(tint ?? .primary)
                .font(mono ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}
