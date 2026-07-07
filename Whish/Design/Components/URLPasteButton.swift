import SwiftUI

/// Compact paste control for URL fields. Wraps the system `PasteButton` so
/// tapping never triggers the iOS paste-permission alert, and the control
/// dims automatically when the clipboard has no text.
struct URLPasteButton: View {
    @Binding var text: String
    var tint: Color = Theme.Colors.accent

    var body: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let pasted = strings.first else { return }
            Task { @MainActor in
                text = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .labelStyle(.titleOnly)
        .buttonBorderShape(.capsule)
        .controlSize(.mini)
        .tint(tint)
    }
}

#Preview {
    @Previewable @State var text = ""
    return VStack(spacing: 20) {
        URLPasteButton(text: $text)
        Text(text.isEmpty ? "clipboard content appears here" : text)
            .font(.caption)
    }
    .padding()
}
