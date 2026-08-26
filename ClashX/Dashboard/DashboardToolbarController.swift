//
//  DashboardToolbarController.swift
//  ClashX Meta
//
//  AppKit-owned NSToolbar bridged to the SwiftUI dashboard through shared
//  ObservableObject state. Layout is fully deterministic across macOS 13+.
//  Structural patterns revived from the legacy pre-SwiftUI dashboard.
//

import Cocoa
import Combine

extension NSToolbarItem.Identifier {
	static let dashSegmentedProxies = NSToolbarItem.Identifier("DashSegmentedProxies")
	static let dashSegmentedRules = NSToolbarItem.Identifier("DashSegmentedRules")
	static let dashSegmentedConns = NSToolbarItem.Identifier("DashSegmentedConns")
	static let dashUpdateAllProxies = NSToolbarItem.Identifier("DashUpdateAllProxies")
	static let dashUpdateAllRules = NSToolbarItem.Identifier("DashUpdateAllRules")
	static let dashHideNames = NSToolbarItem.Identifier("DashHideNames")
	static let dashSearch = NSToolbarItem.Identifier("DashSearch")
	static let dashPauseRefresh = NSToolbarItem.Identifier("DashPauseRefresh")
	static let dashStopAll = NSToolbarItem.Identifier("DashStopAll")
	static let dashSourceIP = NSToolbarItem.Identifier("DashSourceIP")
	static let dashLogFilter = NSToolbarItem.Identifier("DashLogFilter")
	static let dashLogLevel = NSToolbarItem.Identifier("DashLogLevel")
}

@MainActor
final class DashboardToolbarController: NSObject {
	private let chromeState: DashboardChromeState
	private let toolbarState: DashboardToolbarState
	private let connsStorage: ClashConnsStorage

	private(set) var toolbar: NSToolbar!
	private weak var attachedWindow: NSWindow?

	private var cancellables = Set<AnyCancellable>()
	private var trampolines = [ActionTrampoline]()
	private var itemCache = [NSToolbarItem.Identifier: NSToolbarItem]()
	private var lastSourceIPs: [String] = []
	// Guards per-tick setLabel calls; conns streams publish far more often than counts change.
	private var lastSegmentCounts = (active: -1, closed: -1)
	private let logLevels: [ClashLogLevel] = [.silent, .error, .warning, .info, .debug]

	// MARK: - Init / Attach

	init(chromeState: DashboardChromeState,
	     toolbarState: DashboardToolbarState,
	     connsStorage: ClashConnsStorage) {
		self.chromeState = chromeState
		self.toolbarState = toolbarState
		self.connsStorage = connsStorage
		super.init()

		let tb = NSToolbar(identifier: "DashboardToolbar")
		tb.delegate = self
		tb.displayMode = .iconOnly
		toolbar = tb

		subscribe()
	}

	func attach(to window: NSWindow) {
		attachedWindow = window
		window.toolbar = toolbar
		syncItems()
	}

	// MARK: - Desired layout

	private func desiredIdentifiers() -> [NSToolbarItem.Identifier] {
		var ids: [NSToolbarItem.Identifier] = [.toggleSidebar, .sidebarTrackingSeparator]
		switch chromeState.selection {
		case .proxies:
			ids.append(contentsOf: [.dashSegmentedProxies, .flexibleSpace])
			if chromeState.proxyContentSegment == .proxyProviders { ids.append(.dashUpdateAllProxies) }
			ids.append(.dashHideNames)
		case .rules:
			ids.append(contentsOf: [.dashSegmentedRules, .flexibleSpace])
			if chromeState.ruleContentSegment == .ruleProviders { ids.append(.dashUpdateAllRules) }
		case .conns:
			ids.append(contentsOf: [.dashSegmentedConns, .flexibleSpace, .dashPauseRefresh, .dashStopAll])
			if !connsStorage.allSourceIPs.isEmpty { ids.append(.dashSourceIP) }
		case .logs:
			ids.append(contentsOf: [.dashLogFilter, .dashLogLevel])
		default:
			break
		}
		if needsSearch { ids.append(.dashSearch) }
		return ids
	}

	private var needsSearch: Bool {
		switch chromeState.selection {
		case .proxies, .rules, .conns, .logs:
			return true
		default:
			return false
		}
	}

