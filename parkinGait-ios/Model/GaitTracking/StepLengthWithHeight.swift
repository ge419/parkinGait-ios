//
//  StepLengthCalculatorV2.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//


import Foundation
import simd
import Charts

/// A calculator for determining step length using user height.
///
/// Utilizing stride frequency and vairance of accelerometer data.
class StepLengthWithHeight {
    private let METERS_TO_INCHES: Double = 39.3701
    private var recentAccelData: [Double] = []
    private var peakTimes: [Double] = []

    /// Updates the accelerometer data and calculates step length.
    ///
    /// - Parameters:
    ///   - accelMagnitude: The magnitude of the accelerometer data.
    ///   - height: The user's height in meters.
    /// - Returns: The calculated step length in inches, or 0 if insufficient data.
    func calculateStepLength(accelMagnitude: Double, height: Double) -> Double {
        // Add the new accelerometer magnitude to the recent data
        recentAccelData.append(accelMagnitude)

        // Limit the size of the recent data to avoid memory issues
        let windowSize = 50
        if recentAccelData.count > windowSize {
            recentAccelData.removeFirst()
        }

        // Ensure enough data is collected to calculate step length
        guard recentAccelData.count > 1 else {
            return 0
        }

        // Calculate stride frequency using peak times
        let strideFrequency: Double
        if let lastStepTime = peakTimes.last {
            let currentTime = Date().timeIntervalSince1970
            strideFrequency = 1.0 / (currentTime - lastStepTime)
        } else {
            strideFrequency = 0
        }

        // Calculate the mean of the accelerometer data
        let meanAccel = recentAccelData.reduce(0.0, +) / Double(recentAccelData.count)

        // Calculate the variance of the accelerometer data
        let variance = recentAccelData.reduce(0.0) { acc, val in
            acc + pow(val - meanAccel, 2)
        } / Double(recentAccelData.count - 1)

        // Use the stride frequency, variance, and height to calculate step length
        let stepLength = height * (-0.69290106 * strideFrequency + 0.15647773 * variance + 0.1321038) + 0.6110578

        // Convert the step length to inches
        return stepLength * METERS_TO_INCHES
    }

    /// Records a step detected based on peak times.
    ///
    /// - Parameter timestamp: The timestamp of the detected peak.
    func recordStep(timestamp: TimeInterval) {
        peakTimes.append(timestamp)

        // Keep only the most recent peak
        if peakTimes.count > 2 {
            peakTimes.removeFirst()
        }
    }
}
