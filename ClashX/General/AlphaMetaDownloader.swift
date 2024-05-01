//
//  AlphaMetaDownloader.swift
//  ClashX Meta
//
//  Copyright © 2023 west2online. All rights reserved.
//

import Cocoa
import Alamofire
import PromiseKit

class AlphaMetaDownloader: NSObject {

	enum errors: Error {
		case decodeReleaseInfoFailed
		case notFoundUpdate
		case downloadFailed
		case unknownError
		case testFailed

		func des() -> String {
			switch self {
			case .decodeReleaseInfoFailed:
				return "Decode alpha release info failed"
			case .notFoundUpdate:
				return "Not found update"
			case .downloadFailed:
				return "Download failed"
			case .testFailed:
				return "Test downloaded file failed"
			case .unknownError:
				return "Unknown error"
			}
		}
	}

	struct ReleasesResp: Decodable {
		let assets: [Asset]
		struct Asset: Decodable {
			let name: String
			let downloadUrl: String
			let contentType: String
			let state: String

			enum CodingKeys: String, CodingKey {
				case name,
					 state,
					 downloadUrl = "browser_download_url",
					 contentType = "content_type"
			}
		}
	}

	static func assetName() -> String? {
		switch GetMachineHardwareName() {
		case "x86_64":
			return "darwin-amd64"
		case "arm64":
			return "darwin-arm64"
		default:
			return nil
		}
	}

	static func GetMachineHardwareName() -> String? {
		var sysInfo = utsname()
		let retVal = uname(&sysInfo)

		guard retVal == EXIT_SUCCESS else { return nil }

		let machineMirror = Mirror(reflecting: sysInfo.machine)
		let identifier = machineMirror.children.reduce("") { identifier, element in
			guard let value = element.value as? Int8, value != 0 else { return identifier }
			return identifier + String(UnicodeScalar(UInt8(value)))
		}
		return identifier
	}

	static func alphaAsset() -> Promise<ReleasesResp.Asset> {
		Promise { resolver in
			let assetName = assetName()
			AF.request("https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/Prerelease-Alpha").responseDecodable(of: ReleasesResp.self) {
				guard let assets = $0.value?.assets else {
					resolver.reject(errors.downloadFailed)
					return
				}
				
				guard let assetName,
					  let asset = assets.first(where: {
						  $0.name.contains(assetName) &&
						  !$0.name.contains("cgo") &&
						  !$0.name.contains("go120") &&
						  $0.state == "uploaded" &&
						  $0.contentType == "application/gzip"
					  }) else {
					resolver.reject(errors.decodeReleaseInfoFailed)
					return
				}
				resolver.fulfill(asset)
			}
		}
	}

	static func checkVersion(_ asset: ReleasesResp.Asset) -> Promise<ReleasesResp.Asset> {
		Promise { resolver in
			guard let path = Paths.alphaCorePath()?.path,
				  let ad = NSApplication.shared.delegate as? AppDelegate else {
				resolver.reject(errors.unknownError)
				return
			}
			if let v = ad.clashProcess.verifyCoreFile(path),
			   asset.name.contains(v.version) {
				resolver.reject(errors.notFoundUpdate)
			}
			resolver.fulfill(asset)
		}
	}

	static func downloadCore(_ asset: ReleasesResp.Asset) -> Promise<Data> {
		Promise { resolver in
			let fm = FileManager.default
			AF.download(asset.downloadUrl).response {
				guard let gzPath = $0.fileURL?.path,
					  let contentData = fm.contents(atPath: gzPath)
				else {
					resolver.reject(errors.downloadFailed)
					return
				}
				resolver.fulfill(contentData)
			}
		}
	}

	static func replaceCore(_ gzData: Data) -> Promise<String> {
		Promise { resolver in
			let fm = FileManager.default

			guard let helperURL = Paths.alphaCorePath(),
				  let ad = NSApplication.shared.delegate as? AppDelegate else {
				resolver.reject(errors.unknownError)
				return
			}

			try fm.createDirectory(at: helperURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

			let cachePath = Paths.tempPath().appending("/\(UUID().uuidString).newcore")
			try gzData.gunzipped().write(to: .init(fileURLWithPath: cachePath))
			
			Logger.log("save alpha core in \(cachePath)")

			guard let version = ad.clashProcess.verifyCoreFile(cachePath)?.version else {
				resolver.reject(errors.testFailed)
				return
			}

			try? fm.removeItem(at: helperURL)
			try fm.moveItem(atPath: cachePath, toPath: helperURL.path)

			resolver.fulfill(version)
		}
	}
}
