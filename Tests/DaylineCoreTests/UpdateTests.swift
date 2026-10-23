import CryptoKit
import Foundation
import Testing
@testable import DaylineCore

@Suite struct AppVersionTests {
    @Test func parsesTagsAndPlainVersions() {
        #expect(AppVersion("v1.2.3")?.components == [1, 2, 3])
        #expect(AppVersion("1.0")?.description == "1.0")
        #expect(AppVersion("1.x") == nil)
        #expect(AppVersion("") == nil)
        #expect(AppVersion("1..2") == nil)
    }

    @Test func comparesNumerically() {
        #expect(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        #expect(AppVersion("v2.0")! > AppVersion("1.99")!)
        #expect(AppVersion("1.2")! == AppVersion("1.2.0")!)
        #expect(!(AppVersion("1.0.0")! > AppVersion("1.0.0")!))
    }
}

@Suite struct UpdateReleaseTests {
    @Test func decodesGitHubReleaseAndFindsAssets() throws {
        let json = """
        {
          "tag_name": "v1.0.1",
          "body": "修复问题",
          "html_url": "https://github.com/fancyecho/Dayline/releases/tag/v1.0.1",
          "assets": [
            {"name": "Dayline.zip.sig", "browser_download_url": "https://example.com/Dayline.zip.sig"},
            {"name": "Dayline.zip", "browser_download_url": "https://example.com/Dayline.zip"}
          ]
        }
        """
        let release = try JSONDecoder().decode(UpdateRelease.self, from: Data(json.utf8))
        #expect(release.version == AppVersion("1.0.1"))
        #expect(release.archiveURL?.lastPathComponent == "Dayline.zip")
        #expect(release.signatureURL?.lastPathComponent == "Dayline.zip.sig")
    }
}

@Suite struct UpdateSignatureTests {
    private let key = Curve25519.Signing.PrivateKey()
    private var publicKey: String { key.publicKey.rawRepresentation.base64EncodedString() }

    @Test func acceptsMatchingSignature() throws {
        let archive = Data("archive".utf8)
        let signatureFile = Data((try key.signature(for: archive).base64EncodedString() + "\n").utf8)
        let signature = try #require(UpdateSignature.decode(signatureFile: signatureFile))
        #expect(UpdateSignature.isValid(signature: signature, for: archive, publicKeyBase64: publicKey))
    }

    @Test func rejectsTamperedArchiveOrOtherKey() throws {
        let archive = Data("archive".utf8)
        let signature = try key.signature(for: archive)
        #expect(!UpdateSignature.isValid(signature: signature, for: Data("tampered".utf8), publicKeyBase64: publicKey))

        let otherKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        #expect(!UpdateSignature.isValid(signature: signature, for: archive, publicKeyBase64: otherKey))
        #expect(!UpdateSignature.isValid(signature: signature, for: archive, publicKeyBase64: "not base64"))
    }
}
