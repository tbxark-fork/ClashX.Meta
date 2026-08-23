//
//  ConnectionsStatsCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Protocol split card: TCP vs UDP counts from the live connection list
struct ConnectionsStatsCardView: View {
	@Environment(\.overviewDataRefs) private var refs

	@State private var totalCount = 0
	@State private var statsString = "TCP 0 · UDP 0"

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: DashboardTheme.spacingOverviewStatText) {
				HStack(spacing: DashboardTheme.spacingRowInner) {
					Text("Connections")
						.font(DashboardTheme.overviewLabelFont)
						.foregroundColor(.secondary)
						.lineLimit(1)
					Text(verbatim: "\(totalCount)")
						.font(DashboardTheme.overviewLabelFont)
						.monospacedDigit()
						.lineLimit(1)
				}
				Text(verbatim: statsString)
					.font(DashboardTheme.overviewValueFont)
					.lineLimit(1)
					.minimumScaleFactor(0.6)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
		}
		.task(refreshLoop)
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			update()
			try? await Task.sleep(seconds: OverviewRefresh.polledInterval)
		}
	}

	private func update() {
		let conns = refs.conns.conns
		let tcp = conns.filter { $0.metadata.network.lowercased() == "tcp" }.count
		let newTotal = conns.count
		let newStats = "TCP \(tcp) · UDP \(newTotal - tcp)"
		if newTotal != totalCount {
			totalCount = newTotal
		}
		if newStats != statsString {
			statsString = newStats
		}
	}
}
