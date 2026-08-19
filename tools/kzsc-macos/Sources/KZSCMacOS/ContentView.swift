import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showPanel = false

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 360, idealWidth: 410, maxWidth: 520)
            detail
                .frame(minWidth: 650)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Picker(t("Language", "Dil"), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 125)
            }
        }
        .sheet(isPresented: $showPanel) {
            if let url = URL(string: model.panelURL) {
                PanelWebView(url: url).frame(minWidth: 1000, minHeight: 700)
            } else {
                Text(t("Invalid panel URL", "Geçersiz panel URL'si")).padding()
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("KZSC macOS").font(.title2.bold())
                Text(t("Follow the numbered steps on the right. This app performs the SSH installation itself and never stores router passwords.", "Sağdaki numaralı adımları izleyin. Bu uygulama SSH kurulumunu kendisi yapar ve router parolalarını saklamaz."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GroupBox(t("KZSC panel", "KZSC paneli")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(t("Panel URL", "Panel URL'si"), text: $model.panelURL)
                        Button(t("Check panel", "Paneli kontrol et")) { model.checkPanel() }
                        Button(t("Open full KZSC panel", "Tam KZSC panelini aç")) { showPanel = model.openPanel() }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(t("Installation", "Kurulum")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(t("Router IP", "Router IP'si"), text: $model.routerHost)
                        TextField(t("Keenetic SSH 22 user", "Keenetic SSH 22 kullanıcısı"), text: $model.keeneticUser)
                        SecureField(t("Keenetic admin password", "Keenetic yönetici parolası"), text: $model.keeneticPassword)
                        Text(t("Enter the same password you use for the Keenetic web panel. It is not stored.", "Keenetic web panelinde kullandığınız aynı parolayı girin. Parola saklanmaz."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(t("Verified ED25519 SHA-256 fingerprint", "Doğrulanmış ED25519 SHA-256 parmak izi"), text: $model.sshFingerprint)
                        Button(t("Verify SSH 222/22 fingerprint", "SSH 222/22 parmak izini doğrula")) { model.verifySSH() }
                        Button(t("Forget saved SSH fingerprint", "Kayıtlı SSH anahtarını unut")) { model.forgetSSHFingerprint() }
                        Button(t("Scan local LAN", "Yerel LAN'ı tara")) { model.scanLAN() }
                        Button(t("Check trusted release", "Güvenilir sürümü kontrol et")) { model.checkRelease() }
                        SecureField(t("Entware root password", "Entware root parolası"), text: $model.sshPassword)
                        Text(t("Fresh Entware installs use root / keenetic by default. Change this only if you set a custom Entware password.", "Yeni Entware kurulumlarında varsayılan root / keenetic kullanılır. Yalnızca özel bir Entware parolası belirlediyseniz değiştirin."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(t("Install directly from this app", "Bu uygulamadan doğrudan kur")) { model.installDirectly() }
                        Text(t("The app downloads the latest verified release directly from GitHub during installation. Passwords are used only for this SSH session, then cleared from the form.", "Uygulama kurulum sırasında doğrulanmış en son sürümü doğrudan GitHub'dan alır. Parolalar yalnızca bu SSH oturumunda kullanılır ve formdan temizlenir."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(t("Verified package", "Doğrulanmış paket")) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !model.releaseTag.isEmpty { Text(model.releaseTag).font(.caption.monospaced()) }
                        if !model.installOutput.isEmpty {
                            Text(model.installOutput).font(.caption.monospaced()).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }

                if !model.discovered.isEmpty {
                    GroupBox(t("Candidates", "Adaylar")) {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(model.discovered) { candidate in
                                Text("\(candidate.address) · \(candidate.ports.sorted().map(String.init).joined(separator: ", "))")
                                    .font(.caption.monospaced()).textSelection(.enabled)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
        }
        .background(.background)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("KZSC installer and control", "KZSC kurulum ve kontrol")).font(.title.bold())
                Text(t("A guided installer for the Keenetic router. The app verifies, downloads, and installs KZSC through SSH.", "Keenetic router için yönlendirmeli kurulum. Uygulama KZSC'yi SSH üzerinden doğrular, indirir ve kurar."))
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                GuidedSetup(model: model)
                Divider()
                Text(model.log == "Ready." ? t("Ready.", "Hazır.") : model.log).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(model.panelJSON.isEmpty ? t("Panel status will appear here.", "Panel durumu burada görünecek.") : model.panelJSON)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
                    .padding().background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.background)
    }

    private func t(_ english: String, _ turkish: String) -> String {
        model.language.text(english, turkish)
    }
}

private struct GuidedSetup: View {
    @ObservedObject var model: AppModel
    private var panelReady: Bool { !model.panelJSON.isEmpty || !model.discovered.isEmpty }
    private var releaseReady: Bool { !model.releaseTag.isEmpty }
    private var sshReady: Bool { !model.sshFingerprint.isEmpty }

    var body: some View {
        GroupBox(model.language.text("Guided setup", "Yönlendirmeli kurulum")) {
            VStack(alignment: .leading, spacing: 9) {
                GuidedStepRow(number: 1,
                    title: model.language.text("Connect and analyze the router", "Router'a bağlan ve analiz et"),
                    detail: model.language.text("Scan the LAN or check an existing KZSC panel URL.", "LAN'ı tarayın veya mevcut KZSC panel URL'sini kontrol edin."),
                    complete: panelReady, actionTitle: model.language.text("Scan local LAN", "Yerel LAN'ı tara"), action: { model.scanLAN() })
                GuidedStepRow(number: 2,
                    title: model.language.text("Check the latest trusted KZSC release", "En son güvenilir KZSC sürümünü kontrol et"),
                    detail: model.language.text("The app downloads and verifies the archive directly from GitHub only when installation starts.", "Uygulama arşivi yalnızca kurulum başladığında doğrudan GitHub'dan indirip doğrular."),
                    complete: releaseReady, actionTitle: releaseReady ? nil : model.language.text("Check latest release", "Son sürümü kontrol et"), action: { model.checkRelease() })
                GuidedStepRow(number: 3,
                    title: model.language.text("Verify SSH 222/22", "SSH 222/22'yi doğrula"),
                    detail: model.language.text("Confirm the router's ED25519 host key before sending anything. Fresh Entware setups may use SSH 22 first.", "Herhangi bir şey göndermeden önce router'ın ED25519 anahtarını doğrulayın. Yeni Entware kurulumlarında önce SSH 22 kullanılabilir."),
                    complete: sshReady, actionTitle: sshReady ? nil : model.language.text("Verify SSH fingerprint", "SSH parmak izini doğrula"), action: { model.verifySSH() })
                GuidedStepRow(number: 4,
                    title: model.language.text("Install KZSC directly in this app", "KZSC'yi bu uygulamadan doğrudan kur"),
                    detail: model.language.text("Enter the router and admin passwords on the left. The app downloads the latest release, checks KeeneticOS and Entware, installs or queues anything missing, and verifies panel access after reboot.", "Router ve yönetici parolalarını solda girin. Uygulama en son sürümü indirir, KeeneticOS ve Entware'ı kontrol eder, eksikleri kurar veya sıraya alır ve yeniden başlatma sonrası panel erişimini doğrular."),
                    complete: model.installationComplete, actionTitle: model.installationComplete ? nil : model.language.text("Start installation", "Kurulumu başlat"), action: { model.installDirectly() })
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GuidedStepRow: View {
    let number: Int
    let title: String
    let detail: String
    let complete: Bool
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(complete ? "✓" : "\(number)")
                .font(.headline).foregroundStyle(complete ? .green : .accentColor)
                .frame(width: 26, height: 26).background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle {
                    Button(actionTitle, action: action).controlSize(.small).padding(.top, 2)
                }
            }
        }
    }
}
