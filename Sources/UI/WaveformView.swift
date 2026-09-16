import SwiftUI

/// A live bar waveform driven by a level callback returning dBFS (≈ -160…0).
struct WaveformView: View {
    let level: @MainActor () -> Float

    @State private var samples: [Float] = Array(repeating: 0, count: 48)
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let count = samples.count
            guard count > 0 else { return }
            let barWidth = size.width / CGFloat(count)
            let midY = size.height / 2
            for (i, value) in samples.enumerated() {
                let height = max(2, CGFloat(value) * size.height)
                let x = CGFloat(i) * barWidth
                let rect = CGRect(x: x, y: midY - height / 2, width: barWidth * 0.7, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth * 0.35), with: .color(.accentColor))
            }
        }
        .onReceive(timer) { _ in
            let normalized = max(0, min(1, (level() + 60) / 60))
            samples.append(normalized)
            if samples.count > 48 { samples.removeFirst() }
        }
    }
}
