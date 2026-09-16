import SwiftUI
import AppKit

/// Small fixed About window: app identity plus developer contact details.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text("SpeakEase")
                .font(.title2).bold()
            Text("Version \(Self.version) (\(Self.build))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 160)

            VStack(spacing: 4) {
                Text("Nav Virdi")
                    .font(.callout)
                Link("Liberated.Studio", destination: URL(string: "https://Liberated.Studio")!)
                    .font(.callout)
                Link("nav@Liberated.Studio", destination: URL(string: "mailto:nav@Liberated.Studio")!)
                    .font(.callout)
            }
        }
        .padding(28)
        .frame(width: 280)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
