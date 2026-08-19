import Foundation
import Darwin
import Network

struct SubnetScanner: Sendable {
    struct Candidate: Identifiable, Sendable { let address: String; let ports: Set<Int>; var id: String { address } }

    func scanLocal24() async throws -> [Candidate] {
        guard let local = localIPv4() else { return [] }
        let prefix = local.split(separator: ".").dropLast().joined(separator: ".")
        return await withTaskGroup(of: Candidate?.self, returning: [Candidate].self) { group in
            for host in 1...254 { group.addTask { await Self.probe("\(prefix).\(host)") } }
            var output: [Candidate] = []
            for await item in group { if let item { output.append(item) } }
            return output.sorted { $0.address.localizedStandardCompare($1.address) == .orderedAscending }
        }
    }

    private func localIPv4() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }
        for pointer in sequence(first: interfaces, next: { $0?.pointee.ifa_next }) {
            guard let item = pointer?.pointee, let addr = item.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET), let name = item.ifa_name else { continue }
            let interface = String(cString: name); if interface == "lo0" { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST)); getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let value = String(cString: host); if value.hasPrefix("192.168.") || value.hasPrefix("10.") || value.hasPrefix("172.") { address = value; break }
        }
        return address
    }

    private static func probe(_ address: String) async -> Candidate? {
        let ports = await withTaskGroup(of: (Int, Bool).self, returning: [Int].self) { group in
            for port in [22, 222, 80, 443, 9090] {
                group.addTask { (port, await Self.probePort(address, port: port)) }
            }
            var openPorts: [Int] = []
            for await (port, isOpen) in group where isOpen { openPorts.append(port) }
            return openPorts
        }
        return ports.isEmpty ? nil : Candidate(address: address, ports: Set(ports))
    }

    private static func probePort(_ address: String, port: Int) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(address),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            let lock = NSLock()
            var finished = false

            func finish(_ value: Bool) {
                lock.lock()
                guard !finished else { lock.unlock(); return }
                finished = true
                lock.unlock()
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(250)) {
                finish(false)
            }
        }
    }
}
