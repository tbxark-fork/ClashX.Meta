//
//  DashboardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

struct DashboardView: View {
	static let minimumSize = CGSize(width: 920, height: 580)
	
	private let kernelStateChanged = NotificationCenter.default.publisher(for: .init("ClashKernelStateChanged"))
	@State private var kernelState = ConfigManager.shared.kernelState
	@State private var selection: SidebarItem? = .overview
	@StateObject private var clashApiDatasStorage = ClashApiDatasStorage()
	@StateObject private var toolbarState = DashboardToolbarState()
	@StateObject private var proxiesSearchString = ProxiesSearchString()
	@StateObject private var hideProxyNames = HideProxyNames()
	@StateObject private var providerStorage = DBProviderStorage()
	@State private var proxyContentSegment = ProxyContentSegment.proxyList
	@State private var ruleContentSegment = RuleContentSegment.ruleList
	@State private var isUpdatingRuleProviders = false
	@State private var isUpdatingProxyProviders = false
	
	var body: some View {
		NavigationSplitView {
			SidebarView(selection: $selection, clashApiDatasStorage: clashApiDatasStorage)
				.navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
		} detail: {
			detailView
		}
		.toolbar {
			toolbarItems
		}
		.environmentObject(clashApiDatasStorage.overviewData)
		.environmentObject(clashApiDatasStorage.logStorage)
		.environmentObject(clashApiDatasStorage.connsStorage)
		.environmentObject(toolbarState)
		.environmentObject(proxiesSearchString)
		.environmentObject(hideProxyNames)
		.environment(\.overviewDataRefs, OverviewDataRefs(
			overview: clashApiDatasStorage.overviewData,
			conns: clashApiDatasStorage.connsStorage))
		.environmentObject(providerStorage)
		.frame(
			minWidth: Self.minimumSize.width,
			idealWidth: Self.minimumSize.width,
			minHeight: Self.minimumSize.height,
			idealHeight: Self.minimumSize.height
		)
		.onReceive(kernelStateChanged) { _ in
			kernelState = ConfigManager.shared.kernelState
		}
		.onChange(of: selection) { newValue in
			guard let newValue else { return }
			if newValue != .logs {
				toolbarState.logFilter = .all
			}
			if newValue == .proxies {
				proxyContentSegment = .proxyList
			} else if newValue == .rules {
				ruleContentSegment = .ruleList
			}
		}
		.onChange(of: toolbarState.searchText) { newValue in
			proxiesSearchString.string = newValue
		}
		.onChange(of: toolbarState.hideProxyNames) { newValue in
			hideProxyNames.hide = newValue
		}
	}
	
	@ToolbarContentBuilder
	private var toolbarItems: some ToolbarContent {
		if selection == .proxies {
			ToolbarItem(placement: .navigation) {
				Picker("", selection: $proxyContentSegment) {
					ForEach(ProxyContentSegment.allCases) { segment in
						Text(segment.rawValue).tag(segment)
					}
				}
				.pickerStyle(.segmented)
			}
		}
		if selection == .rules {
			ToolbarItem(placement: .navigation) {
				Picker("", selection: $ruleContentSegment) {
					ForEach(RuleContentSegment.allCases) { segment in
						Text(segment.rawValue).tag(segment)
					}
				}
				.pickerStyle(.segmented)
			}
		}
		if let selection {
			toolbarButtons(for: selection)
		}
	}
	
