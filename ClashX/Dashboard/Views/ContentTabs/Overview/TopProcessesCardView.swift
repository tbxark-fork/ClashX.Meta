//
//  TopProcessesCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Per-app traffic ranking aggregated from the live connection list
struct TopProcessesCardView: View {
	@Environment(\.overviewDataRefs) private var refs

	@State private var topApps: [TopApp] = []

	private struct TopApp: Identifiable {
		let name: String
		let bytes: Int64
		let ratio: CGFloat

		var id: String { name }
	}

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: DashboardTheme.spacingRowInner) {
				Text("Top Processes")
					.font(DashboardTheme.titleFont)
				ForEach(topApps) { app in
					rowView(app)
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.task(refreshLoop)
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			await updateTopApps()
			try? await Task.sleep(seconds: OverviewRefresh.polledInterval)
		}
	}

	private func updateTopApps() async {
		var totals: [String: Int64] = [:]
		for conn in refs.conns.conns {
			guard conn.metadata.type != "Inner", !conn.chains.contains("DIRECT") else { continue }
			let name = await refs.conns.appName(
				processPath: conn.metadata.processPath,
				process: conn.metadata.process)
			totals[name, default: 0] += conn.upload + conn.download
		}
		let sorted = totals.sorted { $0.value > $1.value }.prefix(5)
		guard let maxBytes = sorted.first?.value, maxBytes > 0 else {
			topApps = []
			return
		}
		topApps = sorted.map { TopApp(name: $0.key, bytes: $0.value, ratio: CGFloat($0.value) / CGFloat(maxBytes)) }
	}

	private func rowView(_ app: TopApp) -> some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			Text(verbatim: app.name)
				.font(DashboardTheme.overviewLabelFont)
				.lineLimit(1)
				.frame(maxWidth: .infinity, alignment: .leading)
			GeometryReader { proxy in
				Capsule()
					.fill(DashboardTheme.usageBarFill)
					.frame(width: proxy.size.width * app.ratio, height: 4)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.frame(width: 90, height: 4)
			Text(verbatim: DashboardFormatters.byteCount.string(fromByteCount: app.bytes))
				.font(DashboardTheme.overviewLabelFont)
				.foregroundColor(.secondary)
				.monospacedDigit()
				.lineLimit(1)
				.frame(width: 60, alignment: .trailing)
		}
	}
}
