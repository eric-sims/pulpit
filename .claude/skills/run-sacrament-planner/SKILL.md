---
name: run-sacrament-planner
description: Build, run, and drive SacramentPlanner on the iOS simulator. Use when asked to start the app, launch it in the simulator, take a screenshot of its UI, tap through a screen, verify a change in the real app, or run its tests.
---

A SwiftUI + SwiftData iPhone app. Drive it with
`.claude/skills/run-sacrament-planner/driver.sh`, which builds the app onto a booted simulator and
presses buttons through an XCUITest bundle that has **no host app** — it attaches to whatever build
of `com.ericsims.SacramentPlanner` is installed.

That indirection is the whole point: there is no `simctl tap`, and AppleScript UI scripting fails
with `osascript is not allowed assistive access`. A test bundle is the only way to touch the screen
here, so the harness lives outside the app's Xcode project and the repo's own project file stays
untouched.

All paths below are relative to the repo root.

## Prerequisites

Xcode with an iOS simulator runtime. Verified against Xcode 26.6 (17F113), iOS 26.5, iPhone 17.

```bash
xcodebuild -version
xcrun simctl list devices available
```

No `apt-get`/`brew` step — everything used (`xcodebuild`, `simctl`, `xcresulttool`, `python3`) ships
with Xcode and macOS.

## Build

```bash
.claude/skills/run-sacrament-planner/driver.sh build
```

Boots a simulator if none is running, then builds into `.build-artifacts/dd/`. Roughly 60s cold.

## Run (agent path)

```bash
.claude/skills/run-sacrament-planner/driver.sh smoke
```

Build → wipe app data → run `flows/outstanding.swift` → export named screenshots. ~2½ minutes.
Expect `** TEST SUCCEEDED **` and five PNGs.

| command | what it does |
|---|---|
| `driver.sh boot` | boot a simulator, open Simulator.app, print its UDID |
| `driver.sh build` | build the app for that simulator |
| `driver.sh install` | install the built app |
| `driver.sh reset` | uninstall + reinstall — the reliable way to wipe SwiftData |
| `driver.sh launch` | launch the app |
| `driver.sh shot <name>` | screenshot the simulator → `.build-artifacts/<name>.png` |
| `driver.sh flow <name>` | run `flows/<name>.swift` against the installed app |
| `driver.sh smoke` | build + reset + `flow outstanding` |

Artifacts land in `.build-artifacts/` (gitignored): `<flow>/*.png`, `<flow>/*.txt`,
`<flow>.xcresult`.

Override the device with `SIM_DEVICE='iPhone 17 Pro' driver.sh build`.

### Writing a flow

A flow is one `XCTestCase` in `flows/<name>.swift`. `driver.sh flow` copies it to
`uitest/SPUITests/Flow.swift` — the single file the bundle compiles — so only the selected flow
builds. Copy `flows/outstanding.swift`; it exercises the wizard, the roster picker, a Form toggle,
the outline and a sheet, which is most of the app's interaction vocabulary.

`uitest/SPUITests/Support.swift` holds the helpers, each one encoding a trap from the Gotchas below:

| helper | why it exists |
|---|---|
| `shot(name)` / `dumpHierarchy(name)` | attachments `driver.sh` exports under readable names |
| `tap(element, what)` | waits first, and names the element when it fails |
| `flip(toggle, what)` | taps a Form toggle where the switch actually is |
| `advanceWizard(to: title)` | walks the wizard by destination, not by tap count |
| `scroll(to: element)` | brings a lazy List row into existence |
| `appearsWhileScrolling(label)` | honest absence check across a whole scroll view |
| `openFirstMeeting()` | taps the meeting row rather than its section header |

**When a query doesn't match, dump the tree instead of guessing:**

```bash
.claude/skills/run-sacrament-planner/driver.sh flow hierarchy
# → .build-artifacts/hierarchy/00-launch-tree.txt
```

## Run (human path)

```bash
.claude/skills/run-sacrament-planner/driver.sh build
.claude/skills/run-sacrament-planner/driver.sh launch
```

Simulator.app comes to the front and you tap it yourself.

## Test

```bash
cd SacramentKit && swift test
```

100 tests in 15 suites, ~15s. This covers the pure model/scripting package only — the app target
(SwiftData models, views) has no unit tests, which is why the UI flows above matter.

## Gotchas

- **`app.cells.firstMatch` grabs the section header.** In a SwiftUI `List`, the "Upcoming" header
  is itself a cell and sorts first. Tapping it silently does nothing. Rows are `Button`s whose
  label is every line run together — `"Sunday, Aug 9, 2026, Regular, 10 to fill"` — so match on a
  substring. `openFirstMeeting()` does this.
- **Tapping a `Toggle` does nothing.** Its accessibility element spans the entire Form row, so
  `switch.tap()` hits the label. `value` stays `"0"` and nothing warns you. Tap at
  `dx: 0.92` instead — that's `flip()`.
- **A SwiftUI `List` is lazy, so `exists` is false for rows below the fold.** This quietly makes
  *negative* assertions pass for the wrong reason: `XCTAssertFalse(app.staticTexts["Not asked"].exists)`
  succeeds on an unscrolled screen whether or not the chip is there. Sweep with
  `appearsWhileScrolling()`.
- **Don't count wizard steps.** The step list is built at runtime — a fast and testimony meeting
  has no speakers step — and the confirmation button reads "Skip" or "Next" depending on whether
  the step is empty. Loop until the destination navigation bar exists; `advanceWizard(to:)` does.
- **SwiftData survives reinstall-free runs.** A flow that plans a meeting will find the last run's
  meetings on the next launch and match the wrong row. `driver.sh reset` (uninstall + install)
  before any flow that creates data; `smoke` already does.
- **Curly quotes in labels.** The roster picker's one-off button reads `Use “Mark Nielsen” just
  this once` with typographic quotes. Match with a `CONTAINS` predicate on a plain-ASCII tail.
- **Screenshots don't land on disk by themselves.** `XCTAttachment` goes into the `.xcresult` under
  a UUID filename; `driver.sh` runs `xcresulttool export attachments` and renames them from
  `manifest.json`. Attachments need `lifetime = .keepAlways` or they're dropped on success.
- **A named person is required to see status chips at all.** `Assignment.needsFollowUp` requires
  `isFilled`, so an empty slot shows nothing. Any flow checking status behaviour has to name
  someone first.

## Troubleshooting

- **`osascript is not allowed assistive access. (-1719)`**: AppleScript UI scripting needs an
  accessibility grant in System Settings. Don't chase it — use `driver.sh flow`, which needs no
  such permission.
- **`Unable to boot device in current state: Booted`**: harmless. `driver.sh boot` reuses an
  already-booted device rather than booting a second one.
- **`IDERunDestination: Supported platforms ... is empty`**: printed by `xcodebuild` on every run
  here. Not an error; the build succeeds.
- **Flow fails at the *first* interaction with a screen you believe is showing**: the app is
  probably still on the previous screen because a tap missed. Add `shot()` immediately before the
  failing line and look at it before changing the query.
