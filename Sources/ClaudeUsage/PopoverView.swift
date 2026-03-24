import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 10)

            Divider()
                .padding(.bottom, 12)

            if viewModel.isLoading && !viewModel.isLoggedIn && viewModel.sessionPercent == nil {
                loadingView
            } else if !viewModel.isLoggedIn && viewModel.sessionPercent == nil {
                loginPromptView
            } else {
                usageContent
            }

            Divider()
                .padding(.top, 12)
                .padding(.bottom, 8)

            footerRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.91, green: 0.53, blue: 0.28))
                    .frame(width: 18, height: 18)
                Text("C")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("Claude Usage")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.4 : 1)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading usage data…")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Login Prompt

    private var loginPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Sign in to view usage")
                .font(.system(size: 13, weight: .medium))
            Text("Your Claude session and weekly limits\nwill appear here.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign in to Claude") {
                viewModel.showLogin()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.91, green: 0.53, blue: 0.28))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Usage Content

    private var sessionPace: UsagePace? {
        guard let pct = viewModel.sessionPercent else { return nil }
        return calculatePace(sessionPercent: pct, sessionReset: viewModel.sessionReset)
    }

    private var weeklyPace: UsagePace? {
        guard let pct = viewModel.weeklyPercent else { return nil }
        return calculateWeeklyPace(weeklyPercent: pct, weeklyReset: viewModel.weeklyReset)
    }

    /// Fraction of the 5-hour session window that has elapsed (0–1).
    private var sessionExpectedFraction: Double? {
        guard let reset = viewModel.sessionReset,
              let minutesLeft = parseMinutesRemaining(reset) else { return nil }
        return max(0, min((300.0 - Double(minutesLeft)) / 300.0, 1))
    }

    /// Fraction of the 7-day weekly window that has elapsed (0–1).
    private var weeklyExpectedFraction: Double? {
        guard let reset = viewModel.weeklyReset,
              let minutesLeft = parseWeeklyMinutesRemaining(reset) else { return nil }
        let total = 7.0 * 24 * 60
        return max(0, min((total - Double(minutesLeft)) / total, 1))
    }

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            UsageRow(
                label: "Current Session",
                subtext: viewModel.sessionReset.map { "Resets in \($0)" } ?? "—",
                percent: viewModel.sessionPercent,
                paceColor: sessionPace?.swiftUIColor,
                paceLabel: sessionPace?.label,
                expectedFraction: sessionExpectedFraction
            )

            UsageRow(
                label: "Weekly · All Models",
                subtext: viewModel.weeklyReset.map { "Resets \($0)" } ?? "—",
                percent: viewModel.weeklyPercent,
                paceColor: weeklyPace?.swiftUIColor,
                paceLabel: weeklyPace?.label,
                expectedFraction: weeklyExpectedFraction
            )

            if viewModel.isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                    Text("Refreshing…")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else if !viewModel.lastUpdatedText.isEmpty {
                Text(viewModel.lastUpdatedText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Button("Open in Browser") {
                NSWorkspace.shared.open(URL(string: "https://claude.ai/settings/usage")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Usage Row

struct UsageRow: View {
    let label: String
    let subtext: String
    let percent: Int?
    var paceColor: Color? = nil        // pace-based override (session row only)
    var paceLabel: String? = nil       // "Low usage", "On pace", etc.
    var expectedFraction: Double? = nil // where you should be based on time elapsed

    private var fraction: Double {
        guard let p = percent else { return 0 }
        return min(max(Double(p) / 100.0, 0), 1)
    }

    /// Weekly bar uses simple threshold coloring; session bar uses pace color
    private var barColor: Color {
        if let override = paceColor { return override }
        guard let p = percent else { return Color.secondary.opacity(0.4) }
        if p >= 90 { return Color(red: 0.92, green: 0.25, blue: 0.25) }
        if p >= 75 { return Color(red: 0.95, green: 0.55, blue: 0.1) }
        return Color(red: 0.2, green: 0.65, blue: 0.98)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if let pace = paceLabel {
                    Text(pace)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(paceColor ?? .secondary)
                }
                Text(percent.map { "\($0)% used" } ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction, height: 7)
                        .animation(.easeInOut(duration: 0.6), value: fraction)

                    if let ef = expectedFraction {
                        let x = geo.size.width * ef
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.primary.opacity(0.45))
                                .frame(width: 1.5, height: 7)
                            PaceTriangle()
                                .fill(Color.primary.opacity(0.45))
                                .frame(width: 6, height: 4)
                        }
                        .offset(x: x - 0.75)
                    }
                }
            }
            .frame(height: expectedFraction != nil ? 11 : 7)

            Text(subtext)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Pace marker triangle (points upward from below the bar)

private struct PaceTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
