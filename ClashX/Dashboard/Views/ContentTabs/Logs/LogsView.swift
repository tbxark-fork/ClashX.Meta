//
//  LogsView.swift
//  ClashX Dashboard
//
//

import SwiftUI

struct LogsView: View {
	
	@EnvironmentObject var logStorage: ClashLogStorage
	
	@EnvironmentObject var toolbarState: DashboardToolbarState
	@State var searchString: String = ""
    @State var logFilter = DashboardViewContoller.LogFilter.all
    
	@State var logLevel = ConfigOverride.shared.logLevel
	
    var body: some View {
		Group {
			LogsTableView(
                data: logStorage.logs.reversed(),
                filterString: searchString,
                logFilter: toolbarState.logFilter
            )
		}
		.onAppear {
			searchString = toolbarState.searchText
		}
		.onChange(of: toolbarState.searchText) { newValue in
			searchString = newValue
		}
		.onChange(of: toolbarState.logLevel) { newValue in
			logLevelChanged(newValue)
		}
    }
	
	func logLevelChanged(_ level: ClashLogLevel) {
		logStorage.logs.removeAll()
		ConfigOverride.shared.logLevel = level
        Task { @MainActor in
            await ApiRequest.updateLogLevel(level: level)
            ApiRequestStream.shared.resetStreamApi(for: .logging)
        }
	}
}

struct LogsView_Previews: PreviewProvider {
    static var previews: some View {
        LogsView()
    }
}
