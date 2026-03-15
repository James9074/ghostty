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
/// Mirrors the style of the native macOS tab bar closely enough to feel
/// at home, but is implemented entirely in SwiftUI so it can live inside
/// an NSPanel (which does not support NSTabGroup).
struct QuickTerminalTabBar<ViewModel: QuickTerminalTabViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Scrollable tab list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(viewModel.quickTabs.enumerated()), id: \.element.id) { (index, tab) in
                        QuickTerminalTabItem(
                            label: tab.label(index: index),
                            isSelected: index == viewModel.activeQuickTabIndex,
                            onSelect: { viewModel.selectQuickTab(at: index) },
                            onClose: viewModel.quickTabs.count > 1
                                ? { viewModel.closeQuickTab(at: index) }
                                : nil
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Divider()
                .frame(height: 16)
                .padding(.horizontal, 4)

            // New tab button
            Button(action: { viewModel.newQuickTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab")
            .padding(.trailing, 6)
        }
        .frame(height: 28)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct QuickTerminalTabItem: View {
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)

            if let onClose, isHovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .frame(width: 14, height: 14)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(0.25))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close Tab")
            } else if onClose != nil {
                // Reserve space for the close button so labels don't shift
                Color.clear.frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.15)
                      : (isHovering ? Color.secondary.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
        .contentShape(Rectangle())
    }
}
