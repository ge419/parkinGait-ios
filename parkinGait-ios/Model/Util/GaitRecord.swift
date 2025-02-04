//
//  GaitRecord.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/17/24.
//

import Foundation


struct GaitRecord {
    let timestamp: TimeInterval
    let accelX: Double
    let accelY: Double
    let accelZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
//    let accelMagnitude: Double
//    let filteredAccelMagnitude: Double
    let stepDetected: Bool
    let stepLength: Double?
}

