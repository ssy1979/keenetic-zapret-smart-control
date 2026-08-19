import Foundation

struct PanelAPI: Sendable {
    enum Error: LocalizedError { case invalidURL, publicHTTP, http(Int), invalidJSON
        var errorDescription: String? { switch self { case .invalidURL: return "Invalid panel URL"; case .publicHTTP: return "Plain HTTP is limited to the local network"; case .http(let code): return "Panel HTTP status \(code)"; case .invalidJSON: return "Panel returned invalid JSON" } }
    }

    static func validate(baseURL: String) throws -> URL {
        guard var components = URLComponents(string: baseURL), let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https", components.user == nil, components.password == nil, components.query == nil, components.fragment == nil, let host = components.host else { throw Error.invalidURL }
        if scheme == "http" && !isPrivate(host) { throw Error.publicHTTP }
        if !components.path.hasSuffix("/") { components.path += "/" }
        guard let url = components.url else { throw Error.invalidURL }
        return url
    }

    func getJSON(baseURL: String, path: String) async throws -> Data {
        guard !path.hasPrefix("/") && !path.contains("..") else { throw Error.invalidURL }
        let base = try Self.validate(baseURL: baseURL)
        guard let url = URL(string: path, relativeTo: base) else { throw Error.invalidURL }
        var request = URLRequest(url: url); request.httpMethod = "GET"; request.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw Error.http((response as? HTTPURLResponse)?.statusCode ?? -1) }
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else { throw Error.invalidJSON }
        return data
    }

    private static func isPrivate(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" { return true }
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return false }
        return parts[0] == 10
            || (parts[0] == 192 && parts[1] == 168)
            || (parts[0] == 172 && (16...31).contains(parts[1]))
    }
}
