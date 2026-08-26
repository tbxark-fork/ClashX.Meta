//
//  ClashApiDatasStorage.swift
//  ClashX Dashboard
//
//

import Cocoa
import SwiftUI
import CocoaLumberjackSwift

@MainActor
class ClashApiDatasStorage: NSObject, ObservableObject {
	private static let memoryFormatter = ByteCountFormatter()
	
	@Published var overviewData = ClashOverviewData()
	
	@Published var logStorage = ClashLogStorage()
	@Published var connsStorage = ClashConnsStorage()

	private var pendingTraffic: (up: Int, down: Int)?
	private var pendingLogs = [(level: String, log: String)]()
	private var uiUpdateTask: Task<Void, Never>?

	override init() {
		super.init()
		uiUpdateTask = Task { [weak self] in
			while !Task.isCancelled {
				try? await Task.sleep(seconds: 1)
				guard let self else { return }
                flushPendingUpdates()
			}
		}
	}

	deinit {
		uiUpdateTask?.cancel()
	}
	
	func resetStreamApi() {
		let needsStreamStart = !ApiRequestStream.shared.hasObservers
		ApiRequestStream.shared.addObserver(self)
		if needsStreamStart {
			ApiRequestStream.shared.resetStreamApis()
		}
	}

	// Seed history from ApiRequestStream so the dashboard opens with recent data instead of zeros
	func seedHistoryFromStore() {
		let store = ApiRequestStream.shared.trafficHistoryStore
		overviewData.downloadHistories = store.down
		overviewData.uploadHistories = store.up
		overviewData.memoryHistories = store.memory.map(CGFloat.init)
		if let memory = store.latestMemory {
			overviewData.memory = Self.memoryFormatter.string(fromByteCount: memory)
		}
		Logger.log("seed memory history: first=\(store.memory.first ?? -1) last=\(store.memory.last ?? -1) count=\(store.memory.count)", level: .debug)
	}
}

extension ClashApiDatasStorage: ApiRequestStreamDelegate {
    func streamStatusChanged() async {
    }

	func didUpdateTraffic(up: Int, down: Int) async {
        enqueueTrafficUpdate(up: up, down: down)
	}
	
	func didGetLog(log: String, level: String) async {
        enqueueLog(level: level, log: log)
	}
	
	func didUpdateMemory(memory: Int64) async {
		// Store handles sampling and history; nothing to do here
	}

	func enqueueTrafficUpdate(up: Int, down: Int) {
		pendingTraffic = (up: up, down: down)
	}

	func enqueueLog(level: String, log: String) {
		pendingLogs.append((level: level, log: log))
	}

	func flushPendingUpdates() {
		if let traffic = pendingTraffic {
			overviewData.down = traffic.down
			overviewData.up = traffic.up
			pendingTraffic = nil
		}

		if !pendingLogs.isEmpty {
			logStorage.logs.append(contentsOf: pendingLogs.map { .init(level: $0.level, log: $0.log) })
			pendingLogs.removeAll(keepingCapacity: true)

			if logStorage.logs.count > 1000 {
				logStorage.logs.removeFirst(100)
			}
		}

		// Sync history straight from the store; all sampling happens there
		let store = ApiRequestStream.shared.trafficHistoryStore
		overviewData.downloadHistories = store.down
		overviewData.uploadHistories = store.up
		overviewData.memoryHistories = store.memory.map(CGFloat.init)
		if let memory = store.latestMemory {
			overviewData.memory = Self.memoryFormatter.string(fromByteCount: memory)
		}
	}
	
}

fileprivate let TrafficHistoryLimit = 30
fileprivate let MemoryHistoryLimit = 15

class ClashOverviewData: ObservableObject, Identifiable {
	let id = UUID().uuidString

	private static let memoryFormatter = ByteCountFormatter()
	
	@Published var uploadString = "N/A"
	@Published var downloadString = "N/A"
	
	@Published var downloadTotal = "N/A"
	@Published var uploadTotal = "N/A"
	
	@Published var activeConns = "0"
	
	@Published var memory = "0 MB"
	
	@Published var downloadHistories = [CGFloat](repeating: 0, count: TrafficHistoryLimit)
	@Published var uploadHistories = [CGFloat](repeating: 0, count: TrafficHistoryLimit)
	@Published var memoryHistories = [CGFloat](repeating: 0, count: MemoryHistoryLimit)

	var down: Int = 0 {
		didSet {
			downloadString = getSpeedString(for: down)
		}
	}

	var up: Int = 0 {
		didSet {
			uploadString = getSpeedString(for: up)
		}
	}
	
	var downTotal: Int = 0 {
		didSet {
			downloadTotal = getSpeedString(for: downTotal).replacingOccurrences(of: "/s", with: "")
		}
	}
	
