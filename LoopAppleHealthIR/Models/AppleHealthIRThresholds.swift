// AppleHealthIRThresholds.swift
// Loop
//
// Thresholds for Apple Health biometric insulin resistance (IR) calculations.
// All values represent physiological boundaries used for IR delta interpolation.

import Foundation
import os.log

private let log = OSLog(subsystem: "com.loopkit.Loop", category: "AppleHealthIRThresholds")

/// Thresholds governing how each biometric source shifts the IR multiplier.
/// Stored in UserDefaults and decoded on demand; falls back to `defaults` on error.
public struct AppleHealthIRThresholds: Codable, Equatable {

    // MARK: - UserDefaults key

    public static let defaultsKey = "AppleHealthIRThresholds"

    // MARK: - Sleep thresholds (hours)

    /// Hours below which IR is at maximum elevation (heavy penalty).
    public var sleepSevereBelow: Double      // e.g. 4.0

    /// Hours below which IR is substantially elevated.
    public var sleepSubstantialBelow: Double // e.g. 5.5

    /// Hours below which IR is moderately elevated.
    public var sleepModerateBelow: Double    // e.g. 6.5

    /// Hours at / above which IR is at baseline (no penalty).
    public var sleepMildBelow: Double        // e.g. 7.5

    // IR effect magnitudes for sleep (positive = resistance increase %)
    public var sleepSevereEffect: Double      // e.g.  40.0
    public var sleepSubstantialEffect: Double // e.g.  25.0
    public var sleepModerateEffect: Double    // e.g.  10.0
    // MARK: - Step thresholds (steps/day)

    public var stepsLowMin: Double            // e.g.  2_000
    public var stepsModerateMin: Double       // e.g.  7_000
    public var stepsHighMin: Double           // e.g. 10_000
    public var stepsVeryHighMin: Double       // e.g. 15_000

    // IR effect magnitudes for steps (negative = resistance decrease %)
    public var stepsLowEffect: Double         // e.g.  10.0
    public var stepsModerateEffect: Double    // e.g.   0.0
    public var stepsHighEffect: Double        // e.g.  -8.0
    public var stepsVeryHighEffect: Double    // e.g. -15.0

    // MARK: - HRV thresholds (SDNN, ms)

    public var hrvLowBelow: Double            // e.g. 20.0
    public var hrvModerateBelow: Double       // e.g. 40.0
    public var hrvHighAbove: Double           // e.g. 60.0

    // IR effect magnitudes for HRV (positive = resistance increase %)
    public var hrvLowEffect: Double           // e.g.  15.0
    public var hrvModerateEffect: Double      // e.g.   5.0
    public var hrvNormalEffect: Double        // e.g.   0.0
    public var hrvHighEffect: Double          // e.g. -10.0

    // MARK: - Exercise thresholds (minutes of moderate+ activity in last 24 h)

    /// |moderate| <= |substantial| <= |heavy| must hold for each direction.
    public var exerciseModerateMin: Double    // e.g.  20.0
    public var exerciseSubstantialMin: Double // e.g.  45.0
    public var exerciseHeavyMin: Double       // e.g.  90.0

    // IR effect magnitudes for exercise (negative = resistance decrease %)
    public var exerciseModerateEffect: Double    // e.g.  -5.0
    public var exerciseSubstantialEffect: Double // e.g. -12.0
    public var exerciseHeavyEffect: Double       // e.g. -20.0

    // MARK: - Defaults

    public static let defaults = AppleHealthIRThresholds(
        sleepSevereBelow: 4.0,
        sleepSubstantialBelow: 5.5,
        sleepModerateBelow: 6.5,
        sleepMildBelow: 7.5,
        sleepSevereEffect: 40.0,
        sleepSubstantialEffect: 25.0,
        sleepModerateEffect: 10.0,
        stepsLowMin: 2_000,
        stepsModerateMin: 7_000,
        stepsHighMin: 10_000,
        stepsVeryHighMin: 15_000,
        stepsLowEffect: 10.0,
        stepsModerateEffect: 0.0,
        stepsHighEffect: -8.0,
        stepsVeryHighEffect: -15.0,
        hrvLowBelow: 20.0,
        hrvModerateBelow: 40.0,
        hrvHighAbove: 60.0,
        hrvLowEffect: 15.0,
        hrvModerateEffect: 5.0,
        hrvNormalEffect: 0.0,
        hrvHighEffect: -10.0,
        exerciseModerateMin: 20.0,
        exerciseSubstantialMin: 45.0,
        exerciseHeavyMin: 90.0,
        exerciseModerateEffect: -5.0,
        exerciseSubstantialEffect: -12.0,
        exerciseHeavyEffect: -20.0
    )

    // MARK: - Persistence

    /// Load from UserDefaults. Falls back to `defaults` and logs a warning on failure.
    public static var current: AppleHealthIRThresholds {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(AppleHealthIRThresholds.self, from: data)
        } catch {
            os_log(.fault, log: log,
                   "Failed to decode AppleHealthIRThresholds: %{public}@. Using defaults.",
                   error.localizedDescription)
            return .defaults
        }
    }

    /// Persist to UserDefaults.
    public func save() {
        guard let data = try? JSONEncoder().encode(self) else {
            os_log(.error, log: log, "Failed to encode AppleHealthIRThresholds for save.")
            return
        }
        UserDefaults.standard.set(data, forKey: AppleHealthIRThresholds.defaultsKey)
    }

    /// Remove saved value so next access returns `defaults`.
    public static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    // MARK: - Ordering validation

    /// Returns true when all ordering constraints are satisfied.
    public var isValid: Bool {
        // Threshold ordering: sleep bands must be strictly ascending
        guard sleepSevereBelow < sleepSubstantialBelow,
              sleepSubstantialBelow < sleepModerateBelow,
              sleepModerateBelow < sleepMildBelow else { return false }

        // Sleep effect ordering: more deprivation must produce >= effect magnitude
        guard abs(sleepModerateEffect) <= abs(sleepSubstantialEffect),
              abs(sleepSubstantialEffect) <= abs(sleepSevereEffect) else { return false }

        // Threshold ordering: steps bands must be strictly ascending
        guard stepsLowMin < stepsModerateMin,
              stepsModerateMin < stepsHighMin,
              stepsHighMin < stepsVeryHighMin else { return false }

        // Steps effect ordering: higher activity must produce >= effect magnitude
        guard abs(stepsLowEffect) <= abs(stepsModerateEffect),
              abs(stepsModerateEffect) <= abs(stepsHighEffect),
              abs(stepsHighEffect) <= abs(stepsVeryHighEffect) else { return false }

        // Threshold ordering: HRV bands must be strictly ascending
        guard hrvLowBelow < hrvModerateBelow,
              hrvModerateBelow < hrvHighAbove else { return false }

        // HRV effect ordering: veryLow (low band) stress must produce >= effect magnitude than low (moderate band)
        guard abs(hrvLowEffect) >= abs(hrvModerateEffect) else { return false }

        // Threshold ordering: exercise bands must be strictly ascending
        guard exerciseModerateMin < exerciseSubstantialMin,
              exerciseSubstantialMin < exerciseHeavyMin else { return false }

        // Exercise effect ordering: more exercise must produce >= effect magnitude
        guard abs(exerciseModerateEffect) <= abs(exerciseSubstantialEffect),
              abs(exerciseSubstantialEffect) <= abs(exerciseHeavyEffect) else { return false }

        return true
    }
}

