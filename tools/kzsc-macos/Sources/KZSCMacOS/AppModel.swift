import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var language: AppLanguage = .english
    @Published var panelURL = "http://192.168.1.1:9090/"
    @Published var routerHost = "192.168.1.1"
    @Published var sshFingerprint = ""
    @Published var log = "Ready."
    @Published var discovered: [SubnetScanner.Candidate] = []
    @Published var panelJSON = ""
    @Published var releaseTag = ""
    @Published var archivePath = ""
    @Published var installCommand = ""

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

    func downloadRelease() {
        log = text("Downloading and verifying the trusted release…", "Güvenilir sürüm indiriliyor ve doğrulanıyor…")
        Task {
            do {
                let r = try await release.latest()
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let directory = downloads.appendingPathComponent("KZSC", isDirectory: true)
                let archive = try await release.downloadAndVerify(r, directory: directory)
                releaseTag = r.tag
                archivePath = archive.path
                log = self.text("Verified \(r.tag) archive saved to \(archive.path).", "Doğrulanan \(r.tag) arşivi \(archive.path) konumuna kaydedildi.")
            } catch { log = self.text("Release download failed: \(error.localizedDescription)", "Sürüm indirme başarısız: \(error.localizedDescription)") }
        }
    }

    func prepareInstallCommand() {
        do {
            guard !archivePath.isEmpty else { throw SSHTransport.Error.commandFailed(text("Download a verified release first", "Önce doğrulanmış bir sürüm indirin")) }
            let fingerprint = sshFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fingerprint.isEmpty else { throw SSHTransport.Error.commandFailed(text("Verify the SSH fingerprint first", "Önce SSH parmak izini doğrulayın")) }
            installCommand = try ssh.interactiveInstallCommand(host: routerHost, archivePath: archivePath, fingerprint: fingerprint)
            log = text("Interactive SSH install command prepared. Enter the password when Terminal prompts.", "Etkileşimli SSH kurulum komutu hazırlandı. Terminal istediğinde parolayı girin.")
        } catch { log = text("Install command failed: \(error.localizedDescription)", "Kurulum komutu başarısız: \(error.localizedDescription)") }
    }

    func verifySSH() {
        log = text("Verifying SSH host key…", "SSH anahtarı doğrulanıyor…")
        let host = routerHost
        let expected = sshFingerprint
        Task { [ssh, host, expected] in
            do {
                let fp = try await Task.detached(priority: .userInitiated) {
                    try ssh.verifyFingerprint(host: host, port: 222, expected: expected.isEmpty ? nil : expected)
                }.value
                self.sshFingerprint = fp
                self.log = self.text("Verified SSH ED25519 fingerprint: \(fp)", "SSH ED25519 parmak izi doğrulandı: \(fp)")
            } catch {
                self.log = self.text("SSH verification failed: \(error.localizedDescription)", "SSH doğrulaması başarısız: \(error.localizedDescription)")
            }
        }
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
