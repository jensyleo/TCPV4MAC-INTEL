//
//  RefreshEngine.swift
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

/// One tick of the refresh loop: either a fresh diff or a failure description.
public enum RefreshEvent: Sendable {
    case update(ConnectionDiff)
    case failure(String)
}

/// Drives `ConnectionRepository.refresh()` on a timer and publishes each result
/// through an `AsyncStream`. Supports pause/resume and live interval changes.
///
/// The engine owns *timing only*; all data work lives in the repository. The UI
/// layer consumes `events` and never touches `lsof` or the diff engine directly.
public actor RefreshEngine {

    private let repository: ConnectionRepository
    private var interval: RefreshInterval
    private var loopTask: Task<Void, Never>?
    private var isPaused = false

    /// Stream of refresh results. Consume with `for await event in engine.events`.
    public nonisolated let events: AsyncStream<RefreshEvent>
    private let continuation: AsyncStream<RefreshEvent>.Continuation

    public init(repository: ConnectionRepository, interval: RefreshInterval = .default) {
        self.repository = repository
        self.interval = interval
        let (stream, continuation) = AsyncStream<RefreshEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
    }

    /// Starts the loop. Refreshes once immediately, then every `interval`.
    /// A no-op if already running.
    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            await self?.runLoop()
        }
    }

    public func pause() { isPaused = true }
    public func resume() { isPaused = false }

    /// Changes the cadence; takes effect on the next tick.
    public func setInterval(_ interval: RefreshInterval) {
        self.interval = interval
    }

    /// Stops the loop and finishes the event stream.
    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        continuation.finish()
    }

    public var currentInterval: RefreshInterval { interval }
    public var paused: Bool { isPaused }

    /// Performs one refresh immediately and publishes it, regardless of pause
    /// state (used by the toolbar's manual Refresh button).
    public func refreshNow() async {
        await performRefresh()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            if !isPaused {
                await performRefresh()
            }
            do {
                try await Task.sleep(for: interval.duration)
            } catch {
                break // cancelled during sleep
            }
        }
    }

    private func performRefresh() async {
        do {
            let diff = try await repository.refresh()
            continuation.yield(.update(diff))
        } catch {
            continuation.yield(.failure(String(describing: error)))
        }
    }
}
