# TCPV4MACCore

The headless core of **TCPV4MAC**: models, data provider, parser, and diff
engine. It builds and tests entirely from the terminal (`swift test`), with no
Xcode required. The SwiftUI app is built on top of this package.

## Why it is a separate package

The design requires never coupling the UI to `lsof`, and unit tests for the
parser and diff engine. Isolating the logic in a Swift package guarantees this
structurally: the core cannot import SwiftUI/AppKit, and the tests run headless
in CI.

## Architecture decisions

- **`lsof -F` (field mode), not columns.** Column output truncates the process
  name to ~9 chars (`identityservicesd` → `identitys`) and is fragile with
  spaces. Field mode emits one `<key><value>` token per line and full names. See
  [`LsofParser`](Sources/TCPV4MACCore/Parsers/LsofParser.swift).
- **Stable identity in `Connection`.** A random `UUID` per fetch would make every
  connection look "new" each second and break the diff. Identity is derived from
  `pid.fd.proto.local->remote`.
- **`Connection` is AppKit-free.** The process-icon `NSImage` lives in the app
  layer, not the model — keeping views separate from data collection.
- **The app cannot be sandboxed.** The App Sandbox blocks spawning `lsof` and
  inspecting other processes. It is distributed outside the Mac App Store.

## Layout

```
Sources/TCPV4MACCore/
  Models/        Connection, ProtocolType, TCPState
  Providers/     ConnectionProvider + LsofProvider
                 ProcessMetadataProvider + LibprocMetadataProvider
  Parsers/       LsofParser (lsof -F → [Connection])
  DiffEngine/    ConnectionDiffEngine, ConnectionEvent, ConnectionDiff
  Repository/    ConnectionRepository, RefreshEngine, RefreshInterval
Sources/tcpv4mac-cli/   Headless smoke tool (swift run tcpv4mac-cli)
Tests/                 XCTest: parser, diff, repository, refresh engine (29)
```

## Usage

```bash
swift test            # 29 tests: parser + diff + repository + refresh engine
swift run tcpv4mac-cli # dump the real live connections
```

```swift
// One-shot refresh (fetch → enrich → diff):
let repo = ConnectionRepository(provider: LsofProvider())
let diff = try await repo.refresh()
// diff.added / diff.removed / diff.modified  → UI color rules

// Continuous auto-refresh for the UI:
let engine = RefreshEngine(repository: repo, interval: .oneSecond)
await engine.start()
for await event in engine.events {
    if case let .update(diff) = event { /* update the table */ }
}
```

## Future backends (`ConnectionProvider`)

`nettop`, `libproc`, `sysctl`, `Network.framework`, Endpoint Security. The UI
does not change: another provider is simply injected.
