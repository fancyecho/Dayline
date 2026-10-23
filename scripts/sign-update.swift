// 管理更新签名密钥并给发布包签名（Ed25519，CryptoKit）。
//
//   swift scripts/sign-update.swift generate          生成私钥（已存在则不覆盖）并打印公钥
//   swift scripts/sign-update.swift public-key        打印公钥，写进 Updater.swift
//   swift scripts/sign-update.swift sign <文件>       打印该文件的 Base64 签名
//
// 私钥默认存放在 ~/.config/dayline/update-signing-key，可用 DAYLINE_SIGNING_KEY 指定别的路径。
// 私钥不要提交到仓库，并务必备份：丢失后，已安装的 App 将无法通过自动更新升级。
import CryptoKit
import Foundation

let keyURL = ProcessInfo.processInfo.environment["DAYLINE_SIGNING_KEY"].map(URL.init(fileURLWithPath:))
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/dayline/update-signing-key")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func loadKey() -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOf: keyURL, encoding: .utf8),
          let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
    else { fail("读不到私钥：\(keyURL.path)。先运行 generate。") }
    return key
}

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "generate":
    if FileManager.default.fileExists(atPath: keyURL.path) {
        fail("私钥已存在：\(keyURL.path)，不会覆盖。")
    }
    let key = Curve25519.Signing.PrivateKey()
    try FileManager.default.createDirectory(
        at: keyURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    FileManager.default.createFile(
        atPath: keyURL.path,
        contents: Data(key.rawRepresentation.base64EncodedString().utf8),
        attributes: [.posixPermissions: 0o600]
    )
    print(key.publicKey.rawRepresentation.base64EncodedString())

case "public-key":
    print(loadKey().publicKey.rawRepresentation.base64EncodedString())

case "sign":
    guard let path = arguments.dropFirst().first,
          let data = FileManager.default.contents(atPath: path)
    else { fail("用法：sign <文件>") }
    print(try loadKey().signature(for: data).base64EncodedString())

default:
    fail("用法：generate | public-key | sign <文件>")
}
