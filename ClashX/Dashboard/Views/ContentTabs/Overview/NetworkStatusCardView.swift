//
//  NetworkStatusCardView.swift
//  ClashX Dashboard
//
//

import AppKit
import SwiftUI

// System proxy, TUN, and HTTP proxy status; copies terminal proxy commands
struct NetworkStatusCardView: View {
	@State private var tunActive = false
	@State private var tunDevice = ""
	@State private var httpPort = 0
	@State private var socksPort = 0
	@State private var systemProxyActive = false
	@State private var systemProxySetByOther = false
	@State private var apiAddress = "—"
	@State private var copied = false
	@State private var apiCopied = false

	private let rowHeight: CGFloat = 24
	private let valueFont = Font.system(size: 16)

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: DashboardTheme.spacingRowInner) {
				Text("Network")
					.font(DashboardTheme.titleFont)
				infoRow(label: "Sys Proxy") {
					systemProxyValue
				}
				infoRow(label: "TUN",
						value: tunActive ? tunDevice : "Off",
						valueColor: tunActive ? nil : .secondary)
				httpRow
				apiRow
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.task(refreshLoop)
	}

	private func infoRow(label: LocalizedStringKey, value: String, valueColor: Color? = nil) -> some View {
		infoRow(label: label, valueColor: valueColor) {
			Text(verbatim: value)
				.font(valueFont)
				.foregroundColor(valueColor ?? .primary)
				.lineLimit(1)
				.minimumScaleFactor(0.6)
		}
	}

	private func infoRow(label: LocalizedStringKey, valueColor: Color? = nil, @ViewBuilder value: () -> some View) -> some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			Text(label)
				.font(DashboardTheme.overviewLabelFont)
				.foregroundColor(.secondary)
				.frame(width: 90, alignment: .leading)
			value()
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.frame(height: rowHeight)
	}

	@ViewBuilder
	private var systemProxyValue: some View {
		CheckboxView(state: systemProxyCheckboxState)
			.allowsHitTesting(false)
	}

	private var systemProxyCheckboxState: NSControl.StateValue {
		if systemProxySetByOther { return .mixed }
		return systemProxyActive ? .on : .off
	}

	private var httpRow: some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			Text("HTTP(S)")
				.font(DashboardTheme.overviewLabelFont)
				.foregroundColor(.secondary)
				.frame(width: 90, alignment: .leading)
			Text(verbatim: httpPort > 0 ? "\(httpPort)" : "—")
				.font(valueFont)
				.monospacedDigit()
				.lineLimit(1)
			Spacer()
			copyButton(isCopied: copied) {
				copyProxyCommand()
			}
			.help("Copy terminal proxy command")
		}
		.frame(height: rowHeight)
	}

	private var apiRow: some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			Text("API")
				.font(DashboardTheme.overviewLabelFont)
				.foregroundColor(.secondary)
				.frame(width: 90, alignment: .leading)
			Text(verbatim: apiAddress)
				.font(valueFont)
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			Spacer()
			copyButton(isCopied: apiCopied) {
				copyAPILink()
			}
			.help("Copy API address")
		}
		.frame(height: rowHeight)
	}

	private func copyButton(isCopied: Bool, action: @escaping () -> Void) -> some View {
		Button {
			action()
		} label: {
			Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
				.font(.system(size: 13))
				.foregroundColor(isCopied ? .green : .secondary)
		}
		.buttonStyle(.plain)
		.contentShape(Rectangle())
	}

	private func copyAPILink() {
		guard apiAddress != "—" else { return }
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(apiAddress, forType: .string)
		apiCopied = true
		Task {
			try? await Task.sleep(seconds: 1.2)
			apiCopied = false
		}
	}

	private func copyProxyCommand() {
		guard httpPort > 0 else { return }
		let base = "http://127.0.0.1:\(httpPort)"
		var parts = ["export https_proxy=\(base)", "http_proxy=\(base)"]
		if socksPort > 0 {
			parts.append("all_proxy=socks5://127.0.0.1:\(socksPort)")
		}
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(parts.joined(separator: " "), forType: .string)
		copied = true
		Task {
			try? await Task.sleep(seconds: 1.2)
			copied = false
		}
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			await refresh()
			try? await Task.sleep(seconds: OverviewRefresh.polledInterval)
		}
	}

	private func refresh() async {
		let config = await ApiRequest.requestConfig()
		tunDevice = config?.tun.device ?? ""
		httpPort = config?.usedHttpPort ?? 0
		socksPort = config?.usedSocksPort ?? 0
		tunActive = ProxyManager.shared.runtimeTunActive
		let runtime = ProxyManager.shared.state.runtime
		systemProxySetByOther = runtime.systemProxySetByOther
		systemProxyActive = runtime.systemProxyActive
		apiAddress = ConfigManager.apiUrl
	}
}

private struct CheckboxView: NSViewRepresentable {
	let state: NSControl.StateValue

	func makeNSView(context: Context) -> NSButton {
		NSButton(checkboxWithTitle: "", target: nil, action: nil)
	}

	func updateNSView(_ checkbox: NSButton, context: Context) {
		checkbox.state = state
	}
}
