import SwiftUI
import AppKit

/// Floating overlay content shown while preparing/recording: preparation
/// status, or live waveform + partial text.
struct RecordingHUD: View {
    let engine: DictationEngine

    var body: some View {
        VStack(spacing: 8) {
            if engine.state.isPreparing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(preparingLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 8) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    WaveformView(level: engine.micLevel)
                        .frame(height: 22)
                }
                if let transcript = engine.state.liveTranscript, !transcript.isEmpty {
                    Text(transcript)
                        .font(.caption)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var preparingLabel: String {
        if let progress = engine.preparationProgress, progress > 0 {
            return "Preparing… \(Int(progress * 100))%"
        }
        return "Preparing…"
    }
}

/// Manages a borderless floating panel that mirrors the engine's state.
/// Lives for the app's lifetime; shows/hides as dictation starts/stops.
@MainActor
final class RecordingHUDController {
    private let engine: DictationEngine
    private let settingsStore: SettingsStore
    private var panel: NSPanel?
    private static let size = NSSize(width: 264, height: 80)

    init(engine: DictationEngine, settingsStore: SettingsStore) {
        self.engine = engine
        self.settingsStore = settingsStore
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = engine.state
            _ = settingsStore.settings.showHUD
            _ = settingsStore.settings.hudPosition
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observe()
            }
        }
        sync()
    }

    private func sync() {
        let state = engine.state
        let shouldShow = (state.isRecording || state.isPreparing) && settingsStore.settings.showHUD
        if shouldShow {
            show()
            // Re-apply so a position change moves an on-screen panel.
            panel?.setFrameOrigin(origin(for: Self.size))
        } else {
            hide()
        }
    }

    private func show() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RecordingHUD(engine: engine))
        panel.setFrameOrigin(origin(for: Self.size))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func origin(for size: NSSize) -> NSPoint {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pad: CGFloat = 24
        switch settingsStore.settings.hudPosition {
        case .topLeft:     return NSPoint(x: frame.minX + pad, y: frame.maxY - size.height - pad)
        case .topRight:    return NSPoint(x: frame.maxX - size.width - pad, y: frame.maxY - size.height - pad)
        case .bottomLeft:  return NSPoint(x: frame.minX + pad, y: frame.minY + pad)
        case .bottomRight: return NSPoint(x: frame.maxX - size.width - pad, y: frame.minY + pad)
        }
    }
}