	@ViewBuilder
	private func toolbarButtons(for selection: SidebarItem) -> some ToolbarContent {
		switch selection {
		case .overview, .config:
			ToolbarItem(placement: .automatic) { EmptyView() }
		case .proxies:
			if proxyContentSegment == .proxyProviders {
				ToolbarItem(placement: .automatic) {
					Button {
						Task { await updateAllProxyProviders() }
					} label: {
						if isUpdatingProxyProviders {
							ProgressView()
								.controlSize(.small)
						} else {
							Label("Update All", systemImage: "arrow.clockwise")
						}
					}
					.disabled(isUpdatingProxyProviders)
				}
			}
			ToolbarItem(placement: .automatic) {
				Toggle(isOn: Binding(
					get: { toolbarState.hideProxyNames },
					set: { newValue in
						toolbarState.hideProxyNames = newValue
					}
				)) {
					Label("Hide Names", systemImage: toolbarState.hideProxyNames ? "eyeglasses" : "wand.and.stars")
				}
				.toggleStyle(.button)
			}
			ToolbarItem(placement: .automatic) {
				TextField("Search", text: Binding(
					get: { toolbarState.searchText },
					set: { newValue in
						toolbarState.searchText = newValue
					}
				))
				.textFieldStyle(.roundedBorder)
				.frame(width: 220)
			}
		case .rules:
			if ruleContentSegment == .ruleProviders {
				ToolbarItem(placement: .automatic) {
					Button {
						Task { await updateAllRuleProviders() }
					} label: {
						if isUpdatingRuleProviders {
							ProgressView()
								.controlSize(.small)
						} else {
							Label("Update All", systemImage: "arrow.clockwise")
						}
					}
					.disabled(isUpdatingRuleProviders)
				}
			}
			ToolbarItem(placement: .automatic) {
				TextField("Search", text: Binding(
					get: { toolbarState.searchText },
					set: { newValue in
						toolbarState.searchText = newValue
					}
				))
				.textFieldStyle(.roundedBorder)
				.frame(width: 220)
			}
		case .conns:
			ToolbarItem(placement: .automatic) {
				Button {
					toolbarState.stopConns()
				} label: {
					Label("Stop All", systemImage: "stop.circle.fill")
				}
			}
			ToolbarItem(placement: .automatic) {
				TextField("Search", text: Binding(
					get: { toolbarState.searchText },
					set: { newValue in
						toolbarState.searchText = newValue
					}
				))
				.textFieldStyle(.roundedBorder)
				.frame(width: 220)
			}
		case .logs:
			ToolbarItem(placement: .automatic) {
				Picker("Log Filter", selection: Binding(
					get: { toolbarState.logFilter },
					set: { toolbarState.updateLogFilter($0) }
				)) {
					ForEach(DashboardToolbarState.LogFilter.allCases, id: \.self) { filter in
						Text(filter.rawValue).tag(filter)
					}
				}
				.pickerStyle(.menu)
			}
			ToolbarItem(placement: .automatic) {
				Picker("Log Level", selection: Binding(
					get: { toolbarState.logLevel },
					set: { toolbarState.updateLogLevel($0) }
				)) {
					ForEach([ClashLogLevel.silent, .error, .warning, .info, .debug], id: \.self) { level in
						Text(level.rawValue.capitalized).tag(level)
					}
				}
				.pickerStyle(.menu)
			}
			ToolbarItem(placement: .automatic) {
				TextField("Search", text: Binding(
					get: { toolbarState.searchText },
					set: { newValue in
						toolbarState.searchText = newValue
					}
				))
				.textFieldStyle(.roundedBorder)
				.frame(width: 220)
			}
		}
	}
	
	private func updateAllRuleProviders() async {
		guard !isUpdatingRuleProviders else { return }
		isUpdatingRuleProviders = true
		defer { isUpdatingRuleProviders = false }
		_ = await ApiRequest.updateAllProviders(for: .rule)
		NotificationCenter.default.post(name: .ruleProvidersUpdated, object: nil)
	}

	private func updateAllProxyProviders() async {
		guard !isUpdatingProxyProviders else { return }
		isUpdatingProxyProviders = true
		defer { isUpdatingProxyProviders = false }
		_ = await ApiRequest.updateAllProviders(for: .proxy)
		NotificationCenter.default.post(name: .proxyProvidersUpdated, object: nil)
	}

	@ViewBuilder
	private var detailView: some View {
		NavigationStack {
			switch selection {
			case .overview:
				OverviewView()
			case .proxies:
				switch proxyContentSegment {
				case .proxyList:
					ProxiesView()
				case .proxyProviders:
					ProvidersView(mode: .proxy)
				}
			case .rules:
				switch ruleContentSegment {
				case .ruleList:
					RulesView()
				case .ruleProviders:
					ProvidersView(mode: .rule)
				}
			case .conns:
				ConnectionsView()
			case .config:
				ConfigView()
			case .logs:
				LogsView()
			case .none:
				EmptyView()
			}
		}
	}
}

private enum ProxyContentSegment: String, CaseIterable, Identifiable {
	case proxyList = "代理"
	case proxyProviders = "提供商"

	var id: String { rawValue }
}

private enum RuleContentSegment: String, CaseIterable, Identifiable {
	case ruleList = "规则"
	case ruleProviders = "提供商"

	var id: String { rawValue }
}
