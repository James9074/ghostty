import Cocoa

struct QuickTerminalRestorableState: TerminalRestorable {
    static var version: Int { 2 }

    let focusedSurface: String?
    /// All tabs, in order. Each tab holds its own split tree.
    let tabs: [QuickTab]
    /// The index of the tab that was active when the state was saved.
    let activeTabIndex: Int
    let screenStateEntries: QuickTerminalScreenStateCache.Entries

    init(from controller: QuickTerminalController) {
        controller.saveScreenState(exitFullscreen: true)
        self.focusedSurface = controller.focusedSurface?.id.uuidString
        // Snapshot the current surface tree into the active tab before saving.
        var tabs = controller.quickTabs
        let idx = controller.activeQuickTabIndex
        if idx < tabs.count {
            tabs[idx].surfaceTree = controller.surfaceTree
        }
        self.tabs = tabs
        self.activeTabIndex = idx
        self.screenStateEntries = controller.screenStateCache.stateByDisplay
    }

    init(copy other: QuickTerminalRestorableState) {
        self = other
    }

    /// Convenience: the surface tree of the active tab (used by legacy callers).
    var surfaceTree: SplitTree<Ghostty.SurfaceView> {
        guard activeTabIndex < tabs.count else { return .init() }
        return tabs[activeTabIndex].surfaceTree
    }

    var baseConfig: Ghostty.SurfaceConfiguration? {
        var config = Ghostty.SurfaceConfiguration()
        config.environmentVariables["GHOSTTY_QUICK_TERMINAL"] = "1"
        return config
    }
}
