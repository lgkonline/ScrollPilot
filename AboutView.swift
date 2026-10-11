import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? String(localized: "Unknown")
    }

    private var build: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? String(localized: "Unknown")
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            links
            Divider()
            acknowledgements
        }
        .padding(32)
        .frame(width: 460, height: 500)
    }

    private var header: some View {
        VStack(spacing: 12) {
            personalLogo

            Text("ScrollPilot")
                .font(.largeTitle.bold())

            HStack(spacing: 5) {
                Text("Version")
                Text(version)
                Text("·")
                    .accessibilityHidden(true)
                Text("Build")
                Text(build)
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var personalLogo: some View {
        if let image = NSImage(named: "LgkLogo") {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
                .frame(width: 64, height: 64)
                .accessibilityLabel("Personal logo")
        }
    }

    private var links: some View {
        HStack(spacing: 20) {
            ExternalLink(
                title: "Website",
                urlString: "https://scrollpilot.lgk.io"
            )
            ExternalLink(
                title: "GitHub",
                urlString: "https://github.com/lgkonline/ScrollPilot"
            )
        }
    }

    private var acknowledgements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acknowledgements")
                .font(.headline)

            Text("The app icon uses an icon from Bootstrap Icons.")

            HStack(spacing: 16) {
                ExternalLink(
                    title: "Bootstrap Icons",
                    urlString: "https://icons.getbootstrap.com"
                )
                ExternalLink(
                    title: "MIT License",
                    urlString: "https://github.com/twbs/icons/blob/main/LICENSE.md"
                )
            }

            Text("Most of ScrollPilot’s code was created with AI assistance from ChatGPT and Codex.")

            HStack(spacing: 16) {
                ExternalLink(
                    title: "ChatGPT",
                    urlString: "https://chatgpt.com"
                )
                ExternalLink(
                    title: "Codex",
                    urlString: "https://openai.com/codex"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExternalLink: View {
    let title: LocalizedStringKey
    let urlString: String

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        } label: {
            Label(title, systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.link)
    }
}

#Preview {
    AboutView()
}
