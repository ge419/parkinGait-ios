//
//  CSVExportHelper.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import Foundation

/// A utility to export collected gait data to a CSV file.
struct GaitData {
    let timestamp: Double
    let accelX: Double
    let accelY: Double
    let accelZ: Double
    let gyroX: Double
    let gyroY: Double
    let gyroZ: Double
    let stepLength: Double
}

/// Exports gait data to a CSV file and returns the file URL.
func exportToCSV(data: [GaitData], fileName: String) -> URL? {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
    
    var csvText = "Timestamp,AccelX,AccelY,AccelZ,GyroX,GyroY,GyroZ,StepLength\n"
    
    for entry in data {
        let row = "\(entry.timestamp),\(entry.accelX),\(entry.accelY),\(entry.accelZ),\(entry.gyroX),\(entry.gyroY),\(entry.gyroZ),\(entry.stepLength)\n"
        csvText.append(row)
    }
    
    do {
        try csvText.write(to: path, atomically: true, encoding: .utf8)
        return path
    } catch {
        print("Failed to write CSV: \(error.localizedDescription)")
        return nil
    }
}