	var upTotal: Int = 0 {
		didSet {
			uploadTotal = getSpeedString(for: upTotal).replacingOccurrences(of: "/s", with: "")
		}
	}
	
	func getSpeedString(for byte: Int) -> String {
		speedString(for: byte)
	}
}

func speedString(for byte: Int, suffix: String = "/s") -> String {
	if byte < 1_000 {
		return "\(byte)B" + suffix
	}
	let kb = Double(byte) / 1_000
	if kb < 999.5 {
		return threeSigFigures(kb) + "KB" + suffix
	}
	let mb = kb / 1_000
	if mb < 999.5 {
		return threeSigFigures(mb) + "MB" + suffix
	}
	return threeSigFigures(mb / 1_000) + "GB" + suffix
}

// At most 3 significant figures with trailing zeros trimmed: 123, 1.23, 12.3
func threeSigFigures(_ value: Double) -> String {
	if value == 0 { return "0" }
	let exponent = floor(log10(value))
	let scale = pow(10, exponent - 2)
	let rounded = (value / scale).rounded() * scale
	let decimals = max(0, 2 - Int(exponent))
	var text = String(format: "%.\(decimals)f", rounded)
	if text.contains(".") {
		while text.hasSuffix("0") {
			text.removeLast()
		}
		if text.hasSuffix(".") {
			text.removeLast()
		}
	}
	return text
}

class ClashLogStorage: ObservableObject {
	@Published var logs = [ClashLog]()
	
	class ClashLog: NSObject, ObservableObject {
		let id: String
		
		let date: Date
		let level: ClashLogLevel
		@objc let log: String
		
		let levelColor: NSColor
		@objc let levelString: String
		
		init(level: String, log: String) {
			id = UUID().uuidString
			date = Date()
			
			self.level = .init(rawValue: level) ?? .unknow
			self.log = log
			
			self.levelString = level
			switch self.level {
			case .info:
				levelColor = .systemBlue
			case .warning:
				levelColor = .systemYellow
			case .error:
				levelColor = .systemRed
			case .debug:
				levelColor = .systemGreen
			default:
				levelColor = .white
			}
		}
	}
}

@MainActor
class ClashConnsStorage: ObservableObject {
	static let maxClosedConnections = 200

	@Published var conns = [DBConnection]()
	/// Closed connections, newest first, capped at `maxClosedConnections`.
	@Published private(set) var closedConns = [DBConnection]()
	/// While paused all processing is skipped (aligned with upstream yacd); the next resume diffs across the whole gap.
	@Published var isPaused = false

	/// Last applied snapshot; the closed-detection diff runs against this.
	private var trackedConns = [DBConnection]()

	private let appNameResolver = AppNameResolver()

	/// Nonisolated so an empty instance can be built from nonisolated contexts (e.g. EnvironmentKey.defaultValue).
	nonisolated init() {}

	func appName(processPath: String, process: String) async -> String {
		await appNameResolver.appName(processPath: processPath, process: process)
	}

	func apply(_ snapshot: DBConnectionSnapShot) {
		guard !isPaused else { return }
		defer { trackedConns = snapshot.connections }

		let activeIDs = Set(snapshot.connections.map(\.id))
		let newlyClosed = trackedConns.filter { !activeIDs.contains($0.id) }
		if !newlyClosed.isEmpty {
			var seen = Set(newlyClosed.map(\.id))
			var merged = newlyClosed
			for old in closedConns where seen.insert(old.id).inserted {
				merged.append(old)
			}
			closedConns = Array(merged.prefix(Self.maxClosedConnections))
		}

		conns = snapshot.connections
	}

	func reset() {
		conns.removeAll()
		closedConns.removeAll()
		trackedConns.removeAll()
	}
}

extension ClashConnsStorage {
	/// Unique sorted source IPs across active + closed connections.
	var allSourceIPs: [String] {
		var set = Set(conns.map(\.metadata.sourceIP))
		set.formUnion(closedConns.map(\.metadata.sourceIP))
		return set.filter { !$0.isEmpty }.sorted()
	}
}

extension DBConnection {
	/// Keyword + source IP filter matching the table's filter keys.
	func matches(keyword: String, sourceIP: String) -> Bool {
		if !sourceIP.isEmpty, metadata.sourceIP != sourceIP { return false }
		let trimmed = keyword.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty else { return true }
		let key = trimmed.lowercased()
		let candidates: [String] = [
			metadata.host,
			metadata.sniffHost,
			metadata.process,
			chains.reversed().joined(separator: "/"),
			rulePayload.isEmpty ? rule : "\(rule) :: \(rulePayload)",
			"\(metadata.sourceIP):\(metadata.sourcePort)",
			metadata.remoteDestination,
			metadata.destinationIP,
			"\(metadata.type)(\(metadata.network))",
		]
		return candidates.contains { $0.lowercased().contains(key) }
	}
}
