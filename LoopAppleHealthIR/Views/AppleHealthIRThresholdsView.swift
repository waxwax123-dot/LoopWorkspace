// AppleHealthIRThresholdsView.swift
// Loop
//
// Settings screen for adjusting per-biometric IR thresholds.
// Enforces ordering constraints through Stepper bounds and validation.

import SwiftUI

public struct AppleHealthIRThresholdsView: View {

    @State private var thresholds: AppleHealthIRThresholds = .current
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationView {
            Form {
                sleepSection
                stepsSection
                hrvSection
                exerciseSection

                Section {
                    Button(role: .destructive) {
                        AppleHealthIRThresholds.resetToDefaults()
                        thresholds = .defaults
                    } label: {
                        Text("Reset to Defaults")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("IR Thresholds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sleep Section

    private var sleepSection: some View {
        Section(header: Text("Sleep (hours)")) {
            stepperRow(
                label: "Severe below",
                value: $thresholds.sleepSevereBelow,
                range: 1.0...max(1.0, thresholds.sleepSubstantialBelow - 0.5),
                step: 0.5,
                format: "%.1f h"
            )
            stepperRow(
                label: "Substantial below",
                value: $thresholds.sleepSubstantialBelow,
                range: (thresholds.sleepSevereBelow + 0.5)...max(thresholds.sleepSevereBelow + 0.5, thresholds.sleepModerateBelow - 0.5),
                step: 0.5,
                format: "%.1f h"
            )
            stepperRow(
                label: "Moderate below",
                value: $thresholds.sleepModerateBelow,
                range: (thresholds.sleepSubstantialBelow + 0.5)...max(thresholds.sleepSubstantialBelow + 0.5, thresholds.sleepMildBelow - 0.5),
                step: 0.5,
                format: "%.1f h"
            )
            stepperRow(
                label: "Mild below",
                value: $thresholds.sleepMildBelow,
                range: (thresholds.sleepModerateBelow + 0.5)...14.0,
                step: 0.5,
                format: "%.1f h"
            )
            effectRow(label: "Severe effect",     value: $thresholds.sleepSevereEffect,      suffix: "%")
            effectRow(label: "Substantial effect", value: $thresholds.sleepSubstantialEffect, suffix: "%")
            effectRow(label: "Moderate effect",   value: $thresholds.sleepModerateEffect,    suffix: "%")
            effectRow(label: "Mild effect",       value: $thresholds.sleepMildEffect,        suffix: "%")
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        Section(header: Text("Steps (per day)")) {
            stepperRow(
                label: "Low minimum",
                value: $thresholds.stepsLowMin,
                range: 500...max(500, thresholds.stepsModerateMin - 500),
                step: 500,
                format: "%.0f"
            )
            stepperRow(
                label: "Moderate minimum",
                value: $thresholds.stepsModerateMin,
                range: (thresholds.stepsLowMin + 500)...max(thresholds.stepsLowMin + 500, thresholds.stepsHighMin - 500),
                step: 500,
                format: "%.0f"
            )
            stepperRow(
                label: "High minimum",
                value: $thresholds.stepsHighMin,
                range: (thresholds.stepsModerateMin + 500)...max(thresholds.stepsModerateMin + 500, thresholds.stepsVeryHighMin - 500),
                step: 500,
                format: "%.0f"
            )
            stepperRow(
                label: "Very high minimum",
                value: $thresholds.stepsVeryHighMin,
                range: (thresholds.stepsHighMin + 500)...30_000,
                step: 500,
                format: "%.0f"
            )
            effectRow(label: "Low effect",       value: $thresholds.stepsLowEffect,      suffix: "%")
            effectRow(label: "Moderate effect",  value: $thresholds.stepsModerateEffect, suffix: "%")
            effectRow(label: "High effect",      value: $thresholds.stepsHighEffect,     suffix: "%")
            effectRow(label: "Very high effect", value: $thresholds.stepsVeryHighEffect, suffix: "%")
        }
    }

    // MARK: - HRV Section

    private var hrvSection: some View {
        Section(header: Text("HRV SDNN (ms)")) {
            stepperRow(
                label: "Low below",
                value: $thresholds.hrvLowBelow,
                range: 5.0...max(5.0, thresholds.hrvModerateBelow - 5),
                step: 5.0,
                format: "%.0f ms"
            )
            stepperRow(
                label: "Moderate below",
                value: $thresholds.hrvModerateBelow,
                range: (thresholds.hrvLowBelow + 5)...max(thresholds.hrvLowBelow + 5, thresholds.hrvHighAbove - 5),
                step: 5.0,
                format: "%.0f ms"
            )
            stepperRow(
                label: "High above",
                value: $thresholds.hrvHighAbove,
                range: (thresholds.hrvModerateBelow + 5)...200.0,
                step: 5.0,
                format: "%.0f ms"
            )
            effectRow(label: "Low effect",      value: $thresholds.hrvLowEffect,      suffix: "%")
            effectRow(label: "Moderate effect", value: $thresholds.hrvModerateEffect, suffix: "%")
            effectRow(label: "Normal effect",   value: $thresholds.hrvNormalEffect,   suffix: "%")
            effectRow(label: "High effect",     value: $thresholds.hrvHighEffect,     suffix: "%")
        }
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        Section(header: Text("Exercise (minutes/day)")) {
            stepperRow(
                label: "Moderate minimum",
                value: $thresholds.exerciseModerateMin,
                range: 5.0...max(5.0, thresholds.exerciseSubstantialMin - 5),
                step: 5.0,
                format: "%.0f min"
            )
            stepperRow(
                label: "Substantial minimum",
                value: $thresholds.exerciseSubstantialMin,
                range: (thresholds.exerciseModerateMin + 5)...max(thresholds.exerciseModerateMin + 5, thresholds.exerciseHeavyMin - 5),
                step: 5.0,
                format: "%.0f min"
            )
            stepperRow(
                label: "Heavy minimum",
                value: $thresholds.exerciseHeavyMin,
                range: (thresholds.exerciseSubstantialMin + 5)...300.0,
                step: 5.0,
                format: "%.0f min"
            )
            effectRow(label: "Moderate effect",    value: $thresholds.exerciseModerateEffect,    suffix: "%")
            effectRow(label: "Substantial effect", value: $thresholds.exerciseSubstantialEffect, suffix: "%")
            effectRow(label: "Heavy effect",       value: $thresholds.exerciseHeavyEffect,       suffix: "%")
        }
    }

    // MARK: - Reusable row builders

    private func stepperRow(label: String,
                            value: Binding<Double>,
                            range: ClosedRange<Double>,
                            step: Double,
                            format: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: format, value.wrappedValue))
                .foregroundColor(.secondary)
                .monospacedDigit()
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { _ in
                    if thresholds.isValid { thresholds.save() }
                }
        }
    }

    private func effectRow(label: String, value: Binding<Double>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%+.0f\(suffix)", value.wrappedValue))
                .foregroundColor(value.wrappedValue > 0 ? .orange :
                                 value.wrappedValue < 0 ? .green : .secondary)
                .monospacedDigit()
            Stepper("", value: value, in: -100.0...100.0, step: 1.0)
                .labelsHidden()
                .onChange(of: value.wrappedValue) { _ in
                    if thresholds.isValid { thresholds.save() }
                }
        }
    }
}
