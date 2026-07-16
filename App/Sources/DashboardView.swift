//
//  DashboardView.swift
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

/// Top summary cards. The protocol/state cards act as one-click quick filters;
/// "Total" clears filters + search. Active quick-filters are highlighted.
struct DashboardView: View {
    @ObservedObject var model: ConnectionsViewModel

    // A card is highlighted when its dimension is narrowing the results and this
    // flag is part of the kept set — so several state cards (e.g. Listening +
    // Established) can be lit at once, mirroring the filter menu.
    private var protoNarrowing: Bool { !(model.filter.tcp && model.filter.udp) }
    private var ipNarrowing: Bool { !(model.filter.ipv4 && model.filter.ipv6) }
    private var stateNarrowing: Bool { !(model.filter.listening && model.filter.established && model.filter.otherState) }
    private var tcpActive: Bool { model.filter.tcp && protoNarrowing }
    private var udpActive: Bool { model.filter.udp && protoNarrowing }
    private var ipv4Active: Bool { model.filter.ipv4 && ipNarrowing }
    private var ipv6Active: Bool { model.filter.ipv6 && ipNarrowing }
    private var listeningActive: Bool { model.filter.listening && stateNarrowing }
    private var establishedActive: Bool { model.filter.established && stateNarrowing }
    // Scope is loopback vs external — same two-way switch as IPv4/IPv6 and TCP/UDP.
    private var scopeNarrowing: Bool { !(model.filter.loopback && model.filter.external) }
    private var loopbackActive: Bool { model.filter.loopback && scopeNarrowing }
    private var externalActive: Bool { model.filter.external && scopeNarrowing }

    var body: some View {
        let s = model.summary   // all counts in a single pass over the snapshot
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                card("Total", "\(model.totalCount)", .primary, active: false, hint: "Clear filters & search") {
                    model.filter.reset(); model.searchText = ""
                }
                card("IPv4", "\(s.ipv4)", .orange, active: ipv4Active) { toggleIPVersion(v4: true) }
                card("IPv6", "\(s.ipv6)", .pink, active: ipv6Active) { toggleIPVersion(v4: false) }
                card("TCP", "\(s.tcp)", .blue, active: tcpActive) { toggleProtocol(tcp: true) }
                card("UDP", "\(s.udp)", .teal, active: udpActive) { toggleProtocol(tcp: false) }
                card("Listening", "\(s.listening)", .indigo, active: listeningActive) { toggleState(listening: true) }
                card("Established", "\(s.established)", .green, active: establishedActive) { toggleState(listening: false) }
                plainCard("Processes", "\(s.processes)",
                          hint: "Number of distinct processes that currently have connections")
                plainCard("Refresh", model.interval.displayName,
                          hint: "Auto-refresh interval")
                // Scope pair kept last and side by side, mirroring the
                // IPv4/IPv6 and TCP/UDP switches.
                card("Loopback", "\(s.loopback)", .purple, active: loopbackActive,
                     hint: "Show only loopback (localhost / 127.0.0.1 / ::1)") {
                    toggleScope(loopback: true)
                }
                card("External", "\(s.external)", .brown, active: externalActive,
                     hint: "Show only external (non-loopback) connections") {
                    toggleScope(loopback: false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: Quick-filter actions

    // Protocol is a two-way switch: TCP and UDP are the only options, so keeping
    // both is the same as "no protocol filter". A click isolates that protocol
    // (or switches to it); clicking the already-active one clears back to all.
    // (Both protocols at once = the "Total" card / an unfiltered protocol set.)
    private func toggleProtocol(tcp isTCP: Bool) {
        let alreadyOnly = isTCP ? tcpActive : udpActive
        if alreadyOnly {
            model.filter.tcp = true; model.filter.udp = true          // clear → all
        } else {
            model.filter.tcp = isTCP; model.filter.udp = !isTCP       // isolate / switch
        }
    }

    // Same two-way switch as protocol: only IPv4 and IPv6 exist, so keeping both
    // means "no IP-version filter".
    private func toggleIPVersion(v4 isV4: Bool) {
        let alreadyOnly = isV4 ? ipv4Active : ipv6Active
        if alreadyOnly {
            model.filter.ipv4 = true; model.filter.ipv6 = true        // clear → all
        } else {
            model.filter.ipv4 = isV4; model.filter.ipv6 = !isV4       // isolate / switch
        }
    }

    // Same two-way switch as protocol / IP version: only Loopback and External
    // exist, so keeping both means "no scope filter".
    private func toggleScope(loopback isLoopback: Bool) {
        let alreadyOnly = isLoopback ? loopbackActive : externalActive
        if alreadyOnly {
            model.filter.loopback = true; model.filter.external = true         // clear → all
        } else {
            model.filter.loopback = isLoopback; model.filter.external = !isLoopback  // isolate / switch
        }
    }

    // State has three buckets (Listening / Established / Other), so it is a true
    // multi-select: the first click isolates, further clicks add/remove others —
    // exactly like ticking the boxes in the filter menu (e.g. Listening +
    // Established). Clearing the last selection reverts to "show all".
    private func toggleState(listening isListening: Bool) {
        if !stateNarrowing {
            model.filter.listening = isListening                      // isolate
            model.filter.established = !isListening
            model.filter.otherState = false
        } else {
            if isListening { model.filter.listening.toggle() } else { model.filter.established.toggle() }
            if !model.filter.listening && !model.filter.established && !model.filter.otherState {
                model.filter.listening = true; model.filter.established = true; model.filter.otherState = true
            }
        }
    }

    // MARK: Cards

    private func card(_ label: String, _ value: String, _ tint: Color,
                      active: Bool, hint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            cardBody(label, value, tint, active: active)
        }
        .buttonStyle(.plain)
        .help(hint ?? "Filter: \(label)")
    }

    private func plainCard(_ label: String, _ value: String, hint: String) -> some View {
        cardBody(label, value, .primary, active: false).help(hint)
    }

    private func cardBody(_ label: String, _ value: String, _ tint: Color, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3).fontWeight(.semibold).monospacedDigit().foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 74, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(active ? AnyShapeStyle(tint.opacity(0.20)) : AnyShapeStyle(.quaternary.opacity(0.5)),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(active ? tint : .clear, lineWidth: 1.5))
    }
}
