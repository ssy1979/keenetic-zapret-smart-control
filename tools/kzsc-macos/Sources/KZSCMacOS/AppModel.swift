import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var language: AppLanguage = .english
    @Published var panelURL = "http://192.168.1.1:9090/"
    @Published var routerHost = "192.168.1.1"
    @Published var keeneticUser = "admin"
    @Published var keeneticPassword = ""
    @Published var sshPort = 222
    @Published var sshFingerprint = ""
    @Published var log = "Ready."
    @Published var discovered: [SubnetScanner.Candidate] = []
    @Published var panelJSON = ""
    @Published var releaseTag = ""
    /// Fresh Entware installations use root/keenetic by default. A user who
    /// changed the Entware password can replace this value in the form.
    @Published var sshPassword = "keenetic"
    @Published var installOutput = ""
    @Published var installationComplete = false
    @Published var installationInProgress = false

    private let panel = PanelAPI()
    private let scanner = SubnetScanner()
    private let release = ReleaseClient()
    private let ssh = SSHTransport()

    private func text(_ english: String, _ turkish: String) -> String {
        language.text(english, turkish)
    }

    func scanLAN() {
        log = text("Scanning the local /24 network…", "Yerel /24 ağ taranıyor…")
        Task { [scanner] in
            do {
                let result = try await scanner.scanLocal24()
                self.discovered = result
                self.log = self.text("Found \(result.count) candidate(s).", "\(result.count) aday bulundu.")
            } catch { self.log = self.text("LAN scan failed: \(error.localizedDescription)", "LAN taraması başarısız: \(error.localizedDescription)") }
        }
    }

    func checkPanel() {
        log = text("Checking KZSC panel…", "KZSC paneli kontrol ediliyor…")
        Task {
            do {
                let json = try await panel.getJSON(baseURL: panelURL, path: "cgi-bin/health.cgi")
                panelJSON = json.prettyPrinted
                log = text("Panel health check passed.", "Panel sağlık kontrolü başarılı.")
            } catch { log = text("Panel check failed: \(error.localizedDescription)", "Panel kontrolü başarısız: \(error.localizedDescription)") }
        }
    }

    func checkRelease() {
        log = text("Checking the trusted GitHub release…", "Güvenilir GitHub sürümü kontrol ediliyor…")
        Task {
            do {
                let r = try await release.latest()
                releaseTag = r.tag
                log = self.text("Trusted release: \(r.tag). Archive and SHA-256 manifest are present.", "Güvenilir sürüm: \(r.tag). Arşiv ve SHA-256 manifesti hazır.")
            } catch { log = self.text("Release check failed: \(error.localizedDescription)", "Sürüm kontrolü başarısız: \(error.localizedDescription)") }
        }
    }

    func installDirectly() {
        guard !installationInProgress else { return }
        installationComplete = false
        installationInProgress = true
        installOutput = ""
        do {
            let fingerprint = sshFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fingerprint.isEmpty else { installationInProgress = false; throw SSHTransport.Error.commandFailed(text("Verify the SSH fingerprint first", "Önce SSH parmak izini doğrulayın")) }
            guard !sshPassword.isEmpty else { installationInProgress = false; throw SSHTransport.Error.commandFailed(text("Enter the Entware root password first", "Önce Entware root parolasını girin")) }
            log = text("Checking the latest release…", "En son sürüm kontrol ediliyor…")
            Task { [ssh, release, host = routerHost, fingerprint, password = sshPassword,
                    adminUser = keeneticUser, adminPassword = keeneticPassword] in
                do {
                    let latest = try await release.latest()
                    self.log = self.text("Downloading and verifying \(latest.tag)…", "\(latest.tag) indiriliyor ve doğrulanıyor…")
                    let staging = FileManager.default.temporaryDirectory
                        .appendingPathComponent("kzsc-install-\(UUID().uuidString)", isDirectory: true)
                    let archive = try await release.downloadAndVerify(latest, directory: staging)
                    defer { try? FileManager.default.removeItem(at: staging) }
                    self.releaseTag = latest.tag
                    self.log = self.text("Release verified. Connecting to the router…", "Sürüm doğrulandı. Router'a bağlanılıyor…")
                    self.installOutput = self.text("Release verified. Starting the router connection…", "Sürüm doğrulandı. Router bağlantısı başlatılıyor…") + "\n"
                    let reportProgress: @Sendable (SSHTransport.InstallProgress) -> Void = { [weak self] stage in
                        Task { @MainActor [weak self] in
                            self?.recordInstallationProgress(stage)
                        }
                    }
                    let output = try await Task.detached(priority: .userInitiated) {
                        try ssh.install(host: host, archivePath: archive.path, fingerprint: fingerprint,
                                        password: password, adminUser: adminUser, adminPassword: adminPassword,
                                        progress: reportProgress)
                    }.value
                    self.installOutput = output
                    self.sshPassword = "keenetic"
                    self.keeneticPassword = ""
                    self.log = self.text("Installer finished. Waiting for the KZSC panel…", "Kurulum tamamlandı. KZSC paneli bekleniyor…")
                    await self.waitForPanelAfterInstall()
                } catch {
                    self.installOutput = error.localizedDescription
                    self.sshPassword = "keenetic"
                    self.keeneticPassword = ""
                    self.installationInProgress = false
                    self.log = self.text("Installation failed: \(error.localizedDescription)", "Kurulum başarısız: \(error.localizedDescription)")
                }
            }
        } catch { log = text("Installation failed: \(error.localizedDescription)", "Kurulum başarısız: \(error.localizedDescription)") }
    }

    func verifySSH() {
        log = text("Verifying SSH host key…", "SSH anahtarı doğrulanıyor…")
        let host = routerHost
        let expected = sshFingerprint
        Task { [ssh, host, expected] in
            do {
                var lastError: Swift.Error?
                var verifiedPort = 222
                var fp = ""
                for port in [222, 22] {
                    do {
                        fp = try await Task.detached(priority: .userInitiated) {
                            try ssh.verifyFingerprint(host: host, port: port, expected: expected.isEmpty ? nil : expected)
                        }.value
                        verifiedPort = port
                        break
                    } catch { lastError = error }
                }
                guard !fp.isEmpty else {
                    throw lastError ?? SSHTransport.Error.commandFailed(self.text("No SSH host key was found on port 222 or 22.", "222 veya 22 portunda SSH anahtarı bulunamadı."))
                }
                self.sshFingerprint = fp
                self.sshPort = verifiedPort
                self.log = self.text("Verified SSH ED25519 fingerprint on port \(verifiedPort): \(fp)", "SSH ED25519 parmak izi \(verifiedPort) portunda doğrulandı: \(fp)")
            } catch {
                self.log = self.text("SSH verification failed: \(error.localizedDescription)", "SSH doğrulaması başarısız: \(error.localizedDescription)")
            }
        }
    }

    func forgetSSHFingerprint() {
        sshFingerprint = ""
        sshPort = 222
        log = text("Saved SSH fingerprint cleared. Verify the router again before installation.", "Kayıtlı SSH parmak izi silindi. Kurulumdan önce router'ı yeniden doğrulayın.")
    }

    private func waitForPanelAfterInstall() async {
        for attempt in 0..<12 {
            do {
                let json = try await panel.getJSON(baseURL: panelURL, path: "cgi-bin/health.cgi")
                panelJSON = json.prettyPrinted
                installationComplete = true
                installationInProgress = false
                log = text("Installation completed and the KZSC panel is reachable.", "Kurulum tamamlandı ve KZSC paneline erişim sağlandı.")
                return
            } catch {
                if attempt < 11 { try? await Task.sleep(nanoseconds: 5_000_000_000) }
            }
        }
        installationComplete = false
        installationInProgress = false
        log = text("Installation was staged, but the panel is not reachable yet. Wait for the router reboot and check the panel again.", "Kurulum sıraya alındı ancak panele henüz erişilemiyor. Router'ın yeniden başlamasını bekleyip paneli tekrar kontrol edin.")
    }

    private func recordInstallationProgress(_ stage: SSHTransport.InstallProgress) {
        let message: String
        switch stage {
        case .connecting:
            message = text("Connecting to the verified router over SSH…", "Doğrulanmış router'a SSH ile bağlanılıyor…")
        case .bootstrappingEntware:
            message = text("SSH 222 is unavailable. Checking and preparing Entware through Keenetic SSH 22…", "SSH 222 kullanılamıyor. Keenetic SSH 22 üzerinden Entware kontrol edilip hazırlanıyor…")
        case .waitingForEntwareSSH:
            message = text("Waiting for Entware SSH 222. This can take up to four minutes after a component change or reboot…", "Entware SSH 222 bekleniyor. Bileşen değişimi veya yeniden başlatma sonrasında bu işlem dört dakikaya kadar sürebilir…")
        case .authenticatingEntware:
            message = text("Checking Entware SSH 222 authentication before uploading the archive…", "Arşiv yüklenmeden önce Entware SSH 222 kimlik doğrulaması kontrol ediliyor…")
        case .uploadingArchive:
            message = text("Uploading the verified KZSC archive to the router…", "Doğrulanmış KZSC arşivi router'a yükleniyor…")
        case .runningInstaller:
            message = text("Running the KZSC installer on the router. The app will detect a reboot and wait for the panel…", "KZSC kurucusu router üzerinde çalıştırılıyor. Uygulama yeniden başlatmayı algılayıp paneli bekleyecek…")
        }
        log = message
        installOutput += "\(message)\n"
    }

    @discardableResult
    func openPanel() -> Bool {
        do {
            let validated = try PanelAPI.validate(baseURL: panelURL)
            panelURL = validated.absoluteString
            log = text("Panel URL validated.", "Panel URL'si doğrulandı.")
            return true
        } catch {
            log = text("Panel URL rejected: \(error.localizedDescription)", "Panel URL'si reddedildi: \(error.localizedDescription)")
            return false
        }
    }
}

private extension Data {
    var prettyPrinted: String {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let output = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let text = String(data: output, encoding: .utf8) else { return String(decoding: self, as: UTF8.self) }
        return text
    }
}
