//
//  DashboardViewContoller.swift
//  ClashX
//
//  Created by yicheng on 2018/8/28.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import SwiftUI

public class DashboardWindowController: NSWindowController {
    private static let storyboardName = NSStoryboard.Name("Dashboard")

    public var onWindowClose: (() -> Void)?

	public static func create() -> DashboardWindowController {
		let controller = NSStoryboard(name: storyboardName, bundle: Bundle.main)
			.instantiateInitialController()

		guard let controller = controller as? DashboardWindowController else {
			fatalError("Failed to instantiate DashboardWindowController from Dashboard.storyboard")
		}

		return controller
    }

	public override func windowDidLoad() {
		super.windowDidLoad()

		guard let window else { return }
		window.delegate = self
		window.styleMask.insert(.fullSizeContentView)
		window.isOpaque = false
		window.title = "Dashboard"
	}

	public override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(self)
    }
	
	public func set(_ apiURL: String, secret: String? = nil) {
		ConfigManager.shared.overrideApiURL = .init(string: apiURL)
		ConfigManager.shared.overrideSecret = secret
	}
}

extension DashboardWindowController: NSWindowDelegate {
	public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        onWindowClose?()
    }
}

final class DashboardViewContoller: NSViewController {
	override func loadView() {
		view = NSHostingView(rootView: DashboardView())
    }

	override func viewWillAppear() {
		super.viewWillAppear()
		if NSApp.activationPolicy() == .accessory {
			NSApp.setActivationPolicy(.regular)
		}
	}

    deinit {
        NSApp.setActivationPolicy(.accessory)
    }
}
