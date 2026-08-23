//
//  ProxyLatencyView.swift
//  ClashX Dashboard
//
//

import SwiftUI

struct ProxyLatencyView: View {
	let number: Int?
	let isTesting: Bool
	var onClick: (() -> Void)?

	var body: some View {
		let label = isTesting ? "Testing..." : (number.map { "\($0) ms" } ?? "--")
		Text(verbatim: label)
			.font(DashboardTheme.secondaryTextFont)
			.foregroundColor(number.map { DBProxy.delayColor($0) } ?? Color.secondary)
			.contentShape(Rectangle())
			.onTapGesture {
				guard !isTesting else { return }
				onClick?()
			}
			.help(label)
	}
}
