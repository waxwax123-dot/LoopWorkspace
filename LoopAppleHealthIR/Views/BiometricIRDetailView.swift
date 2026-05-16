// BiometricIRDetailView.swift
// Loop
//
// Sheet presenting detailed IR data for a single biometric source:
// current raw value, current IR delta, full threshold table, and 24-hour log.

import SwiftUI

public struct BiometricIRDetailView: View {

    let source: BiometricSource
    let rawValue: Double?
    let irDelta: Double

    public init(source: BiometricSource, rawValue: Double?, irDelta: Double) {
        self.source = source
        self.rawValue = rawValue
        self.irDelta = irDelta
    }

    private var filteredEntries: [AppleHealthIREntry] {
        AppleHealthIREntry.allEntries().filter { $0.source == source }
    }

    public var body: some View {
        NavigationView {
            List {
                currentValueSection
                thresholdTableSection
                historySection
            }
            .navigationTitle(source.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Current value

    private var currentValueSection: some View {
        Section(header: Text("Current Reading")) {
            HStack {
                Text("Value")
                Spacer()
                Text(rawValue.map { source.formatValue($0) } ?? "—")
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            HStack {
                Text("IR Delta")
                Spacer()
                Text(irDelta == 0 ? "None" : String(format: "%+.0f%%", irDelta))
                    .foregroundColor(irDelta > 0 ? .orange : irDelta < 0 ? .green : .secondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Threshold table (live from AppleHealthIRThresholds.current)

    @ViewBuilder
    private var thresholdTableSection: some View {
        Section(header: Text("Thresholds")) {
            ForEach(thresholdRows, id: \.label) { row in
                HStack {
                    Text(row.label)
                    Spacer()
                    Text(row.value)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    Text(row.effect)
                        .foregroundColor(row.effectIsPositive ? .orange :
                                         row.effectIsNegative ? .green : .secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
    }

    // MARK: - 24-hour log

    private var historySection: some View {
        Section(header: Text("Last 24 Hours")) {
            if filteredEntries.isEmpty {
                Text("No data recorded yet.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(filteredEntries.reversed(), id: \.timestamp) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.details)
                                .font(.subheadline)
                            Spacer()
                            Text(entry.irDeltaPercent == 0
                                 ? "None"
                                 : String(format: "%+.0f%%", entry.irDeltaPercent))
                                .foregroundColor(entry.irDeltaPercent > 0 ? .orange :
                                                 entry.irDeltaPercent < 0 ? .green : .secondary)
                                .monospacedDigit()
                                .font(.subheadline)
                        }
                        Text(entry.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Threshold rows builder

    private struct ThresholdRow {
        let label: String
        let value: String
        let effect: String
        var effectIsPositive: Bool
        var effectIsNegative: Bool
    }

    private var thresholdRows: [ThresholdRow] {
        let t = AppleHealthIRThresholds.current
        switch source {
        case .sleep:
            return [
                row("Severe below",      String(format: "< %.1f h", t.sleepSevereBelow),      t.sleepSevereEffect),
                row("Substantial below", String(format: "< %.1f h", t.sleepSubstantialBelow), t.sleepSubstantialEffect),
                row("Moderate below",   String(format: "< %.1f h", t.sleepModerateBelow),    t.sleepModerateEffect),
                row("Mild below",       String(format: "< %.1f h", t.sleepMildBelow),        t.sleepMildEffect),
                row("Baseline",         String(format: ">= %.1f h", t.sleepMildBelow),       0),
            ]
        case .steps:
            return [
                row("Very low",   String(format: "< %.0f", t.stepsLowMin),                  t.stepsLowEffect),
                row("Low",        String(format: "%.0f–%.0f", t.stepsLowMin, t.stepsModerateMin), t.stepsModerateEffect),
                row("Moderate",   String(format: "%.0f–%.0f", t.stepsModerateMin, t.stepsHighMin), t.stepsHighEffect),
                row("High",       String(format: "%.0f–%.0f", t.stepsHighMin, t.stepsVeryHighMin), t.stepsVeryHighEffect),
                row("Very high",  String(format: ">= %.0f", t.stepsVeryHighMin),             t.stepsVeryHighEffect),
            ]
        case .hrv:
            return [
                row("Low",    String(format: "< %.0f ms", t.hrvLowBelow),                         t.hrvLowEffect),
                row("Moderate", String(format: "%.0f–%.0f ms", t.hrvLowBelow, t.hrvModerateBelow), t.hrvModerateEffect),
                row("Normal", String(format: "%.0f–%.0f ms", t.hrvModerateBelow, t.hrvHighAbove),  t.hrvNormalEffect),
                row("High",   String(format: ">= %.0f ms", t.hrvHighAbove),                       t.hrvHighEffect),
            ]
        case .exercise:
            return [
                row("None",        String(format: "< %.0f min", t.exerciseModerateMin),              0),
                row("Moderate",    String(format: "%.0f–%.0f min", t.exerciseModerateMin, t.exerciseSubstantialMin), t.exerciseModerateEffect),
                row("Substantial", String(format: "%.0f–%.0f min", t.exerciseSubstantialMin, t.exerciseHeavyMin),    t.exerciseSubstantialEffect),
                row("Heavy",       String(format: ">= %.0f min", t.exerciseHeavyMin),                t.exerciseHeavyEffect),
            ]
        }
    }

    private func row(_ label: String, _ value: String, _ effect: Double) -> ThresholdRow {
        ThresholdRow(
            label: label,
            value: value,
            effect: effect == 0 ? "None" : String(format: "%+.0f%%", effect),
            effectIsPositive: effect > 0,
            effectIsNegative: effect < 0
        )
    }
}

// MARK: - BiometricSource display helpers

extension BiometricSource {
    var displayName: String {
        switch self {
        case .sleep:    return "Sleep"
        case .steps:    return "Steps"
        case .hrv:      return "HRV"
        case .exercise: return "Exercise"
        }
    }

    func formatValue(_ value: Double) -> String {
        switch self {
        case .sleep:    return String(format: "%.1f h", value)
        case .steps:    return String(format: "%.0f steps", value)
        case .hrv:      return String(format: "%.0f ms", value)
        case .exercise: return String(format: "%.0f min", value)
        }
    }
}
