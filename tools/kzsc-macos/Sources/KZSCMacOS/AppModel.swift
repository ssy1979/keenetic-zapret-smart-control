import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
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

    func scanLAN() {
        log = "Scanning the local /24 network…"
        Task { [scanner] in
            do {
                let result = try await scanner.scanLocal24()
                self.discovered = result
                self.log = "Found \(result.count) candidate(s)."
            } catch { self.log = "LAN scan failed: \(error.localizedDescription)" }
        }
    }

    func checkPanel() {
        log = "Checking KZSC panel…"
        Task {
            do {
                let json = try await panel.getJSON(baseURL: panelURL, path: "cgi-bin/health.cgi")
                panelJSON = json.prettyPrinted
                log = "Panel health check passed."
            } catch { log = "Panel check failed: \(error.localizedDescription)" }
        }
    }

    func checkRelease() {
        log = "Checking the trusted GitHub release…"
        Task {
            do {
                let r = try await release.latest()
                releaseTag = r.tag
                log = "Trusted release: \(r.tag). Archive and SHA-256 manifest are present."
            } catch { log = "Release check failed: \(error.localizedDescription)" }
        }
    }

    func downloadRelease() {
        log = "Downloading and verifying the trusted release…"
        Task {
            do {
                let r = try await release.latest()
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let directory = downloads.appendingPathComponent("KZSC", isDirectory: true)
                let archive = try await release.downloadAndVerify(r, directory: directory)
                releaseTag = r.tag
                archivePath = archive.path
                log = "Verified \(r.tag) archive saved to \(archive.path)."
            } catch { log = "Release download failed: \(error.localizedDescription)" }
        }
    }

    func prepareInstallCommand() {
        do {
            guard !archivePath.isEmpty else { throw SSHTransport.Error.commandFailed("Download a verified release first") }
            let fingerprint = sshFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fingerprint.isEmpty else { throw SSHTransport.Error.commandFailed("Verify the SSH fingerprint first") }
            installCommand = try ssh.interactiveInstallCommand(host: routerHost, archivePath: archivePath, fingerprint: fingerprint)
            log = "Interactive SSH install command prepared. Passwords stay in the terminal prompt."
        } catch { log = "Install command failed: \(error.localizedDescription)" }
    }

    func verifySSH() {
        log = "Verifying SSH host key…"
        let host = routerHost
        let expected = sshFingerprint
        Task { [ssh, host, expected] in
            do {
                let fp = try await Task.detached(priority: .userInitiated) {
                    try ssh.verifyFingerprint(host: host, port: 222, expected: expected.isEmpty ? nil : expected)
                }.value
                self.sshFingerprint = fp
                self.log = "Verified SSH ED25519 fingerprint: \(fp)"
            } catch {
                self.log = "SSH verification failed: \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func openPanel() -> Bool {
        do {
            let validated = try PanelAPI.validate(baseURL: panelURL)
            panelURL = validated.absoluteString
            log = "Panel URL validated."
            return true
        } catch {
            log = "Panel URL rejected: \(error.localizedDescription)"
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
