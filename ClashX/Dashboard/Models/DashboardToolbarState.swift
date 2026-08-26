//
//  DashboardToolbarState.swift
//  ClashX Dashboard
//
//

import Foundation

@MainActor
final class DashboardToolbarState: ObservableObject {
    enum LogFilter: String, CaseIterable {
        case all = "All"
        case rule = "Rule"
        case dns = "DNS"
        case others = "Others"
    }

    @Published var searchText = ""
    @Published var hideProxyNames = false
    @Published var logLevel = ConfigOverride.shared.logLevel
    @Published var logFilter = LogFilter.all
    @Published var connShowClosed = false
    @Published var connSourceIPFilter = ""

    func stopConns() {
        NotificationCenter.default.post(name: .stopConns, object: nil)
    }

    func hideNamesToggled() {
        hideProxyNames.toggle()
    }

    func updateLogLevel(_ level: ClashLogLevel) {
        guard logLevel != level else { return }
        logLevel = level
    }

    func updateLogFilter(_ filter: LogFilter) {
        guard logFilter != filter else { return }
        logFilter = filter
    }
}
