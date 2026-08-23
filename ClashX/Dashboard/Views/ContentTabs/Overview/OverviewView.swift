//
//  OverviewView.swift
//  ClashX Dashboard
//
//

import SwiftUI

struct OverviewView: View {
	
	@EnvironmentObject var data: ClashOverviewData
	
	@State private var version: String = ""
	
    var body: some View {
		ScrollView {
			OverviewGrid {
				OverviewHeroItemView(name: "Upload", value: data.uploadString, color: Color(nsColor: .systemGreen))
					.gridCell(column: 0, row: 0)
				OverviewHeroItemView(name: "Download", value: data.downloadString, color: Color(nsColor: .systemBlue))
					.gridCell(column: 1, row: 0)
				OverviewTopItemView(name: "Download Total", value: data.downloadTotal)
					.gridCell(column: 2, row: 0)
				OverviewTopItemView(name: "Upload Total", value: data.uploadTotal)
					.gridCell(column: 3, row: 0)
				OverviewTopItemView(name: "Active Connections", value: data.activeConns)
					.gridCell(column: 0, row: 1)
				OverviewTopItemView(name: "Mihomo", value: version)
					.gridCell(column: 1, row: 1)
				MemoryCardView()
					.gridCell(column: 2, row: 1)
				TrafficCardView()
					.gridCell(column: 0, row: 2, columnSpan: 2, rowSpan: 2)
			}
			.padding(DashboardTheme.spacingPage)
		}
		.background(DashboardTheme.pageBackground)
		.task {
			await loadVersion()
		}
    }

	@MainActor
	func loadVersion() async {
		version = await ApiRequest.requestVersion()?.version ?? ""
	}
	
}