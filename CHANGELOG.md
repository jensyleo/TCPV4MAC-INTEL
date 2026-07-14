# Changelog

All notable changes to **TCPV4MAC**. Format based on
[Keep a Changelog](https://keepachangelog.com/); this project follows
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added — 2026-07-13 · README screenshots
- Added a screenshots section to the README (overview + inspector), with
  usernames and local IP addresses blurred for privacy.

## [1.0.0] — 2026-07-02

First release. A complete, lightweight macOS TCP/UDP connection inspector
(Sysinternals-TCPView-inspired): live table, filters, search, inspector, color
rules, context menu, CSV/JSON copy & export, admin mode, settings, uninstaller.

### Changed — 2026-07-06 · Bundle id carries no employer/domain association
- Bundle id changed to **`com.jensyleo.tcpv4mac`** (matching the identifier style
  used for an internal project), so the app carries no employer or organization association.
  Every trace of the prior identifier was purged from this Mac — preferences,
  saved state, caches, and TCC grants — and removed from the codebase, docs, and
  build settings. Verified: the installed `Info.plist`, the compiled binary, and
  every file under `~/Library/{Preferences,Saved Application State,Caches,HTTPStorages}`
  are clean.

### Changed — 2026-07-06 · Kill Process reports failures
- Kill Process now checks the result of each `kill(2)`. If any signal fails it
  shows an alert; when it's a permission error (`EPERM`) and the app is running as
  the normal user, the message says the target belongs to root/another user and
  points to ⋯ → "Run as Administrator…". Previously failures were silent, so
  killing another user's process looked like a no-op. (When running as admin/root
  the signal is sent with root privileges, as before.)

### Fixed — 2026-07-06 · ⌘N no longer opens a second window
- Switched the main scene from `WindowGroup` to `Window` (a single unique
  window), so **⌘N / "New Window" can no longer spawn a second window** — the app
  is single-window by design.

### Changed — 2026-07-06 · Quit the app when its window closes
- Closing the window now **quits the app completely**
  (`applicationShouldTerminateAfterLastWindowClosed` → `true`). It's a
  single-window utility, so lingering in the background with no window served no
  purpose.

### Changed — 2026-07-06 · About panel credits the TCPView inspiration
- The About panel now states the app is inspired by **Sysinternals TCPView for
  Windows**, alongside the existing GPLv3 line.

### Added — 2026-07-06 · IPv4 / IPv6 / Loopback dashboard cards
- Three new dashboard quick-filter cards, coherent with the filter menu:
  - **IPv4** and **IPv6** — a two-way switch (like TCP/UDP): a click isolates or
    switches to that IP version; clicking the active one clears back to all.
  - **Loopback** — a real scope filter (not an include/exclude modifier): the
    card focuses on loopback-only (localhost, `127.0.0.1` / `::1`), and clicking
    it again clears back to all. The filter model now has a **Scope** dimension
    (`loopback` / `external`); the menu exposes both toggles, and the dashboard
    card is the loopback switch (its "External" counterpart lives in the menu).
- Added `ipv4Count` / `ipv6Count` / `loopbackCount` to the view model.
- **IPv4 / IPv6 come first** in both the dashboard cards and the filter menu.

### Changed — 2026-07-06 · CLI admin command detaches, replaces the user instance, quits the terminal
- The command-line alternative in the admin sheet now: (1) uses `perl` to fork
  into a **new session** (`POSIX::setsid`) before exec-ing the app, so it fully
  detaches and survives the terminal closing (macOS ships `perl` but not
  `setsid`); (2) `pkill`s the current-user instance by real uid (leaving the new
  root instance — uid 0 — untouched); (3) walks up the process tree to the
  terminal app (first `.app/Contents/MacOS/` ancestor) and `kill -9`s it. SIGKILL
  can't be intercepted, so the "terminate running processes?" dialog no longer
  appears, and because it targets the app process it works for **any** terminal
  (Terminal, iTerm, Warp, Ghostty, kitty, WezTerm, Alacritty, Hyper), not just
  Terminal.app. The relaunched root app already ran `setsid`, so it survives its
  terminal being killed. A wrong password fails `sudo` and the whole `&& { … }`
  group is skipped, leaving the window open to retry.

