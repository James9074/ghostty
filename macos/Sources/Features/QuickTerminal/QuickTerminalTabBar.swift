import SwiftUI
import GhosttyKit

/// The view model that the QuickTerminalTabBar reads from. This is provided
/// by the QuickTerminalController so the tab bar always reflects the correct
/// state without coupling the view to the controller type.
protocol QuickTerminalTabViewModel: ObservableObject {
    var quickTabs: [QuickTab] { get }
    var activeQuickTabIndex: Int { get }
    func selectQuickTab(at index: Int)
    func closeQuickTab(at index: Int)
    func newQuickTab()
}

/// A single tab entry in the quick terminal.
struct QuickTab: Identifiable, Codable {
    let id: UUID
    var surfaceTree: SplitTree<Ghostty.SurfaceView>
    /// Optional user-provided title override. When nil, a default "Tab N" label is shown.
    var titleOverride: String?

    init(surfaceTree: SplitTree<Ghostty.SurfaceView>, titleOverride: String? = nil) {
        self.id = UUID()
        self.surfaceTree = surfaceTree
        self.titleOverride = titleOverride
    }

    func label(index: Int) -> String {
        titleOverride ?? "Tab \(index + 1)"
    }
}

/// A compact tab bar designed for use inside the Quick Terminal window.
///
/// Tabs divide the full available width equally, matching the aesthetic of
/// native macOS tab bars. Implemented in SwiftUI so it can live inside an
/// NSPanel (which does not support NSTabGroup).
struct QuickTerminalTabBar<ViewModel: QuickTerminalTabViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Tabs share all available space equally.
            ForEach(Array(viewModel.quickTabs.enumerated()), id: \.element.id) { (index, tab) in
                if index > 0 {
                    tabSeparator
                }

                QuickTerminalTabItem(
                    label: tab.label(index: index),
                    isSelected: index == viewModel.activeQuickTabIndex,
                    onSelect: { viewModel.selectQuickTab(at: index) },
                    onClose: viewModel.quickTabs.count > 1
                        ? { viewModel.closeQuickTab(at: index) }
                        : nil
                )
                .frame(maxWidth: .infinity)
            }

            tabSeparator

            // New-tab button — fixed width so tabs get all remaining space.
            Button(action: { viewModel.newQuickTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: tabHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab")
        }
        .frame(height: tabHeight)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var tabSeparator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1)
            .padding(.vertical, 5)
    }

    private let tabHeight: CGFloat = 30
}

private struct QuickTerminalTabItem: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    /// Nil when this is the only tab (close is disabled).
    let onClose: (() -> Void)?

    @State private var isHovering = false

    // Width reserved for the close button on each side so the label stays centered.
    private let closeButtonSize: CGFloat = 16
    private let closeButtonPadding: CGFloat = 7

    var body: some View {
        ZStack(alignment: .top) {
            // Accent bar at the very top of the selected tab.
            if isSelected {
                Color.accentColor
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 0) {
                // Close button — always occupies its space so the label stays centred.
                Button(action: { onClose?() }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: closeButtonSize, height: closeButtonSize)
                        Image(systemName: "xmark")
                            .font(.system(size: 7.5, weight: .bold))
                    }
                }
                .buttonStyle(.plain)
                .opacity(showCloseButton ? 1 : 0)
                .disabled(onClose == nil)
                .help("Close Tab")
                .padding(.leading, closeButtonPadding)

                // Label, centred in the remaining space.
                Text(label)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)

                // Mirror close-button space on the right for perfect centering.
                Spacer()
                    .frame(width: closeButtonSize + closeButtonPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(selectionBackground)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var showCloseButton: Bool {
        onClose != nil && (isHovering || isSelected)
    }

    private var selectionBackground: Color {
        if isSelected { return Color.primary.opacity(0.07) }
        if isHovering  { return Color.primary.opacity(0.04) }
        return .clear
    }
}
