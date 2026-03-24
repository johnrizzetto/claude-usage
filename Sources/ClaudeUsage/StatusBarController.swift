import AppKit
import SwiftUI

// MARK: - Controller

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let viewModel: UsageViewModel
    private var eventMonitor: Any?

    /// Cached icon images keyed by pixel size to avoid redrawing every update
    private var iconCache: [CGFloat: NSImage] = [:]

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
        button.attributedTitle = makeTitle(paceColor: .secondaryLabelColor, label: "···")
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
            button.attributedTitle = makeTitle(paceColor: .secondaryLabelColor,
                                               label: viewModel.isLoading ? "···" : "—")
            return
        }

        let pace = calculatePace(sessionPercent: pct, sessionReset: viewModel.sessionReset)
        button.attributedTitle = makeTitle(paceColor: pace.nsColor, label: "\(pct)%")
    }

    /// Builds the menu bar attributed string: tiny Claude icon + pace-colored percentage.
    private func makeTitle(paceColor: NSColor, label: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Claude asterisk icon as an inline text attachment
        let iconSize: CGFloat = 13
        let attachment = NSTextAttachment()
        attachment.image = claudeIcon(size: iconSize)
        // Vertically center the icon relative to the text baseline
        attachment.bounds = CGRect(x: 0, y: -2.5, width: iconSize, height: iconSize)
        result.append(NSAttributedString(attachment: attachment))

        // Thin gap between icon and number
        result.append(NSAttributedString(string: " ", attributes: [
            .font: NSFont.systemFont(ofSize: 8)
        ]))

        // Percentage, colored by pace
        result.append(NSAttributedString(string: label, attributes: [
            .foregroundColor: paceColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]))

        return result
    }

    // MARK: - Claude Icon

    /// Draws the Claude logo: 6 rounded petals arranged radially, in Claude orange.
    private func claudeIcon(size: CGFloat) -> NSImage {
        if let cached = iconCache[size] { return cached }

        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let cx = size / 2
            let cy = size / 2
            let numPetals = 6
            let petalW  = size * 0.21
            let petalH  = size * 0.42
            let offsetY = size * 0.10  // distance from center to petal base

            NSColor(red: 0.856, green: 0.467, blue: 0.337, alpha: 1.0).setFill()

            for i in 0..<numPetals {
                let angleDeg = CGFloat(i) * 360.0 / CGFloat(numPetals)

                // Draw petal centered at origin, then rotate + translate to center
                let petal = NSBezierPath(
                    roundedRect: NSRect(x: -petalW / 2, y: offsetY, width: petalW, height: petalH),
                    xRadius: petalW / 2,
                    yRadius: petalW / 2
                )

                let xform = NSAffineTransform()
                xform.translateX(by: cx, yBy: cy)
                xform.rotate(byDegrees: angleDeg)
                petal.transform(using: xform as AffineTransform)
                petal.fill()
            }
            return true
        }

        image.isTemplate = false
        iconCache[size] = image
        return image
    }

    // MARK: - Popover

    @objc private func handleClick() {
        if popover.isShown { closePopover() } else { openPopover() }
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
