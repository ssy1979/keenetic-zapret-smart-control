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

    /// Copies the verified archive and runs its installer without opening a
    /// separate Terminal window. The password is passed only to the temporary
    /// pseudo-terminal and is never placed in command arguments or on disk.
    func install(host: String, archivePath: String, fingerprint: String, password: String, adminUser: String = "admin", adminPassword: String = "") throws -> String {
        guard !password.isEmpty else { throw Error.commandFailed("Router password is required") }
        guard host.range(of: #"^[A-Za-z0-9.:-]+$"#, options: .regularExpression) != nil else { throw Error.commandFailed("Invalid router host") }
        guard archivePath.range(of: #"^/[A-Za-z0-9._/-]+$"#, options: .regularExpression) != nil else { throw Error.commandFailed("Invalid archive path") }

        var output = ""
        var selectedPort = 0
        var selectedScan = ""
        for port in [222, 22] {
            guard let scan = try? run("/usr/bin/ssh-keyscan", ["-T", "5", "-t", "ed25519", "-p", String(port), host]),
                  !scan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let probeFile = FileManager.default.temporaryDirectory.appendingPathComponent("kzsc-probe-\(UUID().uuidString)")
            try scan.write(to: probeFile, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: probeFile) }
            let actualOutput = try run("/usr/bin/ssh-keygen", ["-lf", probeFile.path, "-E", "sha256"])
            guard let actual = actualOutput.split(whereSeparator: { $0 == " " || $0 == "\t" }).first(where: { $0.hasPrefix("SHA256:") }) else { continue }
            if !fingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && String(actual) != fingerprint.trimmingCharacters(in: .whitespacesAndNewlines) { continue }
            selectedPort = port
            selectedScan = scan
            break
        }
        guard selectedPort != 0 else {
            throw Error.commandFailed("No trusted ED25519 SSH host key was found on ports 222 or 22")
        }

        var knownHosts = FileManager.default.temporaryDirectory.appendingPathComponent("kzsc-known-hosts-\(UUID().uuidString)")
        if selectedPort == 22 {
            output += "Entware /opt is not available on SSH 222; checking and enabling it through Keenetic SSH 22…\n"
            let adminPassword = adminPassword.isEmpty ? password : adminPassword
            let bootstrap = "/bin/ndmc -c 'opkg disk storage:/' && /bin/ndmc -c 'opkg initrc /opt/etc/init.d/rc.unslung' && /bin/ndmc -c 'opkg timezone auto' && /bin/ndmc -c 'system configuration save'"
            let bootstrapHosts = FileManager.default.temporaryDirectory.appendingPathComponent("kzsc-bootstrap-hosts-\(UUID().uuidString)")
            try selectedScan.write(to: bootstrapHosts, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: bootstrapHosts) }
            do {
                output += try runWithPassword("/usr/bin/ssh", ["-o", "StrictHostKeyChecking=yes", "-o", "UserKnownHostsFile=\(bootstrapHosts.path)", "-p", "22", "\(adminUser)@\(host)", bootstrap], password: adminPassword)
            } catch {
                output += "Keenetic Entware bootstrap command returned: \(error.localizedDescription)\n"
            }
            guard waitForSSH(host: host, port: 222, timeout: 240) else {
                throw Error.commandFailed("Entware SSH 222 did not become available. Check that storage:/ or a supported USB disk is configured.")
            }
            selectedPort = 222
            selectedScan = try run("/usr/bin/ssh-keyscan", ["-T", "5", "-t", "ed25519", "-p", "222", host])
        }
        guard !selectedScan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Error.commandFailed("No ED25519 SSH host key was returned") }
        try selectedScan.write(to: knownHosts, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: knownHosts) }

        if selectedPort != 222 {
            throw Error.commandFailed("Entware SSH 222 is required before KZSC can be installed")
        }

        let archiveName = URL(fileURLWithPath: archivePath).lastPathComponent
        let common = ["-o", "StrictHostKeyChecking=yes", "-o", "UserKnownHostsFile=\(knownHosts.path)"]
        output += try runWithPassword("/usr/bin/scp", common + ["-O", "-P", "222", archivePath, "root@\(host):/opt/tmp/\(archiveName)"], password: password)
        let remote = "mkdir -p /opt/tmp/kzsc-macos-stage && tar -xzf /opt/tmp/\(archiveName) -C /opt/tmp/kzsc-macos-stage && installer=$(find /opt/tmp/kzsc-macos-stage -name install.sh -type f | head -n1) && test -n \"$installer\" && rc=0 && /opt/bin/sh \"$installer\" || rc=$?; if [ \"$rc\" -eq 75 ]; then echo KZSC_REBOOT_PENDING=1; exit 0; fi; exit \"$rc\""
        output += try runWithPassword("/usr/bin/ssh", common + ["-p", "222", "root@\(host)", remote], password: password)
        return output
    }

    private func waitForSSH(host: String, port: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let scan = try? run("/usr/bin/ssh-keyscan", ["-T", "3", "-t", "ed25519", "-p", String(port), host]),
               !scan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
            Thread.sleep(forTimeInterval: 5)
        }
        return false
    }

    private func run(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        let output = Pipe(); process.standardOutput = output; process.standardError = output
        try process.run(); process.waitUntilExit()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { throw Error.commandFailed(text.trimmingCharacters(in: .whitespacesAndNewlines).suffix(500).description) }
        return text
    }

    private func runWithPassword(_ path: String, _ arguments: [String], password: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", path] + arguments
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = output
        try process.run()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.25) {
            input.fileHandleForWriting.write(Data((password + "\n").utf8))
            try? input.fileHandleForWriting.close()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw Error.commandFailed(text.trimmingCharacters(in: .whitespacesAndNewlines).suffix(800).description)
        }
        return text
    }
}
