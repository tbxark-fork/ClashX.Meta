//
//  MetaServer.swift
//  ClashX
//
//  Copyright © 2024 west2online. All rights reserved.
//

import Cocoa

struct MetaServer: Codable {
	var externalController: String
	let secret: String
	var log: String = ""
	
	func jsonString() -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted

		guard let data = try? encoder.encode(self),
			  let string = String(data: data, encoding: .utf8) else {
			return ""
		}
		return string
	}
}
