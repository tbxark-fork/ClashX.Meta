//
//  ConnectionsView.swift
//  ClashX Dashboard
//
//

import SwiftUI

struct ConnectionsView: View {

	@EnvironmentObject var data: ClashConnsStorage

	@EnvironmentObject var toolbarState: DashboardToolbarState
	@State private var searchString: String = ""

	var body: some View {
		let source = toolbarState.connShowClosed ? data.closedConns : data.conns
		let filtered = source.filter {
			$0.matches(keyword: searchString, sourceIP: toolbarState.connSourceIPFilter)
		}

		ConnectionsTableView(data: filtered)
			.background(Color(compatible: .textBackgroundColor))
			.onAppear {
				searchString = toolbarState.searchText
			}
			.onChange(of: toolbarState.searchText) { newValue in
				searchString = newValue
			}
			.onReceive(NotificationCenter.default.publisher(for: .stopConns)) { _ in
				stopConns()
			}
	}
	
	func stopConns() {
		Task {
			await ApiRequest.closeAllConnection()
		}
	}
}

struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
    }
}