	/// Incrementally reconcile visible items against the desired layout.
	/// Never tears down the whole bar: removes undesired items, inserts missing
	/// ones at their exact target index, keeping every untouched control alive.
	private func syncItems() {
		let desired = desiredIdentifiers()

		for (index, item) in toolbar.items.enumerated().reversed()
		where !desired.contains(item.itemIdentifier) {
			toolbar.removeItem(at: index)
		}

		for (targetIndex, id) in desired.enumerated() {
			let present = toolbar.items.contains { $0.itemIdentifier == id }
			guard !present else { continue }
			toolbar.insertItem(withItemIdentifier: id, at: min(targetIndex, toolbar.items.count))
		}

		if toolbar.items.map(\.itemIdentifier) != desired {
			// Defensive fallback (ordering drifted): rebuild once.
			while !toolbar.items.isEmpty {
				toolbar.removeItem(at: toolbar.items.count - 1)
			}
			for (index, id) in desired.enumerated() {
				toolbar.insertItem(withItemIdentifier: id, at: index)
			}
		}

		let targetTitleVisibility: NSWindow.TitleVisibility = chromeState.showsSegmentedToolbar ? .hidden : .visible
		if attachedWindow?.titleVisibility != targetTitleVisibility {
			attachedWindow?.titleVisibility = targetTitleVisibility
		}
	}

	// MARK: - Model -> Control subscriptions

	private func subscribe() {
		chromeState.$selection
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in self?.syncItems() }
			.store(in: &cancellables)

		chromeState.$proxyContentSegment
			.receive(on: DispatchQueue.main)
			.sink { [weak self] segment in
				guard let self else { return }
				if let seg = self.cachedControl(.dashSegmentedProxies) as? NSSegmentedControl {
					seg.selectedSegment = segment == .proxyList ? 0 : 1
				}
				self.syncItems()
			}
			.store(in: &cancellables)

		chromeState.$ruleContentSegment
			.receive(on: DispatchQueue.main)
			.sink { [weak self] segment in
				guard let self else { return }
				if let seg = self.cachedControl(.dashSegmentedRules) as? NSSegmentedControl {
					seg.selectedSegment = segment == .ruleList ? 0 : 1
				}
				self.syncItems()
			}
			.store(in: &cancellables)

		chromeState.$isUpdatingProxyProviders
			.receive(on: DispatchQueue.main)
			.sink { [weak self] updating in
				guard let self else { return }
				(self.cachedControl(.dashUpdateAllProxies) as? NSButton)?.isEnabled = !updating
			}
			.store(in: &cancellables)

		chromeState.$isUpdatingRuleProviders
			.receive(on: DispatchQueue.main)
			.sink { [weak self] updating in
				guard let self else { return }
				(self.cachedControl(.dashUpdateAllRules) as? NSButton)?.isEnabled = !updating
			}
			.store(in: &cancellables)

		toolbarState.$hideProxyNames
			.receive(on: DispatchQueue.main)
			.sink { [weak self] hidden in
				guard let self else { return }
				let item = self.itemCache[.dashHideNames]
				item?.image = NSImage(systemSymbolName: hidden ? "eyeglasses" : "wand.and.stars",
				                      accessibilityDescription: nil)
			}
			.store(in: &cancellables)

		toolbarState.$logFilter
			.receive(on: DispatchQueue.main)
			.sink { [weak self] filter in
				guard let self,
				      let group = self.itemCache[.dashLogFilter] as? NSToolbarItemGroup else { return }
				group.selectedIndex = DashboardToolbarState.LogFilter.allCases.firstIndex(of: filter) ?? 0
			}
			.store(in: &cancellables)

		toolbarState.$logLevel
			.receive(on: DispatchQueue.main)
			.sink { [weak self] level in
				guard let self,
				      let group = self.itemCache[.dashLogLevel] as? NSToolbarItemGroup,
				      let index = self.logLevels.firstIndex(of: level) else { return }
				group.selectedIndex = index
			}
			.store(in: &cancellables)

		toolbarState.$connShowClosed
			.receive(on: DispatchQueue.main)
			.sink { [weak self] showClosed in
				guard let self,
				      let seg = self.cachedControl(.dashSegmentedConns) as? NSSegmentedControl else { return }
				seg.selectedSegment = showClosed ? 1 : 0
			}
			.store(in: &cancellables)

