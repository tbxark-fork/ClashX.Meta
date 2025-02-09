//
//  ProvidersView.swift
//  ClashX Dashboard
//
//

import SwiftUI
import SwiftUIIntrospect

struct ProvidersView: View {
	@ObservedObject var providerStorage = DBProviderStorage()
	
	@State private var searchString = ProxiesSearchString()
	
	@StateObject private var hideProxyNames = HideProxyNames()
	
    var body: some View {
		NavigationView {
			listView
			EmptyView()
		}
        .background(Color("SwiftUI Colors/WindowBackgroundColor"))
		.onReceive(NotificationCenter.default.publisher(for: .toolbarSearchString)) {
			guard let string = $0.userInfo?["String"] as? String else { return }
			searchString.string = string
		}
		.onReceive(NotificationCenter.default.publisher(for: .hideNames)) {
			guard let hide = $0.userInfo?["hide"] as? Bool else { return }
			hideProxyNames.hide = hide
		}
		.environmentObject(searchString)
		.onAppear {
			loadProviders()
		}
		.environmentObject(hideProxyNames)
    }
	
	var listView: some View {
		List {
			if providerStorage.proxyProviders.isEmpty,
			   providerStorage.ruleProviders.isEmpty {
				Text("Empty")
					.padding()
			} else {
				Section() {
					if !providerStorage.proxyProviders.isEmpty {
						ProxyProvidersRowView(providerStorage: providerStorage)
					}
					if !providerStorage.ruleProviders.isEmpty {
						RuleProvidersRowView(providerStorage: providerStorage)
					}
				} header: {
					Text("Providers")
				}
			}
			
			if !providerStorage.proxyProviders.isEmpty {
				Text("")
				Section() {
					ForEach(providerStorage.proxyProviders,id: \.id) {
						ProviderRowView(proxyProvider: $0)
					}
				} header: {
					Text("Proxy Provider")
				}
			}
		}
		.introspect(.table, on: .macOS(.v12, .v13, .v14, .v15)) {
			$0.refusesFirstResponder = true
			$0.doubleAction = nil
		}
		.listStyle(.plain)
	}
	
	func loadProviders() {
		ApiRequest.requestProxyProviderList { resp in
			providerStorage.proxyProviders = 		resp.allProviders.values.filter {
				$0.vehicleType == .HTTP
			}.sorted {
				$0.name < $1.name
			}
			.map(DBProxyProvider.init)
		}
		ApiRequest.requestRuleProviderList { resp in
			providerStorage.ruleProviders = resp.allProviders.values.sorted {
					$0.name < $1.name
				}
				.map(DBRuleProvider.init)
		}
	}
	
}

//struct ProvidersView_Previews: PreviewProvider {
//    static var previews: some View {
//        ProvidersView()
//    }
//}
