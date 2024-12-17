//
//  AccelMag.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/17/24.
//

import Foundation
import CoreMotion
import simd
import Charts

class AccelMag {
    private let METERS_TO_INCHES: Float = 39.3701
    private let ACCEL_THRESHOLD: Float = 10.0
    private let MIN_DELTA_TIME: TimeInterval = 0.5  // Minimum step duration (seconds)

    private var cumulativeVelocity: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var cumulativePosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    private var lastTimestamp: TimeInterval?
    
    private var velIntegral = Integral()
    private var posIntegral = Integral()
    private var dt = DeltaTime()

    private var stepCount: Int = 0
    private var stepTimes: [TimeInterval] = []

    // Low-pass filtering state
    private var filteredAccelMagnitude: Double = 0.0
    private let SMOOTHING_FACTOR: Double = 0.2

    // Step detection states
    private var positiveSparkDetected: Bool = false
    private var stepStartTime: TimeInterval?
    private var gaitRecords: [AccelRecord] = []

    func startMotionTracking(timestamp: TimeInterval) {
        dt.first = timestamp
        dt.set(ts: timestamp)
    }

    func processAcceleration(accel: SIMD3<Float>, gyro: SIMD3<Float>, quaternion: CMQuaternion, timestamp: TimeInterval) -> Double? {
        let gravity = getGravity(q: quaternion)
        let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * METERS_TO_INCHES
        let accelMagnitude = Double(length(ag))  // Use raw acceleration magnitude directly
        
        print("Raw Accel Magnitude: \(accelMagnitude)")

        var stepLength: Double? = nil

        if let previousTime = lastTimestamp {
            let deltaTimeFloat = Float(timestamp - previousTime)
            cumulativeVelocity = velIntegral.step(v: ag, dt: deltaTimeFloat)
            cumulativePosition = posIntegral.step(v: cumulativeVelocity, dt: deltaTimeFloat)
        }
        lastTimestamp = timestamp

        // Step detection logic with positive and negative sparks
        if accelMagnitude > Double(ACCEL_THRESHOLD) && !positiveSparkDetected {
            // Positive spark detected
            positiveSparkDetected = true
            stepStartTime = timestamp
        } else if accelMagnitude < Double(ACCEL_THRESHOLD) && positiveSparkDetected {
            // Negative spark detected
            positiveSparkDetected = false

            if let startTime = stepStartTime {
                let deltaTime = timestamp - startTime
                if deltaTime > 2.0 {
                    // If the step duration is too long, ignore it
                    print("Step ignored: ΔTime = \(deltaTime) seconds (too long)")
                } else if deltaTime > MIN_DELTA_TIME {
                    // Valid step detected
                    stepLength = Double(length(cumulativePosition))
                    print("Step Detected: ΔTime = \(deltaTime), Step Length = \(stepLength!) inches")

                    stepCount += 1
                    stepTimes.append(timestamp)
//                    resetIntegration()
                }
                resetIntegration()
                stepStartTime = nil  // Reset step start time
                
            }
        }

        // Store all motion data regardless of step detection
        let accelRecord = AccelRecord(
            timestamp: timestamp,
            accelX: Double(ag.x),
            accelY: Double(ag.y),
            accelZ: Double(ag.z),
            accelMagnitude: accelMagnitude,
            gyroX: Double(gyro.x),
            gyroY: Double(gyro.y),
            gyroZ: Double(gyro.z),
            stepDetected: stepLength != nil,
            stepLength: stepLength
        )
        gaitRecords.append(accelRecord)

        return stepLength
    }


    private func applyLowPassFilter(newValue: Double, previousValue: Double) -> Double {
        return SMOOTHING_FACTOR * newValue + (1 - SMOOTHING_FACTOR) * previousValue
    }

    private func resetIntegration() {
        cumulativeVelocity = SIMD3<Float>(0, 0, 0)
        cumulativePosition = SIMD3<Float>(0, 0, 0)
        velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        posIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
    }
    
    public func resetAllIntegrations() {
        resetIntegration()
    }

    func exportGaitData(fileName: String) -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvText = "Timestamp,AccelX,AccelY,AccelZ,AccelMagnitude,GyroX,GyroY,GyroZ,StepDetected,StepLength\n"

        for record in gaitRecords {
            csvText.append("\(record.timestamp),\(record.accelX),\(record.accelY),\(record.accelZ),\(record.accelMagnitude),\(record.gyroX),\(record.gyroY),\(record.gyroZ),\(record.stepDetected ? "Yes" : "No"),\(record.stepLength != nil ? String(record.stepLength!) : "")\n")
        }

        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }

    private func getGravity(q: CMQuaternion) -> SIMD3<Float> {
        let r0 = 2 * Float(q.w * q.z - q.x * q.y)
        let r1 = 2 * Float(q.y * q.z + q.w * q.x)
        let r2 = Float(q.w * q.w - q.x * q.x - q.y * q.y + q.z * q.z)
        return SIMD3<Float>(r0, r1, r2)
    }

    private func projectAccelOnGravity(accel: SIMD3<Float>, gravity: SIMD3<Float>) -> SIMD3<Float> {
        return accel - dot(accel, gravity) * gravity
    }
}

struct AccelRecord {
    let timestamp: TimeInterval
    let accelX: Double
    let accelY: Double
    let accelZ: Double
    let accelMagnitude: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    let stepDetected: Bool
    let stepLength: Double?
}

