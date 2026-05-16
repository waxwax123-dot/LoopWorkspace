// AppleHealthIRService.swift
// Loop
//
// Converts BiometricsSnapshot readings into IR delta percentages and maintains
// a cumulative IR multiplier clamped to [0.5, 2.0].

import Foundation
import os.log

private let log = OSLog(subsystem: "com.loopkit.Loop", category: "AppleHealthIRService")

// MARK: - Protocol

public protocol AppleHealthIRServiceProtocol: AnyObject {
    /// Process a new biometrics snapshot and update internal state.
    func update(snapshot: BiometricsSnapshot)

    /// Combined IR multiplier in [0.5, 2.0]. Values > 1.0 mean elevated resistance.
    var multiplier: Double { get }

    /// All entries in the 24-hour rolling window.
    var entries: [AppleHealthIREntry] { get }
}

// MARK: - BaseAppleHealthIRService

/// Core implementation. Subclass or replace for testing.
public class BaseAppleHealthIRService: AppleHealthIRServiceProtocol {

    // MARK: - Constants

    private static let multiplierFloor: Double = 0.5
    private static let multiplierCeiling: Double = 2.0

    // MARK: - State

    public private(set) var multiplier: Double = 1.0

    public var entries: [AppleHealthIREntry] {
        AppleHealthIREntry.allEntries()
    }

    // MARK: - Init

    public init() {}

    // MARK: - AppleHealthIRServiceProtocol

    public func update(snapshot: BiometricsSnapshot) {
        let thresholds = AppleHealthIRThresholds.current
        let now = Date()

        // Compute deltas
        let sleepDelta    = computeSleepDelta(snapshot.sleepHours)
        let stepsDelta    = computeStepsDelta(snapshot.stepCount)
        let hrvDelta      = computeHRVDelta(snapshot.hrvSDNN)
        let exerciseDelta = computeExerciseDelta(snapshot.exerciseMinutes)

        // Persist entries for non-nil sources
        if snapshot.sleepHours != nil {
            let entry = AppleHealthIREntry(
                timestamp: now,
                source: .sleep,
                irDeltaPercent: sleepDelta,
                details: String(format: "%.1f h sleep", snapshot.sleepHours ?? 0)
            )
            AppleHealthIREntry.append(entry)
        }

        if snapshot.stepCount != nil {
            let entry = AppleHealthIREntry(
                timestamp: now,
                source: .steps,
                irDeltaPercent: stepsDelta,
                details: String(format: "%.0f steps", snapshot.stepCount ?? 0)
            )
            AppleHealthIREntry.append(entry)
        }

        if snapshot.hrvSDNN != nil {
            let entry = AppleHealthIREntry(
                timestamp: now,
                source: .hrv,
                irDeltaPercent: hrvDelta,
                details: String(format: "%.1f ms HRV SDNN", snapshot.hrvSDNN ?? 0)
            )
            AppleHealthIREntry.append(entry)
        }

        if snapshot.exerciseMinutes != nil {
            let entry = AppleHealthIREntry(
                timestamp: now,
                source: .exercise,
                irDeltaPercent: exerciseDelta,
                details: String(format: "%.0f min exercise", snapshot.exerciseMinutes ?? 0)
            )
            AppleHealthIREntry.append(entry)
        }

        // Recompute multiplier from all four deltas (sum, then apply as factor)
        let totalDeltaPercent = sleepDelta + stepsDelta + hrvDelta + exerciseDelta
        let rawMultiplier = 1.0 + (totalDeltaPercent / 100.0)
        multiplier = max(Self.multiplierFloor, min(Self.multiplierCeiling, rawMultiplier))

        os_log(.debug, log: log,
               "IR update — sleep: %.1f%%, steps: %.1f%%, hrv: %.1f%%, ex: %.1f%%, multiplier: %.2f",
               sleepDelta, stepsDelta, hrvDelta, exerciseDelta, multiplier)
    }

    // MARK: - Delta computation (deterministic, no side effects)

