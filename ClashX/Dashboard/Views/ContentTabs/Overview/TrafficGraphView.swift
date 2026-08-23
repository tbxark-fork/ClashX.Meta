//
//  TrafficGraphView.swift
//  ClashX Dashboard
//
//

import SwiftUI
import Charts

private let segmentCount = 2

enum TrafficGraphType {
	case rate
	case size
}

struct TrafficGraphView: View {
	@Binding var values: [CGFloat]
	let graphColor: Color
	var showYAxis: Bool = true
	var graphType: TrafficGraphType = .rate
	@State private var selectedIndex: Int?

    var body: some View {
		let scale = chartScale(for: values)
		let step = Double(scale.upperBound) / 2
		let yValues = stride(from: 0.0, through: Double(scale.upperBound), by: step)

		let chart = Chart(Array(values.enumerated()), id: \.offset) { pair in
			AreaMark(
				x: .value("Time", pair.offset),
				y: .value("Speed", Double(pair.element))
			)
			.interpolationMethod(.monotone)
			.foregroundStyle(
				LinearGradient(
					colors: [graphColor.opacity(0.25), graphColor.opacity(0.02)],
					startPoint: .top,
					endPoint: .bottom
				)
			)

			LineMark(
				x: .value("Time", pair.offset),
				y: .value("Speed", Double(pair.element))
			)
			.foregroundStyle(graphColor)
			.interpolationMethod(.monotone)
			.lineStyle(StrokeStyle(lineWidth: 2))

			if #available(macOS 14.0, *),
			   let selectedIndex,
			   values.indices.contains(selectedIndex) {
				let selectedValue = Double(values[selectedIndex])

				RuleMark(x: .value("Time", selectedIndex))
					.foregroundStyle(.secondary.opacity(0.5))
					.lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
					.annotation(
						position: .top,
						spacing: 6,
						overflowResolution: .init(x: .fit(to: .chart), y: .fit)
					) {
						Text(speedString(for: Int(selectedValue), suffix: graphType == .rate ? "/s" : ""))
							.font(.system(size: 10).monospacedDigit())
							.foregroundStyle(.primary)
							.padding(.horizontal, 8)
							.padding(.vertical, 3)
							.background(
								Color(nsColor: .textBackgroundColor).opacity(0.9),
								in: RoundedRectangle(cornerRadius: 5)
							)
					}
			}
		}
		.chartXAxis(.hidden)
		.chartYScale(domain: 0...Double(scale.upperBound))

		let chartWithAxis: some View = Group {
			if showYAxis {
				chart.chartYAxis {
					AxisMarks(values: Array(yValues)) { value in
						AxisValueLabel {
							if let v = value.as(Double.self) {
								Text(axisLabel(for: v, unit: scale.unit))
									.font(.system(size: 11).monospacedDigit())
									.foregroundStyle(.secondary)
							}
						}
					}
				}
			} else {
				chart.chartYAxis(.hidden)
			}
		}

		Group {
			if #available(macOS 14.0, *) {
				chartWithAxis.chartXSelection(value: $selectedIndex)
			} else {
				chartWithAxis
			}
		}
    }

	private func chartScale(for values: [CGFloat]) -> TrafficScale {
		let peakValue = values.max() ?? CGFloat(segmentCount) * 1000
		let unit = chartUnit(for: Double(peakValue))
		let maxValueInUnit = Double(peakValue) / unit.divisor
		let minimumScaleValue = unit == .kilobytesPerSecond ? Double(segmentCount) : 0
		let baselineMaxValue = Swift.max(maxValueInUnit, minimumScaleValue)
		let step = niceStep(for: baselineMaxValue / Double(segmentCount))
		let upperValue = step * Double(segmentCount)

		// Switch the whole scale to the next unit once the top reaches a full 1000
		if upperValue >= 1000, let nextUnit = unit.next {
			let maxInNextUnit = maxValueInUnit / 1000
			let nextStep = niceStep(for: maxInNextUnit / Double(segmentCount))
			let nextUpperValue = nextStep * Double(segmentCount)
			return TrafficScale(
				upperBound: CGFloat(nextUpperValue * nextUnit.divisor),
				unit: nextUnit
			)
		}

		return TrafficScale(
			upperBound: CGFloat(upperValue * unit.divisor),
			unit: unit
		)
	}

	private func chartUnit(for value: Double) -> TrafficUnit {
		switch value {
		case ..<1_000_000:
			return .kilobytesPerSecond
		case ..<1_000_000_000:
			return .megabytesPerSecond
		default:
			return .gigabytesPerSecond
		}
	}

	private func niceStep(for rawStep: Double) -> Double {
		guard rawStep > 0 else { return 1 }

		let exponent = floor(log10(rawStep))
		let base = pow(10, exponent)
		let fraction = rawStep / base

		let niceFraction: Double
		switch fraction {
		case ...1:
			niceFraction = 1
		case ...2:
			niceFraction = 2
		case ...5:
			niceFraction = 5
		default:
			niceFraction = 10
		}

		return niceFraction * base
	}

	private func axisLabel(for value: Double, unit: TrafficUnit) -> String {
		if value == 0 { return "0" }

		var scaledValue = value / unit.divisor
		var unit = unit
		// Carry over to the next unit once a full 1000 is reached
		if scaledValue >= 1000, let nextUnit = unit.next {
			scaledValue /= 1000
			unit = nextUnit
		}
		return threeSigFigures(scaledValue) + unit.rawValue
	}

}

private struct TrafficScale {
	let upperBound: CGFloat
	let unit: TrafficUnit
}

private enum TrafficUnit: String {
		case kilobytesPerSecond = "KB/s"
		case megabytesPerSecond = "MB/s"
		case gigabytesPerSecond = "GB/s"

		var divisor: Double {
			switch self {
			case .kilobytesPerSecond:
				return 1_000
			case .megabytesPerSecond:
				return 1_000_000
			case .gigabytesPerSecond:
				return 1_000_000_000
			}
		}

		var next: TrafficUnit? {
			switch self {
			case .kilobytesPerSecond:
				return .megabytesPerSecond
			case .megabytesPerSecond:
				return .gigabytesPerSecond
			case .gigabytesPerSecond:
				return nil
			}
		}
	}

struct TrafficGraphView_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 16) {
			TrafficGraphView(
				values: .constant([12_000, 28_000, 35_000, 22_000, 48_000, 64_000, 40_000, 72_000]),
				graphColor: Color(nsColor: .systemBlue)
			)

			TrafficGraphView(
				values: .constant([2_000, 4_500, 3_500, 8_000, 6_500, 12_000, 9_000, 15_000]),
				graphColor: Color(nsColor: .systemGreen)
			)
		}
		.padding()
		.frame(width: 360)
	}
}
