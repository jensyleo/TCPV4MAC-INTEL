//
//  TCPState.swift
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

/// TCP connection state as reported by `lsof` in the `TST=` field.
public enum TCPState: String, Sendable, Hashable, CaseIterable {
    case listen
    case established
    case closeWait
    case finWait1
    case finWait2
    case lastAck
    case timeWait
    case synSent
    case synReceived
    case closed
    case closing
    case idle
    case bound
    case unknown

    /// Maps an `lsof` `TST=` token (e.g. `LISTEN`, `CLOSE_WAIT`, `SYN_SENT`)
    /// to a case. Matching is case-insensitive and tolerant of separators.
    public init(lsofState raw: String) {
        let normalized = raw
            .uppercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
        switch normalized {
        case "LISTEN": self = .listen
        case "ESTABLISHED": self = .established
        case "CLOSEWAIT": self = .closeWait
        case "FINWAIT1": self = .finWait1
        case "FINWAIT2": self = .finWait2
        case "LASTACK": self = .lastAck
        case "TIMEWAIT": self = .timeWait
        case "SYNSENT": self = .synSent
        case "SYNRCVD", "SYNRECEIVED": self = .synReceived
        case "CLOSED", "CLOSE": self = .closed
        case "CLOSING": self = .closing
        case "IDLE": self = .idle
        case "BOUND": self = .bound
        default: self = .unknown
        }
    }

    /// Human-readable label matching common tooling (e.g. `CLOSE_WAIT`).
    public var displayName: String {
        switch self {
        case .listen: return "LISTEN"
        case .established: return "ESTABLISHED"
        case .closeWait: return "CLOSE_WAIT"
        case .finWait1: return "FIN_WAIT_1"
        case .finWait2: return "FIN_WAIT_2"
        case .lastAck: return "LAST_ACK"
        case .timeWait: return "TIME_WAIT"
        case .synSent: return "SYN_SENT"
        case .synReceived: return "SYN_RCVD"
        case .closed: return "CLOSED"
        case .closing: return "CLOSING"
        case .idle: return "IDLE"
        case .bound: return "BOUND"
        case .unknown: return "UNKNOWN"
        }
    }
}
