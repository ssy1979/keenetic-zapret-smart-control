import Foundation

struct SSHTransport: Sendable {
    enum Error: LocalizedError { case commandFailed(String), fingerprintMismatch
        var errorDescription: String? { switch self { case .commandFailed(let text): return text; case .fingerprintMismatch: return "SSH host fingerprint changed or did not match" } }
    }

    func verifyFingerprint(host: String, port: Int, expected: String?) throws -> String {
        let scan = try run("/usr/bin/ssh-keyscan", ["-T", "5", "-t", "ed25519", "-p", String(port), host])
        guard !scan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Error.commandFailed("No ED25519 SSH host key was returned") }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("kzsc-host-key-\(UUID().uuidString)")
        try scan.write(to: file, atomically: true, encoding: .utf8); defer { try? FileManager.default.removeItem(at: file) }
        let fingerprintOutput = try run("/usr/bin/ssh-keygen", ["-lf", file.path, "-E", "sha256"])
        guard let actual = fingerprintOutput.split(whereSeparator: { $0 == " " || $0 == "\t" }).first(where: { $0.hasPrefix("SHA256:") }) else { throw Error.commandFailed("Unable to parse SSH fingerprint") }
        if let expected, !expected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, String(actual) != expected.trimmingCharacters(in: .whitespacesAndNewlines) { throw Error.fingerprintMismatch }
        return String(actual)
    }

    func interactiveInstallCommand(host: String, archivePath: String, fingerprint: String) throws -> String {
        guard host.range(of: #"^[A-Za-z0-9.:-]+$"#, options: .regularExpression) != nil else { throw Error.commandFailed("Invalid router host") }
        guard archivePath.range(of: #"^/[A-Za-z0-9._/-]+$"#, options: .regularExpression) != nil else { throw Error.commandFailed("Invalid archive path") }
        let archiveName = URL(fileURLWithPath: archivePath).lastPathComponent
        return "# Verified SSH fingerprint: \(fingerprint)\nscp -O -P 222 \(archivePath) root@\(host):/opt/tmp/ && ssh -p 222 root@\(host) 'mkdir -p /opt/tmp/kzsc-macos-stage && tar -xzf /opt/tmp/\(archiveName) -C /opt/tmp/kzsc-macos-stage && installer=$(find /opt/tmp/kzsc-macos-stage -name install.sh -type f | head -n1) && test -n \"$installer\" && /opt/bin/sh \"$installer\"'"
    }

    private func run(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        let output = Pipe(); process.standardOutput = output; process.standardError = output
        try process.run(); process.waitUntilExit()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { throw Error.commandFailed(text.trimmingCharacters(in: .whitespacesAndNewlines).suffix(500).description) }
        return text
    }
}
