//
//  DashboardView.swift
//  ClashX Dashboard
//
//

import SwiftUI

class HideProxyNames: ObservableObject, Identifiable {
	let id = UUID().uuidString
	@Published var hide = false
}

struct DashboardView: View {
	
	private let runningState = NotificationCenter.default.publisher(for: .init("ClashRunningStateChanged"))
	@State private var isRunning = false
	
	var body: some View {
		Group {
			NavigationView {
				SidebarView()
				EmptyView()
			}
		}
		.onReceive(runningState) { _ in
			isRunning = ConfigManager.shared.isRunning
		}
		
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		DashboardView()
    }
}
