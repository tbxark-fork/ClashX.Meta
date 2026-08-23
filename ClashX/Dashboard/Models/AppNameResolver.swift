//
//  AppNameResolver.swift
//  ClashX Dashboard
//
//

import Foundation

// Maps process paths to host app display names; outermost .app wins so
// helper processes merge into their host app; unbundled processes fall
// back to their executable name as standalone entries
actor AppNameResolver {
	// processPath -> display name; bounded by live process count
	private var cache: [String: String] = [:]

	func appName(processPath: String, process: String) -> String {
		if let hit = cache[processPath] { return hit }
		let name = resolve(processPath: processPath, process: process)
		cache[processPath] = name
		return name
	}

	private func resolve(processPath: String, process: String) -> String {
		var dir = ""
		for part in processPath.split(separator: "/") {
			dir += "/" + part
			if part.hasSuffix(".app"), FileManager.default.fileExists(atPath: dir) {
				return String(part.dropLast(4))
			}
		}
		return process.isEmpty ? "Unknown" : process
	}
}
