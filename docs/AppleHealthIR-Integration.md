# Apple Health Biometric IR Integration Guide

This document explains how to wire the new `AppleHealthIR` components into the
existing Loop app.

## 1. Instantiate Services in DeviceDataManager / LoopAppManager

Create the service objects once at app startup (singleton pattern):

```swift
// In DeviceDataManager.swift (or LoopAppManager.swift)

let biometricsService = BiometricsService()
let irService = BaseAppleHealthIRService()
let irObservable = AppleHealthIRServiceObservable(
    irService: irService,
    biometricsService: biometricsService
)
```

Keep these as stored properties so they remain alive for the app lifetime.

## 2. Apply IR Multiplier in LoopDataManager

Search for the two locations in `LoopDataManager.swift` where
`insulinSensitivity` (an `InsulinSensitivitySchedule` value) is used to
compute a dose or effect (approximately lines ~1542 and ~1640).

At each location, multiply the sensitivity value by the current IR factor:

```swift
// Before:
let sensitivity = insulinSensitivitySchedule.quantity(at: date)

// After:
let baselineSensitivity = insulinSensitivitySchedule.quantity(at: date)
let irMultiplier = DeviceDataManager.shared.irService.multiplier
let sensitivity = HKQuantity(
    unit: baselineSensitivity.unit,
    doubleValue: baselineSensitivity.doubleValue(for: baselineSensitivity.unit) / irMultiplier
)
```

Note: Dividing sensitivity by the multiplier means elevated resistance
(multiplier > 1.0) reduces effective sensitivity, causing Loop to recommend
more insulin — the physiologically correct behaviour.

## 3. Add BiometricHomePanel to the Home Screen

In `HomeViewController.swift` (or equivalent SwiftUI root view):

```swift
// SwiftUI
BiometricHomePanel(service: DeviceDataManager.shared.irObservable)
    .padding(.horizontal)
```

Or in the existing UIKit stack controller, host it via `UIHostingController`.

## 4. Add Thresholds Settings Entry Point

Navigate to the settings screen by presenting `AppleHealthIRThresholdsView`:

```swift
NavigationLink("IR Thresholds") {
    AppleHealthIRThresholdsView()
}
```

## 5. HealthKit Entitlement Additions

Add the following five types to the `NSHealthShareUsageDescription` array in
`Info.plist` and to the HealthKit capability in the project target:

| Quantity / Category Type         | Identifier                                      |
|----------------------------------|-------------------------------------------------|
| Sleep Analysis                   | `HKCategoryTypeIdentifierSleepAnalysis`         |
| Step Count                       | `HKQuantityTypeIdentifierStepCount`             |
| HRV SDNN                         | `HKQuantityTypeIdentifierHeartRateVariabilitySDNN` |
| Apple Exercise Time              | `HKQuantityTypeIdentifierAppleExerciseTime`     |
| Heart Rate                       | `HKQuantityTypeIdentifierHeartRate`             |

In `Info.plist`, extend `NSHealthShareUsageDescription`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Loop uses sleep, steps, HRV, exercise, and heart-rate data from
Apple Health to adjust insulin sensitivity recommendations.</string>
```

## 6. Background Delivery

`BiometricsService` calls `enableBackgroundDelivery(for:frequency:)` for all
five types automatically after authorisation. No additional entitlement changes
are needed beyond the standard `healthkit` background mode, which should
already be present in the Loop entitlements file.