### Changed — 2026-07-06 · Cleanup / optimization pass
- Removed dead code (`anyFilter` in the dashboard).
- Sorting: a sort-descriptor change no longer sorts and reloads the table
  **twice** — `apply` already re-sorts from the live rows and reloads once.
- `visibleConnections` no longer copies the snapshot array when there are no
  removed-row ghosts (the common case).
- Dashboard counts are now computed in **one pass** (`summary`) instead of eight
  separate O(n) scans of the snapshot per render.
- De-duplicated the "Clear filters & search" action (reuses `clearFiltersAndSearch()`).
- Reviewed the whole codebase (core package + app): the `TCPV4MACCore` package
  needed no changes; `lsof -F` state parsing, the `RefreshEngine` actor's
  `[weak self]` loop capture, and the pasteboard `clearContents()` calls were all
  verified correct and left as-is.

### Changed — 2026-07-06 · Single "Restore Default View" (no more scattered resets)
- The view reset now lives in **one** place: **Columns → Restore Default View**
  (restores column order, width, visibility and sort). Removed the duplicate from
  the ⋯ menu, which is now **More** (Run as Administrator, Uninstall). "Show All
  Columns" stays as the lighter unhide-only action.

### Fixed — 2026-07-06 · Column autofit no longer clips wide content
- Double-clicking a column divider to autofit was capped at **600 px**, so long
  values (full **Executable** paths, Bundle IDs) stopped widening before showing
  the whole cell. The cap is now generous (2000 px), so autofit expands to the
  actual content.

### Fixed — 2026-07-06 · Dashboard quick-filters now match the filter menu
- The dashboard summary cards (TCP/UDP, Listening/Established) used
  isolate-only logic, so **Listening and Established could not be active at the
  same time** — a state achievable only through the filter menu. The cards now
  behave like the menu's independent toggles: the first click isolates a value,
  and subsequent clicks add/remove others (multi-select), so combinations such as
  Listening + Established are reachable from the cards too. Clearing the last
  selection reverts to "show all". Card highlighting reflects every kept value.
- **TCP/UDP cards** are treated as a two-way **switch** (only two protocols
  exist, so keeping both = no protocol filter): a click isolates or switches to
  that protocol, and clicking the active one clears back to all. This fixes a
  regression where, from "TCP only", clicking UDP showed *everything* instead of
  switching to "UDP only".

### Changed — 2026-07-02 · Unsigned detection = ad-hoc too
- The **orange "unsigned"** color now triggers for binaries with **no recognized
  signing identity** — truly unsigned *or* ad-hoc (no Developer ID / Apple
  authority) — not only the never-runnable "no signature at all" case. Apple- and
  Developer-ID-signed processes stay uncolored. Signature shows "Ad-hoc (unsigned)".
  (Verified with a throwaway ad-hoc listener, since removed.)

### Changed — 2026-07-02 · In-app password sheet for root (replaces Terminal / osascript)
- **"Run as Administrator…"** now opens an **in-app password sheet**. The typed
  password is validated with `sudo -S -k` (piped via **stdin** — never in argv or
  logs) and, if correct, the app **relaunches as root** (detached, in the GUI
  session, so it shows its window). Continuous — **no periodic re-prompt**, no
  Terminal, no signing.
- Wrong password → shown inline in the sheet; on success the normal-user window
  quits once the root instance is confirmed (`pgrep`). The root instance shows a
  "Admin (all users)" badge.
- Removed the earlier osascript-based "Admin Mode" (rejected the password / forced
  a re-prompt every ~5 min) and the Terminal relaunch, in favor of this.
- The "Run as Administrator…" item is hidden when already running as root
  (`getuid() == 0`) — avoids re-elevating an elevated instance.
- The password sheet also shows the equivalent **CLI command**
  (`sudo "<app>/Contents/MacOS/TCPV4MAC"`) with a copy button.
- **Always asks for the password** (simpler + consistent): even on Macs with
  Touch-ID-for-sudo, the sheet always shows the password field and pipes it to
  `sudo`. If Touch ID appears it still works, and the typed password is a reliable
  fallback — so behavior is the same everywhere. (Dropped the earlier
  detect-and-branch Touch ID handling.)

