//
//  TrafficCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Traffic chart card: title, legend, and Down/Up history charts
struct TrafficCardView: View {
	@Environment(\.overviewDataRefs) private var refs

	@State private var downloadHistories = [CGFloat]()
	@State private var uploadHistories = [CGFloat]()

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: 2) {
				Text("Traffic")
					.font(DashboardTheme.titleFont)

				legendItem(color: DashboardTheme.chartBlue, name: "Down")
				TrafficGraphView(values: $downloadHistories,
								 graphColor: DashboardTheme.chartBlue)

				legendItem(color: DashboardTheme.chartGreen, name: "Up")
					.padding(.top, 16)
				TrafficGraphView(values: $uploadHistories,
								 graphColor: DashboardTheme.chartGreen)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
		.task(refreshLoop)
	}

	private func refreshLoop() async {
		while !Task.isCancelled {
			downloadHistories = refs.overview.downloadHistories
			uploadHistories = refs.overview.uploadHistories
			try? await Task.sleep(seconds: OverviewRefresh.chartInterval)
		}
	}

	private func legendItem(color: Color, name: LocalizedStringKey) -> some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			RoundedRectangle(cornerRadius: 2)
				.fill(color)
				.frame(width: 14, height: 9)
			Text(name)
				.font(DashboardTheme.overviewLabelFont)
				.foregroundColor(.secondary)
		}
	}
}
