//
//  MemoryCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Memory chart card: legend with current value above the history chart
struct MemoryCardView: View {
	@Environment(\.overviewDataRefs) private var refs

	private let color = DashboardTheme.chartPurple

	@State private var memoryHistories = [CGFloat]()
	@State private var memoryText = "0 MB"

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: 2) {
				HStack {
					legendItem(name: "Memory")
					Spacer()
					Text(verbatim: memoryText)
						.font(DashboardTheme.overviewLabelFont)
						.foregroundColor(.secondary)
						.monospacedDigit()
						.lineLimit(1)
						.minimumScaleFactor(0.7)
				}

				TrafficGraphView(values: $memoryHistories,
								 graphColor: color,
								 showYAxis: false,
								 graphType: .size)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.task(refreshLoop)
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			memoryHistories = refs.overview.memoryHistories
			memoryText = refs.overview.memory
			try? await Task.sleep(seconds: OverviewRefresh.chartInterval)
		}
	}

	private func legendItem(name: LocalizedStringKey) -> some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			RoundedRectangle(cornerRadius: 2)
				.fill(color)
				.frame(width: 14, height: 9)
			Text(name)
				.font(DashboardTheme.overviewLabelFont)
		}
	}
}
