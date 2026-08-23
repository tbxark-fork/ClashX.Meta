//
//  SubscriptionUsageCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Subscription usage of the provider owning PROXY's current node
struct SubscriptionUsageCardView: View {
	@State private var display: Display?

	struct Display: Equatable {
		let totalText: String
		let ratio: CGFloat
		let percentText: String
		let helpText: String
	}

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: DashboardTheme.spacingOverviewStatText) {
				HStack(spacing: DashboardTheme.spacingRowInner) {
					Text("Subscription Usage")
						.font(DashboardTheme.overviewLabelFont)
						.foregroundColor(.secondary)
						.lineLimit(1)
					Text(verbatim: display?.totalText ?? "—")
						.font(DashboardTheme.overviewLabelFont)
						.monospacedDigit()
						.lineLimit(1)
				}
				if display != nil {
					HStack(spacing: DashboardTheme.spacingRowInner) {
					Gauge(value: display?.ratio ?? 0) { }
						.gaugeStyle(UsageGaugeStyle(
							height: 4.5,
							trackColor: DashboardTheme.cellBackground,
							fillColor: Color.accentColor))
						.accessibilityLabel(Text(verbatim:
							[display?.percentText, display?.helpText].compactMap { $0 }.joined(separator: ", ")))
						Text(verbatim: display?.percentText ?? "—")
							.font(DashboardTheme.overviewValueFont)
							.monospacedDigit()
							.lineLimit(1)
							.layoutPriority(1)
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.help(display?.helpText ?? "")
		.task(refreshLoop)
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			await refresh()
			try? await Task.sleep(seconds: OverviewRefresh.polledInterval)
		}
	}

	private func refresh() async {
		let proxies = await ApiRequest.requestProxyGroupList()
		let providers = await ApiRequest.requestProxyProviderList()
		let newDisplay = Self.resolve(proxies: proxies, providers: providers)
		if newDisplay != display {
			display = newDisplay
		}
	}

	static func resolve(proxies: ClashProxyResp, providers: ClashProviderResp) -> Display? {
		guard var name = proxies.proxiesMap["PROXY"]?.now else { return nil }
		var visited: Set<ClashProxyName> = [name]
		for _ in 0..<8 {
			guard let node = proxies.proxiesMap[name],
			      let next = node.now,
			      !visited.contains(next) else { break }
			visited.insert(next)
			name = next
		}
		guard let provider = providers.allProviders.values.first(where: {
			$0.type == .Proxy && $0.vehicleType == .HTTP && $0.proxies.contains { $0.name == name }
		}) else { return nil }

		// mihomo passes through unparsable or negative userinfo values, reject non-standard data
		guard let info = provider.subscriptionInfo,
		      info.upload >= 0,
		      info.download >= 0,
		      info.total > 0 else { return nil }
		let used = info.upload + info.download
		guard used >= 0 else { return nil }

		let ratio = min(CGFloat(used) / CGFloat(info.total), 1)
		let percent = Int((Double(used) / Double(info.total) * 100).rounded())
		let formatter = DashboardFormatters.byteCount
		let totalText = formatter.string(fromByteCount: info.total)
		let usedText = formatter.string(fromByteCount: used)

		var helpParts: [String] = ["\(usedText) / \(totalText)"]
		if info.expire > 0 {
			let date = Date(timeIntervalSince1970: TimeInterval(info.expire)).formatted(date: .abbreviated, time: .omitted)
			helpParts.append(String(format: NSLocalizedString("Expire: %@", comment: ""), date))
		} else {
			helpParts.append(String(format: NSLocalizedString("Expire: %@", comment: ""), NSLocalizedString("none", comment: "")))
		}

		return Display(
			totalText: totalText,
			ratio: ratio,
			percentText: String(format: "%d%%", percent),
			helpText: helpParts.joined(separator: " · ")
		)
	}
}

// Custom capacity style: pure SwiftUI drawing, avoids the NSProgressIndicator
// tint recursion crash on newer macOS with dynamic tint colors.
private struct UsageGaugeStyle: GaugeStyle {
	let height: CGFloat
	let trackColor: Color
	let fillColor: Color

	func makeBody(configuration: Configuration) -> some View {
		GeometryReader { proxy in
			ZStack(alignment: .leading) {
				Capsule().fill(trackColor)
				Capsule()
					.fill(fillColor)
					.frame(width: proxy.size.width * CGFloat(configuration.value))
			}
		}
		.frame(height: height)
	}
}
