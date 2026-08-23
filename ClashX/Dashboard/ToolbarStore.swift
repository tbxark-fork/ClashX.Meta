//
//  ToolbarStore.swift
//  
//
//

import Foundation

@MainActor
final class ToolbarStore {
	static let shared = ToolbarStore()
	private init() {}

	var searchStrings = [String: String]()
}
