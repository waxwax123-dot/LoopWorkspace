// AppleHealthIRServiceTests.swift
// Loop Tests
//
// XCTestCase covering deterministic delta computation and multiplier clamping.

import XCTest
@testable import Loop

final class AppleHealthIRServiceTests: XCTestCase {

    var service: BaseAppleHealthIRService!

    override func setUp() {
        super.setUp()
        // Ensure we use factory defaults for deterministic tests
        AppleHealthIRThresholds.resetToDefaults()
        service = BaseAppleHealthIRService()
    }

    override func tearDown() {
        AppleHealthIRThresholds.resetToDefaults()
        super.tearDown()
    }

    // MARK: - Default multiplier

    func testDefaultMultiplier() {
        XCTAssertEqual(service.multiplier, 1.0, accuracy: 0.001,
                       "Initial multiplier should be 1.0")
    }

    // MARK: - Nil inputs return 0

    func testNilSleepReturnsZero() {
        XCTAssertEqual(service.computeSleepDelta(nil), 0)
    }

    func testNilStepsReturnsZero() {
        XCTAssertEqual(service.computeStepsDelta(nil), 0)
    }

    func testNilHRVReturnsZero() {
        XCTAssertEqual(service.computeHRVDelta(nil), 0)
    }

    func testNilExerciseReturnsZero() {
        XCTAssertEqual(service.computeExerciseDelta(nil), 0)
    }

    // MARK: - Sleep delta

    func testSleepDelta_BelowSevere() {
        // Below severeBellow (4.0 h) -> severe effect (40%)
        let delta = service.computeSleepDelta(2.0)
        XCTAssertEqual(delta, AppleHealthIRThresholds.defaults.sleepSevereEffect, accuracy: 0.01)
    }

    func testSleepDelta_BetweenSevereAndSubstantial() {
        let t = AppleHealthIRThresholds.defaults
        // Midpoint between 4.0 and 5.5 -> midpoint between 40% and 25% = 32.5%
        let midHours = (t.sleepSevereBelow + t.sleepSubstantialBelow) / 2
        let expected = (t.sleepSevereEffect + t.sleepSubstantialEffect) / 2
        let delta = service.computeSleepDelta(midHours)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testSleepDelta_AboveMild() {
        // At or above mildBelow (7.5 h) -> baseline (0%)
        let delta = service.computeSleepDelta(9.0)
        XCTAssertEqual(delta, 0, accuracy: 0.001)
    }

    func testSleepDelta_EqualToSevereThreshold_Interpolates() {
        // Exactly at severeBellow boundary -> interpolation starts (should not be 40% anymore)
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeSleepDelta(t.sleepSevereBelow)
        // At the lower bound of the [severe, substantial] band -> should be severeEffect
        XCTAssertEqual(delta, t.sleepSevereEffect, accuracy: 0.01)
    }

    func testSleepDelta_BetweenModerateAndMild() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.sleepModerateBelow + t.sleepMildBelow) / 2
        let expected = (t.sleepModerateEffect + t.sleepMildEffect) / 2
        let delta = service.computeSleepDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    // MARK: - Steps delta

    func testStepsDelta_BelowLowMin() {
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeStepsDelta(500)
        XCTAssertEqual(delta, t.stepsLowEffect, accuracy: 0.01)
    }