    /// Returns IR delta % for sleep. Positive = more resistance.
    /// Uses linear interpolation between adjacent threshold bands.
    public func computeSleepDelta(_ hours: Double?) -> Double {
        guard let hours = hours else { return 0 }

        let t = AppleHealthIRThresholds.current

        if hours < t.sleepSevereBelow {
            return t.sleepSevereEffect
        } else if hours < t.sleepSubstantialBelow {
            return lerp(from: t.sleepSevereEffect,
                        to: t.sleepSubstantialEffect,
                        lowerBound: t.sleepSevereBelow,
                        upperBound: t.sleepSubstantialBelow,
                        value: hours)
        } else if hours < t.sleepModerateBelow {
            return lerp(from: t.sleepSubstantialEffect,
                        to: t.sleepModerateEffect,
                        lowerBound: t.sleepSubstantialBelow,
                        upperBound: t.sleepModerateBelow,
                        value: hours)
        } else if hours < t.sleepMildBelow {
            return lerp(from: t.sleepModerateEffect,
                        to: 0.0,
                        lowerBound: t.sleepModerateBelow,
                        upperBound: t.sleepMildBelow,
                        value: hours)
        } else {
            // At or above sleepMildBelow: IR returns to baseline
            return 0
        }
    }

    /// Returns IR delta % for step count. Negative = improved sensitivity.
    public func computeStepsDelta(_ steps: Double?) -> Double {
        guard let steps = steps else { return 0 }

        let t = AppleHealthIRThresholds.current

        if steps < t.stepsLowMin {
            return t.stepsLowEffect
        } else if steps < t.stepsModerateMin {
            return lerp(from: t.stepsLowEffect,
                        to: t.stepsModerateEffect,
                        lowerBound: t.stepsLowMin,
                        upperBound: t.stepsModerateMin,
                        value: steps)
        } else if steps < t.stepsHighMin {
            return lerp(from: t.stepsModerateEffect,
                        to: t.stepsHighEffect,
                        lowerBound: t.stepsModerateMin,
                        upperBound: t.stepsHighMin,
                        value: steps)
        } else if steps < t.stepsVeryHighMin {
            return lerp(from: t.stepsHighEffect,
                        to: t.stepsVeryHighEffect,
                        lowerBound: t.stepsHighMin,
                        upperBound: t.stepsVeryHighMin,
                        value: steps)
        } else {
            return t.stepsVeryHighEffect
        }
    }

    /// Returns IR delta % for HRV SDNN. Negative = improved sensitivity.
    public func computeHRVDelta(_ hrv: Double?) -> Double {
        guard let hrv = hrv else { return 0 }

        let t = AppleHealthIRThresholds.current

        if hrv < t.hrvLowBelow {
            return t.hrvLowEffect
        } else if hrv < t.hrvModerateBelow {
            return lerp(from: t.hrvLowEffect,
                        to: t.hrvModerateEffect,
                        lowerBound: t.hrvLowBelow,
                        upperBound: t.hrvModerateBelow,
                        value: hrv)
        } else if hrv < t.hrvHighAbove {
            return lerp(from: t.hrvModerateEffect,
                        to: t.hrvNormalEffect,
                        lowerBound: t.hrvModerateBelow,
                        upperBound: t.hrvHighAbove,
                        value: hrv)
        } else {
            return t.hrvHighEffect
        }
    }

    /// Returns IR delta % for exercise minutes. Negative = improved sensitivity.
    public func computeExerciseDelta(_ minutes: Double?) -> Double {
        guard let minutes = minutes else { return 0 }

        let t = AppleHealthIRThresholds.current

        if minutes < t.exerciseModerateMin {
            return 0
        } else if minutes < t.exerciseSubstantialMin {
            return lerp(from: 0,
                        to: t.exerciseModerateEffect,
                        lowerBound: t.exerciseModerateMin,
                        upperBound: t.exerciseSubstantialMin,
                        value: minutes)
        } else if minutes < t.exerciseHeavyMin {
            return lerp(from: t.exerciseModerateEffect,
                        to: t.exerciseSubstantialEffect,
                        lowerBound: t.exerciseSubstantialMin,
                        upperBound: t.exerciseHeavyMin,
                        value: minutes)
        } else {
            return t.exerciseHeavyEffect
        }
    }

    // MARK: - Private helpers

    /// Linear interpolation within a band. Guards against divide-by-zero.
    private func lerp(from startValue: Double,
                      to endValue: Double,
                      lowerBound: Double,
                      upperBound: Double,
                      value: Double) -> Double {
        let range = upperBound - lowerBound
        guard range > 0 else { return startValue }
        let fraction = (value - lowerBound) / range
        return startValue + fraction * (endValue - startValue)
    }
}

