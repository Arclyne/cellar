import SwiftUI

struct LibraryStatusBar: View {
    @Environment(BottleLibrary.self) private var library

    var body: some View {
        VStack(spacing: 0) {
            if !library.isWineRuntimeAvailable {
                WineRuntimeMissingBanner()
            }
            if let activityMessage = library.activityMessage {
                ActivityBanner(message: activityMessage)
            }
        }
    }
}

struct WineRuntimeMissingBanner: View {
    private static let installationHint = "Download Wine Devel from github.com/Gcenx/macOS_Wine_builds and move it to Applications."

    @Environment(BottleLibrary.self) private var library

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wine is not installed")
                    .font(.headline)
                Text(Self.installationHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Check Again") {
                library.refresh()
            }
        }
        .padding(12)
        .background(.bar)
    }
}

struct ActivityBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(.callout)
                .lineLimit(1)
            Spacer()
        }
        .padding(12)
        .background(.bar)
    }
}
