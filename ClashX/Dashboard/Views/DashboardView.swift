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
	@State private var proxyContentSegment = ProxyContentSegment.proxyList
	@State private var ruleContentSegment = RuleContentSegment.ruleList
	
	var body: some View {
		NavigationSplitView {
			SidebarView(selection: $selection, clashApiDatasStorage: clashApiDatasStorage)
				.navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 230)
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
		ToolbarItem(placement: .automatic) {
			if selection == nil {
				EmptyView()
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
		default:
			EmptyView()
		}
	}
	
	@ViewBuilder
	private var detailView: some View {
		switch selection {
		case .overview:
			OverviewView()
		case .proxies:
			DashboardPlaceholderView(title: proxyContentSegment.rawValue)
		case .rules:
			DashboardPlaceholderView(title: ruleContentSegment.rawValue)
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

private enum ProxyContentSegment: String, CaseIterable, Identifiable {
	case proxyList = "代理"
	case proxyProviders = "代理提供商"

	var id: String { rawValue }
}

private enum RuleContentSegment: String, CaseIterable, Identifiable {
	case ruleList = "规则"
	case ruleProviders = "规则提供商"

	var id: String { rawValue }
}

private struct DashboardPlaceholderView: View {
	let title: String

	var body: some View {
		ZStack {
			Color.clear
			Text(title)
				.font(.title2.weight(.semibold))
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
