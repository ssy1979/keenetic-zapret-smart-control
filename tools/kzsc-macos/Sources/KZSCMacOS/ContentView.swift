import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showPanel = false

    var body: some View {
        NavigationSplitView {
            Form {
                Section("KZSC panel") {
                    TextField("Panel URL", text: $model.panelURL)
                    Button("Check panel") { model.checkPanel() }
                    Button("Open full KZSC panel") { showPanel = model.openPanel() }
                }
                Section("Installation") {
                    TextField("Router IP", text: $model.routerHost)
                    TextField("Verified ED25519 SHA-256 fingerprint", text: $model.sshFingerprint)
                    Button("Verify SSH 222 fingerprint") { model.verifySSH() }
                    Button("Scan local LAN") { model.scanLAN() }
                    Button("Check trusted release") { model.checkRelease() }
                    Button("Download and verify latest release") { model.downloadRelease() }
                    Button("Prepare interactive SSH install command") { model.prepareInstallCommand() }
                    Text("Passwords are entered only in the interactive SSH flow and are not stored.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Verified package") {
                    if !model.releaseTag.isEmpty { Text(model.releaseTag).font(.caption.monospaced()) }
                    if !model.archivePath.isEmpty { Text(model.archivePath).font(.caption.monospaced()).textSelection(.enabled) }
                    if !model.installCommand.isEmpty {
                        Text(model.installCommand)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxHeight: 130, alignment: .topLeading)
                    }
                }
                Section("Candidates") {
                    ForEach(model.discovered) { candidate in
                        Text("\(candidate.address) · \(candidate.ports.sorted().map(String.init).joined(separator: ", "))")
                            .font(.caption.monospaced())
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("KZSC macOS")
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                Text("KZSC installer and control")
                    .font(.title.bold())
                Text(model.log).foregroundStyle(.secondary)
                Divider()
                Text(model.panelJSON.isEmpty ? "Panel status will appear here." : model.panelJSON)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding()
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .sheet(isPresented: $showPanel) {
            if let url = URL(string: model.panelURL) {
                PanelWebView(url: url).frame(minWidth: 1000, minHeight: 700)
            } else {
                Text("Invalid panel URL").padding()
            }
        }
    }
}
