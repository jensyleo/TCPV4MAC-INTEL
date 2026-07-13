//
//  AdminPasswordSheet.swift
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

/// In-app password sheet. The typed password is validated with `sudo` and used
/// to relaunch the app as root — no Terminal, no periodic re-prompt.
struct AdminPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorText: String?
    @State private var busy = false
    @State private var copied = false

    /// Command-line equivalent. `perl` (always present on macOS; `setsid` is not)
    /// forks and starts a **new session** so the app fully detaches from the
    /// terminal — `nohup &` alone leaves it in the terminal's session, so closing
    /// the window still kills it. The parent exits immediately.
    ///
    /// On success it then `pkill`s the current-user instance (by real uid, so the
    /// new root instance — uid 0 — is untouched), mirroring the in-app relaunch.
    /// Finally it walks up the process tree to the terminal app (the first
    /// `.app/Contents/MacOS/` ancestor of the shell) and `kill -9`s it. SIGKILL
    /// can't be intercepted, so no "terminate running processes?" dialog appears,
    /// and because it targets the app process itself it works for **any** terminal
    /// (Terminal, iTerm, Warp, Ghostty, kitty, WezTerm, Alacritty, Hyper) — not
    /// just Terminal.app. The relaunched root app already ran `setsid`, so it
    /// survives its terminal being killed. A wrong password fails `sudo` and the
    /// whole `&& { … }` group is skipped, leaving the window open to retry.
    private var cliCommand: String {
        let path = Bundle.main.executableURL?.path ?? "/Applications/TCPV4MAC.app/Contents/MacOS/TCPV4MAC"
        let daemonize = "use POSIX; exit if fork; POSIX::setsid(); "
            + "open(STDIN,\"</dev/null\"); open(STDOUT,\">/dev/null\"); open(STDERR,\">/dev/null\"); exec(@ARGV)"
        let killTerminal = "t=$PPID; while [ \"$t\" -gt 1 ]; do "
            + "case \"$(ps -o comm= -p $t)\" in *.app/Contents/MacOS/*) break;; esac; "
            + "t=$(ps -o ppid= -p $t | tr -d ' '); done; [ \"$t\" -gt 1 ] && kill -9 \"$t\" || exit"
        return "sudo perl -e '\(daemonize)' \"\(path)\" && { pkill -x -U $(id -u) TCPV4MAC; \(killTerminal); }"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Run TCPV4MAC as administrator").font(.headline)
                    Text("Enter your macOS account password. TCPV4MAC relaunches with root privileges to show connections from all users and system processes.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit { authenticate() }
                .disabled(busy)

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if busy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.disabled(busy)
                Button("Authenticate") { authenticate() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || password.isEmpty)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Prefer the command line? Run this in any terminal — it relaunches as admin, closes this instance, and closes the terminal app for you:")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(cliCommand)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cliCommand, forType: .string)
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy command")
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func authenticate() {
        guard !busy, !password.isEmpty else { return }
        busy = true
        errorText = nil
        let pw = password
        Task {
            let outcome = await SudoRelaunch.relaunchAsRoot(password: pw)
            busy = false
            switch outcome {
            case .success:
                password = ""
                SudoRelaunch.quitWhenRootUp()
                dismiss()
            case .wrongPassword:
                password = ""
                errorText = "Incorrect password. Please try again."
            case .failed(let message):
                errorText = "Could not run as administrator: \(message)"
            }
        }
    }
}
