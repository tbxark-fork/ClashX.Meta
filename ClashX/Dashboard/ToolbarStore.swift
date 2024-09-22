//
//  ToolbarStore.swift
//  
//
//

import Cocoa

class ToolbarStore: NSObject {
	static let shared = ToolbarStore()
	
	private override init() {
		
	}
	
	var searchStrings = [String: String]()
}
