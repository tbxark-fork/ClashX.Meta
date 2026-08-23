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

			ConnectionsTableView(data: data.conns,
								 filterString: searchString)
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