    func testStepsDelta_ModerateRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.stepsLowMin + t.stepsModerateMin) / 2
        let expected = (t.stepsLowEffect + t.stepsModerateEffect) / 2
        let delta = service.computeStepsDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testStepsDelta_HighRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.stepsModerateMin + t.stepsHighMin) / 2
        let expected = (t.stepsModerateEffect + t.stepsHighEffect) / 2
        let delta = service.computeStepsDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testStepsDelta_VeryHighRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.stepsHighMin + t.stepsVeryHighMin) / 2
        let expected = (t.stepsHighEffect + t.stepsVeryHighEffect) / 2
        let delta = service.computeStepsDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testStepsDelta_AboveVeryHighMin() {
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeStepsDelta(t.stepsVeryHighMin + 5000)
        XCTAssertEqual(delta, t.stepsVeryHighEffect, accuracy: 0.01)
    }

    // MARK: - HRV delta

    func testHRVDelta_LowRange() {
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeHRVDelta(10.0)
        XCTAssertEqual(delta, t.hrvLowEffect, accuracy: 0.01)
    }

    func testHRVDelta_ModerateRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.hrvLowBelow + t.hrvModerateBelow) / 2
        let expected = (t.hrvLowEffect + t.hrvModerateEffect) / 2
        let delta = service.computeHRVDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testHRVDelta_NormalRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.hrvModerateBelow + t.hrvHighAbove) / 2
        let expected = (t.hrvModerateEffect + t.hrvNormalEffect) / 2
        let delta = service.computeHRVDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testHRVDelta_HighRange() {
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeHRVDelta(t.hrvHighAbove + 10)
        XCTAssertEqual(delta, t.hrvHighEffect, accuracy: 0.01)
    }

    // MARK: - Exercise delta

    func testExerciseDelta_BelowModerateMin() {
        let delta = service.computeExerciseDelta(5.0)
        XCTAssertEqual(delta, 0, accuracy: 0.001)
    }

    func testExerciseDelta_ModerateRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.exerciseModerateMin + t.exerciseSubstantialMin) / 2
        let expected = (0 + t.exerciseModerateEffect) / 2
        let delta = service.computeExerciseDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testExerciseDelta_SubstantialRange() {
        let t = AppleHealthIRThresholds.defaults
        let mid = (t.exerciseSubstantialMin + t.exerciseHeavyMin) / 2
        let expected = (t.exerciseModerateEffect + t.exerciseSubstantialEffect) / 2
        let delta = service.computeExerciseDelta(mid)
        XCTAssertEqual(delta, expected, accuracy: 0.1)
    }

    func testExerciseDelta_HeavyRange() {
        let t = AppleHealthIRThresholds.defaults
        let delta = service.computeExerciseDelta(t.exerciseHeavyMin + 30)
        XCTAssertEqual(delta, t.exerciseHeavyEffect, accuracy: 0.01)
    }

    // MARK: - Multiplier clamping

    func testMultiplierFloor() {
        // Very long sleep + high HRV + lots of steps + heavy exercise -> floor at 0.5
        let snapshot = BiometricsSnapshot(
            sleepHours: 12.0,       // -> 0%
            stepCount: 30_000,      // -> -15%
            hrvSDNN: 120.0,         // -> -10%
            exerciseMinutes: 200.0  // -> -20%
        )
        service.update(snapshot: snapshot)
        XCTAssertGreaterThanOrEqual(service.multiplier, 0.5,
                                    "Multiplier must not go below floor of 0.5")
    }

    func testMultiplierCeiling() {
        // Severe sleep deficit + very low HRV + minimal steps + no exercise -> ceiling at 2.0
        let snapshot = BiometricsSnapshot(
            sleepHours: 1.0,    // -> 40%
            stepCount: 0,       // -> 10%
            hrvSDNN: 5.0,       // -> 15%
            exerciseMinutes: 0  // -> 0%
        )
        service.update(snapshot: snapshot)
        XCTAssertLessThanOrEqual(service.multiplier, 2.0,
                                  "Multiplier must not exceed ceiling of 2.0")
    }

    func testMultiplierBaseline() {
        // Optimal biometrics -> multiplier near 1.0 (or at least within [0.5, 2.0])
        let snapshot = BiometricsSnapshot(
            sleepHours: 8.0,
            stepCount: 10_000,
            hrvSDNN: 55.0,
            exerciseMinutes: 30.0
        )
        service.update(snapshot: snapshot)
        XCTAssertGreaterThanOrEqual(service.multiplier, 0.5)
        XCTAssertLessThanOrEqual(service.multiplier, 2.0)
    }
}
