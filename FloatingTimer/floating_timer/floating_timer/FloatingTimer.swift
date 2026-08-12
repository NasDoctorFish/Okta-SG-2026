import SwiftUI
import AppKit

// Xcode setup: New Project > macOS > App (SwiftUI). Delete generated App/ContentView files,
// add this file instead. Optional: set "Application is agent (UIElement)" in Info.plist
// to hide the dock icon (window stays floating regardless).

@main
struct FloatingTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class KeyableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = KeyableBorderlessWindow(
            contentRect: NSRect(x: 200, y: 200, width: 340, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: TimerView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct TimerOption {
    let label: String
    let seconds: Int
}

struct TimerView: View {
    private let options = [TimerOption(label: "8분", seconds: 480), TimerOption(label: "2분", seconds: 120)]

    @State private var activeDuration: Int? = nil
    @State private var remaining: Int = 0
    @State private var isFinished = false
    @State private var pulse = false
    @State private var usedDurations: Set<Int> = []
    @State private var isHovering = false
    @State private var timer: Timer?
    @State private var customMinutesText: String = ""

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                if activeDuration != nil {
                    Text(timeString(remaining))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(isFinished ? .red : .white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(isFinished && pulse ? 1.12 : 1.0)
                        .animation(
                            isFinished ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default,
                            value: pulse
                        )
                } else {
                    HStack(spacing: 12) {
                        ForEach(options, id: \.seconds) { option in
                            if !usedDurations.contains(option.seconds) {
                                Button(option.label) { start(option.seconds) }
                                    .buttonStyle(TimerButtonStyle())
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("분", text: $customMinutesText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(width: 80)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                            .onSubmit { startCustom() }
                        Button("시작") { startCustom() }
                            .buttonStyle(TimerButtonStyle())
                            .disabled(Int(customMinutesText) == nil || Int(customMinutesText)! <= 0)
                    }
                }
            }
            .padding(22)

            if isHovering && activeDuration != nil {
                Button(action: reset) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
        .frame(minWidth: 220, minHeight: 120)
        .background(Color.white.opacity(0.001))
        .onHover { hovering in isHovering = hovering }
        .overlay(alignment: .topLeading) {
            if isHovering && activeDuration == nil {
                Button(action: quit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red.opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }

    private func start(_ seconds: Int) {
        timer?.invalidate()
        activeDuration = seconds
        remaining = seconds
        isFinished = false
        pulse = false
        usedDurations.insert(seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 {
                remaining -= 1
            } else {
                isFinished = true
                pulse = true
                timer?.invalidate()
            }
        }
    }

    private func startCustom() {
        guard let minutes = Int(customMinutesText), minutes > 0 else { return }
        customMinutesText = ""
        start(minutes * 60)
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        activeDuration = nil
        isFinished = false
        pulse = false
        usedDurations.removeAll()
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct TimerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.black.opacity(configuration.isPressed ? 0.55 : 0.4))
            .clipShape(Capsule())
    }
}