		toolbarState.$connSourceIPFilter
			.receive(on: DispatchQueue.main)
			.sink { [weak self] ip in
				guard let self,
				      let popup = self.cachedControl(.dashSourceIP) as? NSPopUpButton else { return }
				if ip.isEmpty {
					popup.selectItem(at: 0)
				} else {
					popup.selectItem(withTitle: ip)
				}
			}
			.store(in: &cancellables)

		connsStorage.$isPaused
			.receive(on: DispatchQueue.main)
			.sink { [weak self] paused in
				guard let self else { return }
				let item = self.itemCache[.dashPauseRefresh]
				item?.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.circle",
				                      accessibilityDescription: nil)
			}
			.store(in: &cancellables)

		Publishers.CombineLatest(connsStorage.$conns, connsStorage.$closedConns)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				guard let self else { return }
				self.updateConnsSegmentLabels()
				let ips = self.connsStorage.allSourceIPs
				guard ips != self.lastSourceIPs else { return }
				let menuPresenceChanged = self.lastSourceIPs.isEmpty != ips.isEmpty
				self.lastSourceIPs = ips
				self.repopulateSourceIPMenu()
				if menuPresenceChanged { self.syncItems() }
			}
			.store(in: &cancellables)
	}

	// MARK: - Control helpers

	private func cachedControl(_ id: NSToolbarItem.Identifier) -> NSView? {
		itemCache[id]?.view
	}

	private func updateConnsSegmentLabels() {
		let counts = (active: connsStorage.conns.count, closed: connsStorage.closedConns.count)
		guard counts != lastSegmentCounts,
		      let seg = cachedControl(.dashSegmentedConns) as? NSSegmentedControl else { return }
		lastSegmentCounts = counts
		seg.setLabel("\(NSLocalizedString("Active", comment: "")) \(counts.active)", forSegment: 0)
		seg.setLabel("\(NSLocalizedString("Closed", comment: "")) \(counts.closed)", forSegment: 1)
	}

	private func repopulateSourceIPMenu() {
		guard let popup = cachedControl(.dashSourceIP) as? NSPopUpButton else { return }
		popup.removeAllItems()
		popup.addItem(withTitle: NSLocalizedString("All", comment: ""))
		for ip in connsStorage.allSourceIPs {
			popup.addItem(withTitle: ip)
		}
		if toolbarState.connSourceIPFilter.isEmpty {
			popup.selectItem(at: 0)
		} else {
			popup.selectItem(withTitle: toolbarState.connSourceIPFilter)
		}
	}

	// MARK: - Item builders

	private func makeTrampoline(_ handler: @escaping () -> Void) -> ActionTrampoline {
		let t = ActionTrampoline(handler)
		trampolines.append(t)
		return t
	}

	private func wrappedItem(id: NSToolbarItem.Identifier, label: String, view: NSView) -> NSToolbarItem {
		let item = NSToolbarItem(itemIdentifier: id)
		item.label = label
		item.paletteLabel = label
		item.view = view
		return item
	}

	private func item(for identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
		if let cached = itemCache[identifier] { return cached }

		let item: NSToolbarItem?
		switch identifier {
		case .dashSegmentedProxies:
			item = makeSegmentedItem(id: .dashSegmentedProxies,
			                         titles: ProxyContentSegment.allCases.map(\.title),
			                         selectedIndex: chromeState.proxyContentSegment == .proxyList ? 0 : 1) { [weak self] index in
				self?.chromeState.proxyContentSegment = index == 0 ? .proxyList : .proxyProviders
			}
		case .dashSegmentedRules:
			item = makeSegmentedItem(id: .dashSegmentedRules,
			                         titles: RuleContentSegment.allCases.map(\.title),
			                         selectedIndex: chromeState.ruleContentSegment == .ruleList ? 0 : 1) { [weak self] index in
				self?.chromeState.ruleContentSegment = index == 0 ? .ruleList : .ruleProviders
			}
		case .dashSegmentedConns:
			let seg = NSSegmentedControl(labels: [
				"\(NSLocalizedString("Active", comment: "")) \(connsStorage.conns.count)",
				"\(NSLocalizedString("Closed", comment: "")) \(connsStorage.closedConns.count)",
			], trackingMode: .selectOne, target: makeTrampoline { [weak self] in
				guard let self,
				      let seg = self.cachedControl(.dashSegmentedConns) as? NSSegmentedControl else { return }
				self.toolbarState.connShowClosed = seg.selectedSegment == 1
			}, action: #selector(ActionTrampoline.fire))
			seg.selectedSegment = toolbarState.connShowClosed ? 1 : 0
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Connections", comment: ""),
			                   view: seg)
		case .dashUpdateAllProxies:
			let trampoline = makeTrampoline { [weak self] in
				guard let self else { return }
				Task { await self.chromeState.updateAllProxyProviders() }
			}
			let button = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise",
			                                     accessibilityDescription: nil) ?? NSImage(),
			                      target: trampoline,
			                      action: #selector(ActionTrampoline.fire))
			button.isBordered = true
			button.bezelStyle = .texturedRounded
			button.isEnabled = !chromeState.isUpdatingProxyProviders
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Update All", comment: ""),
			                   view: button)
		case .dashUpdateAllRules:
			let trampoline = makeTrampoline { [weak self] in
				guard let self else { return }
				Task { await self.chromeState.updateAllRuleProviders() }
			}
			let button = NSButton(image: NSImage(systemSymbolName: "arrow.clockwise",
			                                     accessibilityDescription: nil) ?? NSImage(),
			                      target: trampoline,
			                      action: #selector(ActionTrampoline.fire))
			button.isBordered = true
			button.bezelStyle = .texturedRounded
			button.isEnabled = !chromeState.isUpdatingRuleProviders
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Update All", comment: ""),
			                   view: button)
		case .dashHideNames:
			let trampoline = makeTrampoline { [weak self] in
				guard let self else { return }
				self.toolbarState.hideNamesToggled()
			}
			let button = NSButton(image: NSImage(systemSymbolName: toolbarState.hideProxyNames ? "eyeglasses" : "wand.and.stars",
			                                     accessibilityDescription: nil) ?? NSImage(),
			                      target: trampoline,
			                      action: #selector(ActionTrampoline.fire))
			button.isBordered = true
			button.bezelStyle = .texturedRounded
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Hide Names", comment: ""),
			                   view: button)
		case .dashSearch:
			let searchItem = NSSearchToolbarItem(itemIdentifier: .dashSearch)
			searchItem.resignsFirstResponderWithCancel = true
			searchItem.searchField.delegate = self
			searchItem.searchField.stringValue = toolbarState.searchText
			searchItem.toolTip = NSLocalizedString("Search", comment: "")
			item = searchItem
		case .dashPauseRefresh:
			let trampoline = makeTrampoline { [weak self] in
				guard let self else { return }
				self.connsStorage.isPaused.toggle()
			}
			let button = NSButton(image: NSImage(systemSymbolName: connsStorage.isPaused ? "play.fill" : "pause.circle",
			                                     accessibilityDescription: nil) ?? NSImage(),
			                      target: trampoline,
			                      action: #selector(ActionTrampoline.fire))
			button.isBordered = true
			button.bezelStyle = .texturedRounded
			item = wrappedItem(id: identifier,
			                   label: connsStorage.isPaused
			                       ? NSLocalizedString("Resume Refresh", comment: "")
			                       : NSLocalizedString("Pause Refresh", comment: ""),
			                   view: button)
		case .dashStopAll:
			let trampoline = makeTrampoline { [weak self] in
				guard let self else { return }
				self.toolbarState.stopConns()
			}
			let button = NSButton(image: NSImage(systemSymbolName: "stop.circle.fill",
			                                     accessibilityDescription: nil) ?? NSImage(),
			                      target: trampoline,
			                      action: #selector(ActionTrampoline.fire))
			button.isBordered = true
			button.bezelStyle = .texturedRounded
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Stop All", comment: ""),
			                   view: button)
		case .dashSourceIP:
			let popup = NSPopUpButton(frame: .zero, pullsDown: false)
			popup.addItem(withTitle: NSLocalizedString("All", comment: ""))
			for ip in connsStorage.allSourceIPs {
				popup.addItem(withTitle: ip)
			}
			popup.target = makeTrampoline { [weak self] in
				guard let self,
				      let popup = self.cachedControl(.dashSourceIP) as? NSPopUpButton,
				      popup.indexOfSelectedItem >= 0 else { return }
				self.toolbarState.connSourceIPFilter = popup.indexOfSelectedItem == 0
					? ""
					: popup.itemTitles[popup.indexOfSelectedItem]
			}
			popup.action = #selector(ActionTrampoline.fire)
			if !toolbarState.connSourceIPFilter.isEmpty {
				popup.selectItem(withTitle: toolbarState.connSourceIPFilter)
			}
			item = wrappedItem(id: identifier,
			                   label: NSLocalizedString("Source IP", comment: ""),
			                   view: popup)
		case .dashLogFilter:
			let titles = DashboardToolbarState.LogFilter.allCases.map(\.rawValue)
			let group = NSToolbarItemGroup(itemIdentifier: identifier,
			                               titles: titles,
			                               selectionMode: .selectOne,
			                               labels: titles,
			                               target: makeTrampoline { [weak self] in
			                               	guard let self,
			                               	      let group = self.itemCache[.dashLogFilter] as? NSToolbarItemGroup,
			                               	      case let index = group.selectedIndex,
			                               	      index >= 0,
			                               	      index < DashboardToolbarState.LogFilter.allCases.count else { return }
			                               	self.toolbarState.updateLogFilter(DashboardToolbarState.LogFilter.allCases[index])
			                               },
			                               action: #selector(ActionTrampoline.fire))
			group.controlRepresentation = .collapsed
			group.selectedIndex = DashboardToolbarState.LogFilter.allCases.firstIndex(of: toolbarState.logFilter) ?? 0
			group.label = NSLocalizedString("Log Filter", comment: "")
			item = group
		case .dashLogLevel:
			let levels = logLevels
			let titles = levels.map { $0.rawValue.capitalized }
			let group = NSToolbarItemGroup(itemIdentifier: identifier,
			                               titles: titles,
			                               selectionMode: .selectOne,
			                               labels: titles,
			                               target: makeTrampoline { [weak self] in
			                               	guard let self,
			                               	      let group = self.itemCache[.dashLogLevel] as? NSToolbarItemGroup,
			                               	      case let index = group.selectedIndex,
			                               	      index >= 0,
			                               	      index < levels.count else { return }
			                               	self.toolbarState.updateLogLevel(levels[index])
			                               },
			                               action: #selector(ActionTrampoline.fire))
			group.controlRepresentation = .collapsed
			group.selectedIndex = levels.firstIndex(of: toolbarState.logLevel) ?? 1
			group.label = NSLocalizedString("Log Level", comment: "")
			item = group
		default:
			item = nil
		}
		if let item {
			itemCache[identifier] = item
		}
		return item
	}

	private func makeSegmentedItem(id: NSToolbarItem.Identifier,
	                               titles: [String],
	                               selectedIndex: Int,
	                               onSelect: @escaping (Int) -> Void) -> NSToolbarItem {
		let trampoline = makeTrampoline { [weak self] in
			guard let self, let seg = self.cachedControl(id) as? NSSegmentedControl else { return }
			onSelect(seg.selectedSegment)
		}
		let segment = NSSegmentedControl(labels: titles,
		                                 trackingMode: .selectOne,
		                                 target: trampoline,
		                                 action: #selector(ActionTrampoline.fire))
		segment.selectedSegment = selectedIndex
		return wrappedItem(id: id, label: titles.first ?? "", view: segment)
	}
}

// MARK: - NSToolbarDelegate

extension DashboardToolbarController: NSToolbarDelegate {
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		desiredIdentifiers()
	}

	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		[
			.toggleSidebar, .sidebarTrackingSeparator,
			.dashSegmentedProxies, .dashSegmentedRules, .dashSegmentedConns,
			.dashUpdateAllProxies, .dashUpdateAllRules, .dashHideNames, .dashSearch,
			.dashPauseRefresh, .dashStopAll, .dashSourceIP, .dashLogFilter, .dashLogLevel,
			.flexibleSpace, .space,
		]
	}

	func toolbar(_ toolbar: NSToolbar,
	             itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
	             willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		item(for: itemIdentifier)
	}
}

// MARK: - Search field live updates

extension DashboardToolbarController: NSSearchFieldDelegate {
	func controlTextDidChange(_ obj: Notification) {
		guard let field = obj.object as? NSSearchField else { return }
		toolbarState.searchText = field.stringValue
	}
}

// MARK: - Target/Action trampoline

@MainActor
private final class ActionTrampoline: NSObject {
	private let handler: () -> Void

	init(_ handler: @escaping () -> Void) {
		self.handler = handler
		super.init()
	}

	@objc func fire() {
		handler()
	}
}
