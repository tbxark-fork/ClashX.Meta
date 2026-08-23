//
//  FormatterExtension.swift
//  ClashX Dashboard
//
//

import Foundation

enum DashboardFormatters {
	static let byteCount: ByteCountFormatter = {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .binary
		return formatter
	}()

	static let relativeDateTimeShort: RelativeDateTimeFormatter = {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .short
		return formatter
	}()

	static func providerUpdateText(for date: Date) -> String {
		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .abbreviated
		let relative = formatter.localizedString(for: date, relativeTo: Date())
		return Locale.current.language.languageCode?.identifier == "zh"
			? "更新于 \(relative)"
			: "Updated \(relative)"
	}
}
