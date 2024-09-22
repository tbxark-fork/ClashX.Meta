//
//  DashboardManagerSwiftUI.swift
//  ClashX Meta
//
//  Copyright © 2023 west2online. All rights reserved.
//

import Cocoa
import RxSwift


class DashboardManager: NSObject {
	
	static let shared = DashboardManager()
	
	override init() {
	}
	
	var useSwiftUI: Bool {
		get {
			return ConfigManager.useSwiftUIDashboard
		}
		set {
			ConfigManager.useSwiftUIDashboard = newValue
			
			if newValue {
				clashWebWindowController?.close()
			} else {
				deinitNotifications()
				dashboardWindowController?.close()
			}
		}
	}
	var dashboardWindowController: DashboardWindowController?
	
	private var disposables = [Disposable]()
	
	
	var clashWebWindowController: ClashWebViewWindowController?

	func show(_ sender: NSMenuItem?) {
		initNotifications()
		
		if useSwiftUI {
			clashWebWindowController = nil
			showSwiftUIWindow(sender)
		} else {
			dashboardWindowController = nil
			showWebWindow(sender)
		}
	}
	
	func showWebWindow(_ sender: NSMenuItem?) {
		if clashWebWindowController == nil {
			clashWebWindowController = ClashWebViewWindowController.create()
			clashWebWindowController?.onWindowClose = {
				[weak self] in
				self?.clashWebWindowController = nil
			}
		}
		clashWebWindowController?.showWindow(sender)
	}
	
	func deinitNotifications() {
		disposables.forEach {
			$0.dispose()
		}
		disposables.removeAll()
	}
	
	deinit {
		deinitNotifications()
	}
}

extension DashboardManager {
	func showSwiftUIWindow(_ sender: NSMenuItem?) {
		if dashboardWindowController == nil {
			dashboardWindowController = DashboardWindowController.create()
			dashboardWindowController?.onWindowClose = {
				[weak self] in
				self?.dashboardWindowController = nil
			}
		}
		
		dashboardWindowController?.set(ConfigManager.apiUrl, secret: ConfigManager.shared.overrideSecret ?? ConfigManager.shared.apiSecret)
		
		dashboardWindowController?.showWindow(sender)
	}
	
	func initNotifications() {
		guard useSwiftUI, disposables.count == 0 else { return }
		
		let n1 = NotificationCenter.default.rx.notification(.configFileChange).subscribe {
			[weak self] _ in
			self?.dashboardWindowController?.reload()
		}

		let n2 = NotificationCenter.default.rx.notification(.reloadDashboard).subscribe {
			[weak self] _ in
			self?.dashboardWindowController?.reload()
		}
		disposables.append(n1)
		disposables.append(n2)
	}
	
}
