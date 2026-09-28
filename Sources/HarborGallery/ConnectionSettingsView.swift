import SwiftUI

struct ConnectionSettingsView: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var replacementToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: GallerySpacing.space24) {
            Text("Harbor Connection")
                .font(.title2.weight(.semibold))

            if store.token != nil {
                Label("Connected — token stored in Mac Keychain", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                Divider()

                Text("Replace token")
                    .font(.headline)
                SecureField("hbp_…", text: $replacementToken)
                    .textFieldStyle(.roundedBorder)
                Text("The token needs Harbor’s Files, Notes, and Notebooks permissions to create galleries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Save New Token") {
                        Task {
                            if await store.connect(using: replacementToken) {
                                replacementToken = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(replacementToken.isEmpty || store.isLoading)

                    Spacer()

                    Button("Disconnect", role: .destructive) {
                        store.disconnect()
                    }
                }
            } else {
                Text("Open the main Harbor Gallery window to connect your account.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
