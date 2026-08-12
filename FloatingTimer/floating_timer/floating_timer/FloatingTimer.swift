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

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 240, height: 140),
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                if activeDuration != nil {
                    Text(timeString(remaining))
                        .font(.system(size: 69, weight: .bold, design: .rounded))
                        .foregroundColor(isFinished ? .red : .white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
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
                        .foregroundColor(.white.opacity(0.85))
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