### Added — 2026-07-02 · Columns menu + Copy Cell / CSV / JSON
- **Show/hide columns**: a dedicated **Columns** toolbar menu (per-column toggles
  + "Show All Columns") **and** the native right-click header menu — both
  model-driven and persisted. (The Columns menu is top-level like the filter menu;
  nesting it inside the ⋯ menu made SwiftUI close it on hover.)
- **Help ▸ TCPV4MAC Help**: a concise technical explanation (what it lists, the
  color legend, admin mode, why CLOSED sockets linger, right-click actions).
- Context menu: **Copy <Column> Cell** (the clicked cell), and **Copy as ▸ CSV /
  JSON** for the selected rows.

### Added — 2026-07-02 · Clear, About panel, loading spinner
- **Clear** toolbar button (shown only when a search/filter is active) plus **Esc**
  to clear the current search and filters.
- **About TCPV4MAC** panel customized with a GPLv3 notice + license link (name,
  version and copyright come from the bundle).
- First launch shows **nothing** (blank) until the first snapshot lands — the
  sub-second load doesn't warrant a spinner, and this avoids a misleading flash of
  "No connections". (Dropped the spinner.)

### Changed — 2026-07-02 · Bigger icons + legacy cleanup
- **Process icons enlarged** to 20 px (32 px overlapped); row height 26.
- Uninstaller and `uninstall.sh` now also purge the **pre-rename bundle id**
  (used when the app was still called "TCPView4MAC") — prefs, saved state,
  caches, TCC — so no old-name remnants are left behind.

### Added — 2026-07-02 · UX polish (empty states, quick-filter cards, alignment)
- **Empty-state messages** over the table: "Couldn't read connections" + Retry
  (on error), "No matching connections" + Clear (when filtered/searched), or
  "No connections".
- **Dashboard cards are quick filters**: click TCP / UDP / Listening / Established
  to isolate that category (click again to clear); **Total** clears filters +
  search. The active quick-filter card is highlighted.
- **All cells centered except the "Application" column** (kept left-aligned) —
  and column headers are centered too.
- **Cell tooltips**: hovering a truncated cell shows the full value; dashboard
  "Processes" / "Refresh" cards have explanatory tooltips.

### Added — 2026-07-02 · Keyboard shortcuts, double-click, copy row
- **"Connections" menu / shortcuts**: Refresh Now (⌘R), Pause/Resume Auto-Refresh
  (⌘⇧P), Show/Hide Inspector (⌘⌥I).
- **Double-click a row** opens the inspector (it follows the selection).
- **Copy Row** in the context menu, and **⌘C** copies the selected rows as
  tab-separated values (all data columns) — paste straight into a spreadsheet.

### Added / Changed — 2026-07-02 · Polish
- **"Run as Administrator" now quits Terminal fully** if TCPV4MAC launched it
  (Terminal wasn't already running) — the window closing left Terminal.app active.
  If Terminal was already open, it's left untouched.
- **Root instance now comes to the foreground**: launched directly (not via
  LaunchServices) it didn't grab focus; the elevated instance now activates
  itself once the normal instance quits.
- **Intermittent "two Terminal windows"**: replaced the timing-based reuse with a
  deterministic pass that closes any window that isn't ours (only when we launched
  Terminal), so the stray startup window can't survive a race.
- **Single instance (per user)**: on launch, if another TCPV4MAC owned by the
  same user is already running, the new one activates it and exits. Enforced
  per-uid so the "Run as Administrator" root relaunch is still allowed.
- **Preferred terminal**: Settings has an "Open Terminal in" picker (Ask each
  time / installed terminals). Once chosen — from Settings *or* by picking from
  the context-menu submenu the first time — the menu shows a single "Open in
  <terminal>" item instead of the submenu.
