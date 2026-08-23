//
//  TrafficCardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

// Traffic chart card: title, legend, and Down/Up history charts
struct TrafficCardView: View {
	@EnvironmentObject var data: ClashOverviewData

	var body: some View {
		OverviewCard {
			VStack(alignment: .leading, spacing: 2) {
				Text("Traffic")
					.font(DashboardTheme.titleFont)

				legendItem(color: Color(nsColor: .systemBlue), name: "Down")
				TrafficGraphView(values: $data.downloadHistories,
								 graphColor: Color(nsColor: .systemBlue))

				legendItem(color: Color(nsColor: .systemGreen), name: "Up")
					.padding(.top, 16)
				TrafficGraphView(values: $data.uploadHistories,
								 graphColor: Color(nsColor: .systemGreen))
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}

	private func legendItem(color: Color, name: String) -> some View {
		HStack(spacing: DashboardTheme.spacingRowInner) {
			RoundedRectangle(cornerRadius: 2)
				.fill(color)
				.frame(width: 14, height: 9)
			Text(name)
				.font(DashboardTheme.secondaryTextFont)
				.foregroundColor(.secondary)
		}
	}
}
