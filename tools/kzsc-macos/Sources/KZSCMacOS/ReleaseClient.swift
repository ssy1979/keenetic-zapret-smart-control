import Foundation
import CryptoKit

struct ReleaseClient: Sendable {
    struct Release { let tag: String; let archive: URL; let checksum: URL }
    enum Error: LocalizedError { case invalidRelease, missingAssets, checksumMismatch, http(Int)
        var errorDescription: String? { switch self { case .invalidRelease: return "Unexpected KZSC release tag"; case .missingAssets: return "Release archive or checksum is missing"; case .checksumMismatch: return "Release SHA-256 mismatch"; case .http(let code): return "GitHub HTTP status \(code)" } }
    }
    private let endpoint = URL(string: "https://api.github.com/repos/ssy1979/keenetic-zapret-smart-control/releases/latest")!

    func latest() async throws -> Release {
        var request = URLRequest(url: endpoint); request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Error.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let tag = json["tag_name"] as? String, tag.range(of: #"^v0\.11\.2\.[0-9]+-generic$"#, options: .regularExpression) != nil else { throw Error.invalidRelease }
        let assets = (json["assets"] as? [[String: Any]]) ?? []
        let archive = assets.first { ($0["name"] as? String) == "keenetic-zapret-smart-control-\(tag).tar.gz" }?["browser_download_url"] as? String
        let checksum = assets.first { ($0["name"] as? String) == "keenetic-zapret-smart-control-\(tag).tar.gz.sha256" }?["browser_download_url"] as? String
        guard let a = archive.flatMap(URL.init(string:)), let c = checksum.flatMap(URL.init(string:)), a.host == "github.com", c.host == "github.com" else { throw Error.missingAssets }
        return Release(tag: tag, archive: a, checksum: c)
    }

    func downloadAndVerify(_ release: Release, directory: URL) async throws -> URL {
        let (archiveData, archiveResponse) = try await URLSession.shared.data(from: release.archive)
        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: release.checksum)
        guard let archiveHTTP = archiveResponse as? HTTPURLResponse,
              let checksumHTTP = checksumResponse as? HTTPURLResponse,
              (200..<300).contains(archiveHTTP.statusCode),
              (200..<300).contains(checksumHTTP.statusCode) else {
            throw Error.http((archiveResponse as? HTTPURLResponse)?.statusCode ?? (checksumResponse as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let expected = String(decoding: checksumData, as: UTF8.self).split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).first.map(String.init) ?? ""
        let actual = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
        guard expected.count == 64, expected.lowercased() == actual else { throw Error.checksumMismatch }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("keenetic-zapret-smart-control-\(release.tag).tar.gz")
        try archiveData.write(to: destination, options: .atomic)
        return destination
    }
}
