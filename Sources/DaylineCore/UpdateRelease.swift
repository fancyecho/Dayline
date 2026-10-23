import CryptoKit
import Foundation

/// GitHub Releases API 中 Dayline 更新需要的部分。
public struct UpdateRelease: Decodable, Sendable {
    /// 发布包和签名在 Release 附件里的固定文件名。
    public static let archiveName = "Dayline.zip"
    public static let signatureName = "Dayline.zip.sig"

    public struct Asset: Decodable, Sendable {
        public let name: String
        public let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let notes: String?
    public let pageURL: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case notes = "body"
        case pageURL = "html_url"
        case assets
    }

    public var version: AppVersion? { AppVersion(tagName) }

    public var archiveURL: URL? { assets.first { $0.name == Self.archiveName }?.downloadURL }
    public var signatureURL: URL? { assets.first { $0.name == Self.signatureName }?.downloadURL }
}

/// 更新包的 Ed25519 签名校验。私钥只在发布者本机，App 里只有公钥。
public enum UpdateSignature {
    public static func isValid(signature: Data, for archive: Data, publicKeyBase64: String) -> Bool {
        guard let keyData = Data(base64Encoded: publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        else { return false }
        return publicKey.isValidSignature(signature, for: archive)
    }

    /// 签名文件里是一行 Base64。
    public static func decode(signatureFile: Data) -> Data? {
        String(data: signatureFile, encoding: .utf8)
            .flatMap { Data(base64Encoded: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
}
