# Ghostty — Claude Development Notes

Practical knowledge accumulated from hands-on development, building, and
releasing the macOS app. Complements `AGENTS.md` and `macos/AGENTS.md`.

---

## Building the macOS App

### Prerequisites (one-time)

The Metal toolchain is not included with Xcode by default and must be
downloaded separately before any build will succeed:

```sh
xcodebuild -downloadComponent MetalToolchain
```

### Full build sequence (clean machine)

```sh
# 1. Build the Zig core library (only needed when non-Swift files change)
zig build -Demit-macos-app=false -Doptimize=ReleaseFast   # release
zig build -Demit-macos-app=false                           # debug (default)

# 2. Build the macOS app — run from the repo root
nu macos/build.nu --configuration Debug          # fast iteration
nu macos/build.nu --configuration ReleaseLocal   # personal release build

# Output: macos/build/<configuration>/Ghostty.app
```

`build.nu` must be invoked from the **repo root** (not from inside `macos/`),
or use an absolute path: `nu /path/to/ghostty/macos/build.nu`.

### Configurations

| Configuration  | Use case | Signing |
|---------------|----------|---------|
| `Debug`        | Day-to-day iteration | Ad-hoc |
| `ReleaseLocal` | Personal release; runs on your machine and other Macs (right-click → Open on first launch) | Ad-hoc |
| `Release`      | Distribution; requires a paid Apple Developer account | Developer ID |

### Iterating on Swift-only changes

Once `GhosttyKit.xcframework` exists (from a prior Zig build), you can skip
step 1 and just re-run `build.nu`. The Zig rebuild is only needed when files
outside `macos/` change.

---

## Testing / Local Test Harness

`test-quick-terminal.sh` at the repo root provides a build → launch →
trigger → log capture loop. Run it from the repo root:

```sh
bash test-quick-terminal.sh [timeout_seconds]   # default 10s
```

It:
1. Builds with `ReleaseLocal` configuration
2. Kills any running Ghostty instance
3. Streams `log` output to `/tmp/ghostty-quick-terminal-test.log`
4. Launches the app and waits 3 s for startup
5. Clicks **View → Quick Terminal** via `osascript` / System Events
6. Waits for the timeout, then reports crash reports and filtered logs

**System Events access** must be granted to Terminal (or whatever shell
host runs the script) in System Settings → Privacy & Security → Accessibility.

### Process name gotcha

The running process is named **`ghostty`** (lowercase), not `Ghostty`.
Use `pgrep -ix ghostty` (case-insensitive) to check whether it is alive.
`pgrep -x Ghostty` will silently return nothing even when the app is running.

### Crash reports

Written to `~/Library/Logs/DiagnosticReports/Ghostty*.ips` (JSON).
Parse with:

```sh
python3 -c "
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
print(d.get('terminationReason',''))
for t in d.get('threads',[]):
    if t.get('triggered'):
        for f in t.get('frames',[])[:20]: print(f.get('symbol','?'))
" ~/Library/Logs/DiagnosticReports/Ghostty*.ips
```

---

## Releasing a Personal Build

```sh
# Zip (preserves code signature and resource forks)
ditto -c -k --keepParent \
    /path/to/macos/build/ReleaseLocal/Ghostty.app \
    /path/to/Ghostty.zip

# Publish to GitHub (gh CLI)
gh release create "<tag>" \
    --repo <owner>/ghostty \
    --target <branch-or-sha> \
    --title "<title>" \
    --notes "<notes>" \
    "/path/to/Ghostty.zip#Ghostty.zip"
```

`ReleaseLocal` builds are ad-hoc signed — they run on any Mac but Gatekeeper
will prompt on first launch. Users must **right-click → Open** the first time.
They will NOT run on machines under MDM/managed security policies.

---

## macOS App Architecture Notes

### Quick Terminal

`macos/Sources/Features/QuickTerminal/`

- Backed by `QuickTerminalWindow` — a subclass of **`NSPanel`**, not
  `NSWindow`. This means native `NSTabGroup` / macOS tab groups are
  **not supported**. Any tab functionality must be implemented as a custom
  SwiftUI view inside the panel.
- The panel starts with an **empty `surfaceTree`** and only creates a
  terminal process on the first `animateIn()` call. This saves resources
  when the Quick Terminal has never been shown.
- `surfaceTreeDidChange` is called whenever the split tree changes. The
  empty-tree case (`to.isEmpty`) must be handled carefully — it can fire
  before any tabs are initialised (e.g. during `super.init`), so always
  guard against an empty tabs array before calling tab-removal logic.

### ObservableObject / @Published in subclasses

`BaseTerminalController` owns the `ObservableObject` conformance.
Adding `@Published` properties in a subclass is unreliable for triggering
SwiftUI re-renders. Use manual `objectWillChange.send()` in a `willSet`
observer instead:

```swift
private(set) var myProperty: SomeType = defaultValue {
    willSet { objectWillChange.send() }
}
```

### SurfaceView focus after tab switches

When a new `SurfaceView` is created and added to `surfaceTree`, SwiftUI
needs at least one layout pass to attach the view to the window before
`makeFirstResponder` has any effect. Use a retry loop:

```swift
func focusSurfaceWhenReady(_ surface: SurfaceView, in window: NSWindow, retries: Int) {
    guard visible, retries > 0 else { return }
    if surface.window == window {
        window.makeFirstResponder(surface)
        return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(25)) {
        self.focusSurfaceWhenReady(surface, in: window, retries: retries - 1)
    }
}
```

A single short `asyncAfter` delay is not reliable — the layout time varies.

### Menu structure (for osascript / testing)

| Feature | Menu path |
|---------|-----------|
| Quick Terminal | View → Quick Terminal |
| New Tab | File → New Tab |
| New Window | File → New Window |

### Key file locations

| Purpose | Path |
|---------|------|
| Quick Terminal controller | `macos/Sources/Features/QuickTerminal/QuickTerminalController.swift` |
| Quick Terminal tab bar | `macos/Sources/Features/QuickTerminal/QuickTerminalTabBar.swift` |
| Base terminal controller | `macos/Sources/Features/Terminal/BaseTerminalController.swift` |
| Normal terminal tabs | `macos/Sources/Features/Terminal/TerminalController.swift` |
| Split tree data structure | `macos/Sources/Features/Splits/SplitTree.swift` |
| App delegate | `macos/Sources/App/macOS/AppDelegate.swift` |
| Main menu (XIB) | `macos/Sources/App/macOS/MainMenu.xib` |
