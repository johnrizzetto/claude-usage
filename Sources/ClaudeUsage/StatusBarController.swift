import AppKit
import SwiftUI

// MARK: - Controller

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: UsageViewModel
    private var eventMonitor: Any?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        viewModel = UsageViewModel()
        super.init()

        setupButton()
        setupPopover()

        viewModel.onUpdate = { [weak self] in
            self?.updateStatusBarTitle()
        }
    }

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        // Initial placeholder
        button.attributedTitle = makeTitle(dot: NSColor.secondaryLabelColor, label: "···")
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 320, height: 280)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(viewModel: viewModel)
        )
    }

    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }

        guard let pct = viewModel.sessionPercent else {
            if viewModel.isLoading {
                button.attributedTitle = makeTitle(dot: NSColor.secondaryLabelColor, label: "···")
            } else {
                button.attributedTitle = makeTitle(dot: NSColor.secondaryLabelColor, label: "—")
            }
            return
        }

        let pace = calculatePace(
            sessionPercent: pct,
            sessionReset: viewModel.sessionReset
        )

        button.attributedTitle = makeTitle(dot: pace.nsColor, label: "\(pct)%")
    }

    /// Builds an attributed string: colored ● dot + monospaced percentage label
    private func makeTitle(dot dotColor: NSColor, label: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let dotAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: dotColor,
            .font: NSFont.systemFont(ofSize: 9)
        ]
        result.append(NSAttributedString(string: "● ", attributes: dotAttrs))

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        ]
        result.append(NSAttributedString(string: label, attributes: labelAttrs))

        return result
    }

    @objc private func handleClick() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
