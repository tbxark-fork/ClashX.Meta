//
//  ProviderRowView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Column widths measured from the longest content; fixed spacing handled by HStack spacing
struct ProxyProviderColumnWidths {
	let index: CGFloat
	let first: CGFloat
	let second: CGFloat
	let third: CGFloat
	let fourth: CGFloat
	let fifth: CGFloat
	let typeIconWidth: CGFloat
	let thirdIconWidth: CGFloat

	static let columnSpacing: CGFloat = DashboardTheme.spacingColumn
	private static let badgeIconSpacing: CGFloat = 3

	init(providers: [DBProxyProvider]) {
		let fontSize: CGFloat = 12
		let typeTexts = providers.map { $0.vehicleType.rawValue }
		let qtyTexts = providers.map { String(format: NSLocalizedString("%lld nodes", comment: ""), $0.proxies.count) }
		let trafficTexts = providers.map(\.trafficInfo)
		let expireTexts = providers.map(\.expireDate)
		let updatedTexts = providers.map(\.updatedAt)

		typeIconWidth = TextMeasurement.iconWidth("internaldrive", fontSize: fontSize)
		thirdIconWidth = TextMeasurement.iconWidth("shippingbox", fontSize: fontSize)

		index = 30
		first = max(
			TextMeasurement.maxWidth(of: providers.map(\.name), font: DashboardTheme.primaryTextNSFont),
			TextMeasurement.maxWidth(of: trafficTexts, font: DashboardTheme.secondaryTextNSFont)
		)
		second = TextMeasurement.maxWidth(of: typeTexts, font: DashboardTheme.secondaryTextNSFont) + typeIconWidth + Self.badgeIconSpacing
		third = TextMeasurement.maxWidth(of: qtyTexts, font: DashboardTheme.secondaryTextNSFont) + thirdIconWidth + Self.badgeIconSpacing
		fourth = TextMeasurement.maxWidth(of: expireTexts, font: DashboardTheme.secondaryTextNSFont)
		fifth = TextMeasurement.maxWidth(of: updatedTexts, font: DashboardTheme.secondaryTextNSFont)
	}
}

struct ProviderRowView: View {
	let index: Int
	let columnWidths: ProxyProviderColumnWidths
	@ObservedObject var proxyProvider: DBProxyProvider

	@EnvironmentObject var hideProxyNames: HideProxyNames

	@State private var isHovered = false
	@State private var isUpdating = false

	var body: some View {
		HStack(spacing: 0) {
			NavigationLink {
				ProviderProxiesView(provider: proxyProvider)
			} label: {
				rowContent
			}
			.buttonStyle(.plain)
			.frame(maxWidth: .infinity, alignment: .leading)

			Button {
				Task { await update() }
			} label: {
				Group {
					if isUpdating {
						ProgressView()
							.controlSize(.small)
					} else {
						Image(systemName: "arrow.clockwise")
					}
				}
				.foregroundColor(.secondary)
				.frame(minWidth: 32, minHeight: 28)
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.disabled(isUpdating)
		}
		.padding(.horizontal, DashboardTheme.spacingRowH)
		.padding(.vertical, 10)
		.background(isHovered ? DashboardTheme.cellHoverBackground : Color.clear)
		.onHover { isHovered = $0 }
	}

	private var rowContent: some View {
		HStack(spacing: ProxyProviderColumnWidths.columnSpacing) {
			Text(verbatim: "\(index)")
				.font(DashboardTheme.secondaryTextFont.monospacedDigit())
				.foregroundColor(.secondary)
				.frame(width: columnWidths.index, alignment: .center)

			VStack(alignment: .leading, spacing: 3) {
				HStack(spacing: ProxyProviderColumnWidths.columnSpacing) {
					Text(hideProxyNames.hide ? String(proxyProvider.id.hiddenID) : proxyProvider.name)
						.font(DashboardTheme.primaryTextFont)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(width: columnWidths.first, alignment: .leading)
					badge(icon: "internaldrive", text: proxyProvider.vehicleType.rawValue, iconFrame: columnWidths.typeIconWidth)
						.lineLimit(1)
						.frame(width: columnWidths.second, alignment: .leading)
					badge(icon: "shippingbox", text: String(format: NSLocalizedString("%lld nodes", comment: ""), proxyProvider.proxies.count), iconFrame: columnWidths.thirdIconWidth)
						.lineLimit(1)
						.frame(width: columnWidths.third, alignment: .leading)
				}
				HStack(spacing: ProxyProviderColumnWidths.columnSpacing) {
					Text(verbatim: proxyProvider.trafficInfo)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(width: columnWidths.first, alignment: .leading)
					Text(proxyProvider.expireDate)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(width: columnWidths.fourth, alignment: .leading)
					Text(proxyProvider.updatedAt)
						.lineLimit(1)
						.truncationMode(.tail)
						.frame(width: columnWidths.fifth, alignment: .leading)
				}
				.font(DashboardTheme.secondaryTextFont)
				.foregroundColor(.secondary)
			}
		}
	}

	private func badge(icon: String, text: String, iconFrame: CGFloat) -> some View {
		HStack(spacing: 3) {
			Image(systemName: icon)
				.frame(width: iconFrame)
			Text(text)
		}
		.font(DashboardTheme.secondaryTextFont)
		.foregroundColor(.secondary)
	}

	@MainActor
	private func update() async {
		guard !isUpdating else { return }
		isUpdating = true
		defer { isUpdating = false }
		_ = await ApiRequest.updateProvider(for: .proxy, name: proxyProvider.name)
		NotificationCenter.default.post(name: .proxyProvidersUpdated, object: nil)
	}
}
