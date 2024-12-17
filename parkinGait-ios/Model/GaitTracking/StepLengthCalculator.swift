//
//  StepLengthCalculator.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

/// Calculator for determining step length using IMU data. Algorithm from previous team using ZVU.
///
///

import Foundation
import CoreMotion
import simd
import Charts

class StepLengthCalculator {
    private let METERS_TO_INCHES: Float = 39.3701
    private let DISTANCE_THRESHOLD: Double = 3.0
    private let ACCEL_THRESH: Float = 1.0
    private let GYRO_THRESH: Float = 3.0
    
    private var velIntegral = Integral()
    private var posIntegral = Integral()
    private var dt = DeltaTime()
    private var zvu = ZVU()
    
    // Storage for all motion data (acceleration, gyroscope, step detection, etc.)
    private var gaitRecords: [GaitRecord] = []
    
    init() {
        zvu.begin(threshA: ACCEL_THRESH, threshB: GYRO_THRESH, sampleThresh: 30)
    }
    
    func startMotionTracking(timestamp: TimeInterval) {
        dt.first = timestamp
        dt.set(ts: timestamp)
    }
    
    func processMotionData(accel: SIMD3<Float>, gyro: SIMD3<Float>, quaternion: CMQuaternion, timestamp: TimeInterval) -> Double? {
        // Gravity compensation
        let gravity = getGravity(q: quaternion)
        let ag = projectAccelOnGravity(accel: accel, gravity: gravity) * METERS_TO_INCHES
        
        // Handle zero velocity update
        let notMoving = zvu.check(a: ag, b: gyro)
        var stepLength: Double? = nil
        
        if notMoving {
            resetPos()
        } else {
            let deltaTime = dt.step(ts: timestamp)
            if deltaTime > 0 {
                let velocity = velIntegral.step(v: ag, dt: deltaTime)
                _ = posIntegral.step(v: velocity, dt: deltaTime)
                
                if Double(length(posIntegral.cum)) > DISTANCE_THRESHOLD {
                    stepLength = Double(length(posIntegral.cum))
                    resetVel()
                    resetPos()
                }
            }

        }
        
        // Store all motion data along with step detection
        let gaitRecord = GaitRecord(
            timestamp: timestamp,
            accelX: Double(ag.x),
            accelY: Double(ag.y),
            accelZ: Double(ag.z),
            gyroX: Double(gyro.x),
            gyroY: Double(gyro.y),
            gyroZ: Double(gyro.z),
            stepDetected: stepLength != nil,
            stepLength: stepLength
        )
        gaitRecords.append(gaitRecord)
        
        return stepLength
    }
    
    func exportGaitData(fileName: String) -> URL? {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var csvText = "Timestamp,AccelX,AccelY,AccelZ,GyroX,GyroY,GyroZ,StepDetected,StepLength\n"
        
        for record in gaitRecords {
            csvText.append("\(record.timestamp),\(record.accelX),\(record.accelY),\(record.accelZ),\(record.gyroX),\(record.gyroY),\(record.gyroZ),\(record.stepDetected ? "Yes" : "No"),\(record.stepLength != nil ? String(record.stepLength!) : "")\n")
        }
        
        do {
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            print("Failed to write CSV: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func resetPos() {
        velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        posIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        dt.set(ts: 0)
    }
    
    private func resetVel() {
        velIntegral.reset(vec: SIMD3<Float>(0, 0, 0))
        posIntegral.resetPrev(vec: SIMD3<Float>(0, 0, 0))
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