- **"Run as Administrator…"** (⋯ menu): relaunches TCPV4MAC as root via Terminal
  + `sudo`, so it can show connections from **all** users / system processes
  (not just the current user's). Terminal prompts for the password and now
  **closes itself automatically** once authenticated (the root instance is
  launched detached with `nohup`), and once the elevated instance is confirmed
  running (via `pgrep`) the **normal-user window quits automatically** (a
  cancelled prompt leaves it open). A native GUI password prompt is a future item
  (see ROADMAP — the clean `SMAppService` helper needs Developer ID signing,
  and the app is intentionally not signed).
- Install location is **/Applications** (standard) instead of ~/Applications.

### Added — 2026-07-02 · Settings window (Section B8)
- Native **Settings** window (⌘,): **Appearance** (System / Light / Dark),
  **Refresh interval** (now persisted across launches), **Auto-refresh on launch**,
  and **Show process icons**. The view model is shared between the main and
  Settings windows.
- Deferred (as per spec): **Resolve DNS** (needs Phase 2 reverse-DNS) and
  **Launch at Login** (future). "Remember filters / layout" is already automatic.
- **App icon** added (network-inspector artwork): full macOS icon set generated
  from a 1024×1024 PNG via `Scripts/make-appicon.sh` and wired through an asset
  catalog. **This completes the Phase 1 MVP.**

### Added — 2026-07-02 · Uninstall
- **In-app "Uninstall TCPV4MAC…"** (⋯ menu): removes all traces — preferences,
  saved state, caches, and **Privacy & Security (TCC) grants** (`tccutil reset
  All`) — then moves the app to the Trash and quits.
- **`Scripts/uninstall.sh`** for the same cleanup when the app is already gone.
- (The app creates no login items / launch agents, so there are none to remove.)

### Added — 2026-07-02 · Context menu + CSV export (Section B7)
- **Right-click context menu** on connections (acts on the selection, or the
  clicked row): Copy Local Address, Copy Remote Address, Copy PID, Copy Bundle ID,
  Copy Executable Path; **Reveal in Finder**; **Open Terminal Here**; and **Kill
  Process** (SIGTERM, with a confirmation alert; handles multi-select).
- **Export CSV**: toolbar button → `NSSavePanel` → writes **all** connections
  (18 columns incl. CPU/memory/threads/arch/signature) with proper CSV escaping.

### Added — 2026-07-02 · Persist UI state across launches
- **Column layout** (order / width / hidden) restored via `NSTableView`'s native
  `autosaveName` + `autosaveTableColumns`.
- **Sort order** (column + direction) persisted to `UserDefaults` and reapplied.
- **Inspector visibility** persisted via `@AppStorage`.
- **Filters** persisted: `ConnectionFilter` is `Codable`, saved to `UserDefaults`
  on change and restored on launch.
- **"Restore Default View"** action (toolbar ⋯ menu): all columns visible, default
  order + widths, sort back to Application ascending, inspector shown.

### Changed — 2026-07-02 · Native NSTableView (table rewrite)
- Replaced the SwiftUI `Table` with a native **`NSTableView`** (`ConnectionsTable`,
  `NSViewRepresentable`). The SwiftUI table desynced column content and could
  close the window when reordering with >10 columns + customization.
- Gains: **full-row background colors** (proper added/modified/removed/unsigned/
  listening/loopback/root tints, not just text), **double-click a column divider
  to auto-fit** (Excel-style), stable **reorder / hide-show** (header right-click
  menu), native multi-select and per-column sorting, and **unlimited columns**.
- **New resource columns**: **CPU %**, **Memory**, **Threads**, plus **Arch** and
  **Signature** — alongside Icon, Application, PID, User, Proto, State, Local/
  Remote Address & Port, Bundle ID, Executable, Duration.
- Per-process metrics (memory/threads/CPU-time via `proc_pidinfo`) are sampled for
  **all** visible pids each tick; CPU % from CPU-time deltas.
- Color rules refactored into a single `RowStatus` (SwiftUI legend color +
  `NSColor` text tint). Rows are colored by **text tint** (per user preference),
  not a full-row background.

### Added — 2026-07-02 · Inspector + AppKit enrichment (Section B6)
- **Trailing inspector** (native `.inspector`, toggle in toolbar): icon, bundle
  id, PID/PPID, user, architecture, code signature, executable path, CPU %,
  memory, thread count, connection count, and the selected socket's details.
- **AppKit/Security/libproc enrichment** in the app layer (`ProcessEnricher`,
  kept out of the core): icon (`NSWorkspace`, cached), bundle id
  (`NSRunningApplication`, cached), architecture, code signature (`SecStaticCode`,
  warmed off-main and cached by path), and metrics (`proc_pidinfo`: resident
  memory, threads, CPU time). CPU % is sampled from CPU-time deltas.
- **Table columns restored** now that the target is macOS 26 (10-column limit
  lifted via column `Group`s): **Icon**, **Bundle ID**, **Duration**.
- **Color rules completed**: **Unsigned** (orange) using the signature cache, and
  **Removed** (red) via short-lived ghost rows kept ~1.5 s after a connection
  disappears. Legend updated.

### Added — 2026-07-02 · Filters (Section B5)
- **Filter menu** in the toolbar (badged when active) with toggles for Protocol
  (TCP/UDP), IP version (IPv4/IPv6), State (Listening/Established/Other) and
  Include-loopback, plus **Reset filters**. Applied on top of the text search;
  the status bar's "Showing X of Y" reflects the result.
- Internet vs Local-Network scope filtering is deferred to a later pass.

### Changed — 2026-07-02
- **"Open Terminal Here" now lets you pick the terminal**: lists installed
  emulators (Terminal, iTerm, Warp, Ghostty, kitty, WezTerm, Alacritty, Hyper) as
  a submenu and opens the chosen one at the executable's folder.

### Fixed — 2026-07-02
- **"Run as Administrator" opened two Terminal windows**: when Terminal wasn't
  already running, launching it created a startup window *and* a `do script`
  window. Now the script detects whether Terminal was running and, if not, reuses
  the startup window (`do script … in window 1`) — a single window either way.
- **Uninstall left the preferences `.plist` behind**: deleting it in-process
  didn't stick because `cfprefsd` re-flushes the domain on quit. Now a detached
  `defaults delete` runs after the app exits, so the plist is removed for good.
- **Column layout wasn't being persisted**: `autosaveName`/`autosaveTableColumns`
  were set *before* the columns were added, so nothing was saved. Enabling
  autosave *after* adding the columns fixes order/width/hidden persistence
  (verified the `NSTableView Columns` key now appears in the app's defaults).
- **UI could hang briefly** (window blanked then recovered): the Signature column
  computed `SecStaticCode` **synchronously on the main thread** for uncached rows
  on every refresh. Signature reads are now **cache-only**; the value is computed
  off-main (`warmSignatures`) and appears on the next tick. Verified with `sample`
  that the main thread no longer blocks in signing code.
- **State filter did nothing** (e.g. "Listening only" showed no rows): a `switch`
  over the optional `state` didn't match the bare enum cases, so every row fell
  into "Other". Now compared with `==`. State toggles work independently of the
  protocol toggles.
- **PID and Local Port showed locale thousands separators** (e.g. "41.944",
  "7.000"); now rendered verbatim ("41944", "7000").
- **Loopback rows now win over listening** in the color rules, so `127.0.0.1` /
  `::1` sockets show purple instead of blue.
- **Added/Modified highlight now persists ~2.5 s** (across several fast refreshes)
  instead of a single tick, so the green/amber flashes are actually visible.

### Known limitations (added)
- **Only the current user's connections are shown.** `lsof` without root reports
  only the invoking user's processes, so root/other-user connections (and thus
  the gray "root" tint) don't appear. Seeing all system connections needs
  elevated privileges — a privileged helper (`SMAppService`) is a future item.

### Added — 2026-07-02 · Color rules (Section B4)
- Row color rules: **Added** (green) and **Modified** (readable amber) flash for
  the refresh in which the diff engine reports them; persistent **Listening**
  (blue), **Loopback** (purple) and **Root** (dark gray) tints otherwise.
  Transient states take precedence over attributes.
- Colors are applied as row **text tint** (SwiftUI `Table` has no per-row
  background); "modified" uses amber instead of pure yellow for legibility.
- Added a **color legend** popover (toolbar palette button).
- Deferred to B6 (need enrichment / ghost rows): **Removed** (red) and
  **Unsigned** (orange) — palette entries reserved in `RowPalette`.

### Added — 2026-07-02 · Toolbar + Dashboard (Section B3)
- **Toolbar**: search field (`.searchable`), **Pause/Resume**, manual **Refresh**,
  and a **Refresh-rate** picker (500 ms – 10 s) wired to the engine.
- **Live search** across process, PID, user, protocol, state, local/remote IP &
  port, executable and bundle id (`Connection.matches`). Dashboard counts stay on
  the full snapshot; the table shows the filtered set.
- **Dashboard cards** on top: Total, TCP, UDP, Listening, Established, Processes,
  Refresh rate.
- Status bar now shows "Showing X of Y", selection count, a Paused indicator,
  and a **refresh counter** (`N refreshes`) so the chosen interval is visibly
  observable even when the connection set doesn't change.
- `RefreshEngine.refreshNow()` added (immediate refresh, bypasses pause) — 29
  core tests still green.
- Filter / Settings / Export buttons are deferred to their sections (B5 / B8 / B7)
  rather than adding non-functional toolbar buttons now.

### Changed — 2026-07-02 · Target latest macOS
- Raised the app's minimum deployment target to **macOS 26 (Tahoe)** — the app
  now targets the latest macOS. (The `TCPV4MACCore` package stays portable.) This
  also lifts SwiftUI's 10-column table limit, so the remaining spec columns can
  be added when B6 lands.

### Known limitations
- **Double-click on a column divider does not auto-fit the column to its content**
  (Excel-style). SwiftUI's `Table` doesn't support this; it's an AppKit
  `NSTableView` behavior. Tracked for a later pass (NSTableView bridge or a
  "size to fit" action).

### Added — 2026-07-02 · Full table (Section B2)
- Expanded the main table to the 10 populated spec columns — Application, PID,
  User, Proto, State, Local Address, Local Port, Remote Address, Remote Port,
  Executable — all **sortable** (header click), **resizable**, and
  **show/hide + reorder** (right-click header, via `TableColumnCustomization`).
- Added `Connection+Display` (app layer) with display strings and non-optional
  sort keys, keeping the core model UI-free.
- Added live **first-seen / duration** tracking in the view model (`durationText`)
  — will surface in the inspector (B6).
- Row selection is **multi-select** (`Set<Connection.ID>`) — single click plus
  ⌘/⇧ range/extend selection.
- Note: SwiftUI's `TableColumnBuilder` caps at **10 columns on macOS 14**, so
  Icon + Bundle ID (both need B6 AppKit enrichment) and a Duration column are
  deferred to the inspector rather than shown as extra top-level columns.

### Changed — 2026-07-02 · Renamed project to TCPV4MAC
- Renamed the whole project **TCPView4MAC → TCPV4MAC** (folder, app, product,
  scheme, `.xcodeproj`), the core module **TCPViewCore → TCPV4MACCore**, the CLI
  **tcpview-cli → tcpv4mac-cli**, and adopted its own bundle id.
  References to Microsoft's *Sysinternals TCPView* (the inspiration credit) are
  intentionally left unchanged. Build + 29 tests still green; app runs.

### Added — 2026-07-02 · SwiftUI app scaffold (Section B1)
- **`TCPV4MAC.app`** — first SwiftUI app target, non-sandboxed, macOS 14+,
  its own bundle id, ad-hoc signed for local runs.
- Project generated with **XcodeGen** from `project.yml` (source of truth); the
  generated `TCPV4MAC.xcodeproj` is also committed so it opens without tooling.
  Regenerate with `xcodegen generate`.
- **`ConnectionsViewModel`** (`@MainActor @Observable`, MVVM) subscribes to the
  core `RefreshEngine` and republishes the live snapshot; exposes dashboard counts.
- **`ContentView`** — live `Table` (process, PID, proto, state, local/remote,
  executable), a status bar with summary counts + last-updated time, and an
  error banner. Auto-refreshes via the engine.
- Verified: `xcodebuild` **BUILD SUCCEEDED**, app launches and runs
  (non-sandboxed, no sandbox entitlement).

### Changed — 2026-07-02 · License
- Relicensed from MIT to the **GNU General Public License v3.0** (copyleft), at
  the author's request. `LICENSE` now holds the full, verbatim GPLv3 text.
  (GPL is fine here because the app ships outside the Mac App Store; MAS terms
  are known to conflict with the GPL.)
- Added the standard **GPLv3 header** to all 19 Swift source files (build + 29
  tests still green).
- Repo is now **publish-ready** under GPLv3: license, per-file headers, README
  license notice, `.gitignore`. Remaining to actually publish: author email,
  GitHub repo name, and public/private (see `Publicar GitHub/PUBLISHING.md`).

### Added — 2026-07-02 · Repository & refresh engine (core Section A)
- **`ConnectionRepository`** (actor, Repository Pattern): composes provider +
  metadata enrichment + diff engine. `refresh()` does fetch → enrich → diff and
  is fully deterministic/unit-testable with mocks.
- **`RefreshEngine`** (actor): drives `refresh()` on a timer and publishes each
  result through an `AsyncStream<RefreshEvent>`. Supports pause / resume / live
  interval change / stop. Owns timing only — no data logic, no UI coupling.
- **`RefreshInterval`** enum (500 ms / 1 / 2 / 5 / 10 s, default 1 s).
- **Process enrichment**: `ProcessMetadataProvider` protocol +
  `LibprocMetadataProvider` (executable path via `proc_pidpath`, parent pid via
  `proc_pidinfo`). Added `parentPID` + `Connection.applying(_:)`; enrichment
  resolves each pid once per snapshot (cached).
- **10 new unit tests** (repository + refresh engine, with mock providers) →
  **29 total, all green**.
- Updated `tcpv4mac-cli` to drive the full repository pipeline; validated against
  the live system (148 connections, 148/148 enriched with executable paths, PPID
  resolved, second-refresh diff working).

### Added — 2026-07-01 · Data engine (`TCPV4MACCore`)
- Created `TCPV4MACCore`, a headless Swift package (Swift 6, macOS 14+) holding
  all UI-independent logic so parsing and diffing can be unit-tested on their own.
- **Models** (`Connection`, `ProtocolType`, `TCPState`) — AppKit-free. `Connection`
  carries a **stable identity** (`pid.fd.proto.local->remote`) instead of a random
  UUID, so the diff engine can track a connection across refresh snapshots.
- **`ConnectionProvider`** protocol abstracting the data source, plus
  **`LsofProvider`** (runs `/usr/sbin/lsof -i -nP -F…` off the cooperative thread
  pool and tolerates `lsof`'s routine non-zero exit).
- **`LsofParser`** — parses `lsof -F` field output (not the column layout, which
  truncates process names to ~9 chars). Handles IPv4, bracketed IPv6 (`[::1]:port`),
  IPv6 zones, `*:*`, and `local->remote` forms.
- **`ConnectionDiffEngine`** — compares consecutive snapshots and emits
  added / removed / modified events for the UI's color rules.
- **`tcpv4mac-cli`** — a headless smoke tool (`swift run tcpv4mac-cli`) that
  exercises the full provider → parser → diff pipeline against live `lsof`.
- **19 XCTest unit tests** (parser fixtures + diff engine) — all green.

### Project / docs — 2026-07-01
- Added repo docs: bilingual `README` / `CHANGELOG` (EN + ES), `LICENSE`,
  `.gitignore`, and `TCPV4MACCore/README.md`.
- Added a `Publicar GitHub/` folder (review copies + legal/publish notes),
  mirroring the workflow used for the HardwareGrowler project.
- Added `ROADMAP.md` — living to-do / roadmap (done vs pending by phase,
  plus the recommended next step).

### Decisions
- **App name: `TCPV4MAC`** — chosen to stay clear of Microsoft Sysinternals'
  "TCPView" trademark while signaling the inspiration.
- **License: GNU GPL v3.0** © 2026 Jensy Leonardo Martínez Cruz (original work).
- The app will **not** be sandboxed (App Sandbox blocks `lsof` and cross-process
  inspection) → distributed outside the Mac App Store.

[1.0.0]: https://example.com/CHANGE-ME/releases/tag/v1.0.0
