import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os

/// Result of an insertion attempt.
enum InjectionOutcome: Equatable {
    /// A paste keystroke was sent to the frontmost app (text is also on the clipboard).
    case pasted
    /// Couldn't attempt a paste; the text is on the clipboard for manual use.
    case copiedToClipboard(reason: String)
}

/// Inserts text into the frontmost app. The transcription is always placed on
/// the clipboard (the reliable result); when Accessibility is granted we
/// additionally fire a best-effort ⌘V on top. Nothing is restored — the text
/// stays on the clipboard.
@MainActor
final class TextInjectionService {

    /// Hint recognized by well-behaved clipboard-history managers (Paste,
    /// Maccy, Raycast, …) to skip archiving this pasteboard item. It does not
    /// clear the live pasteboard itself — that's handled separately below.
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    @discardableResult
    func inject(_ text: String, pressEnter: Bool, autoClearDelay: TimeInterval?, restoreClipboard: Bool) throws -> InjectionOutcome {
        let pasteboard = NSPasteboard.general
        let snapshot: String? = restoreClipboard ? pasteboard.string(forType: .string) : nil
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setString("", forType: Self.transientType)

        guard AXIsProcessTrusted() else {
            // The clipboard is the delivery here — never clear or restore it.
            Log.injection.notice("Accessibility not trusted; text left on clipboard.")
            return .copiedToClipboard(reason: "Accessibility not granted")
        }

        // Best-effort ⌘V on top of the clipboard. May still fail (e.g. no
        // focused text field); the clipboard copy is the fallback.
        try paste()
        if pressEnter { try pressReturn() }

        if restoreClipboard {
            // Pasting apps read the pasteboard asynchronously after the
            // keystroke; restore only once the paste has had time to land.
            scheduleClipboardRestore(snapshot, expectedChangeCount: pasteboard.changeCount)
        } else if let autoClearDelay {
            scheduleClipboardClear(after: autoClearDelay, expectedChangeCount: pasteboard.changeCount)
        }
        return .pasted
    }

    /// Clears the clipboard after `delay`, but only if nothing else has been
    /// copied since (`changeCount` still matches) — never clobbers content the
    /// user copied in the meantime.
    private func scheduleClipboardClear(after delay: TimeInterval, expectedChangeCount: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount == expectedChangeCount else { return }
            pasteboard.clearContents()
        }
    }

    /// Puts the pre-injection clipboard contents back once the paste has been
    /// consumed, but only if nothing else has been copied since.
    private func scheduleClipboardRestore(_ snapshot: String?, expectedChangeCount: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount == expectedChangeCount else { return }
            pasteboard.clearContents()
            if let snapshot {
                pasteboard.setString(snapshot, forType: .string)
            }
        }
    }

    // MARK: - Synthetic key events

    private func paste() throws {
        try postKey(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }

    private func pressReturn() throws {
        try postKey(CGKeyCode(kVK_Return), flags: [])
    }

    private func postKey(_ key: CGKeyCode, flags: CGEventFlags) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            throw DictationError.injectionFailed("Could not create key events.")
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
