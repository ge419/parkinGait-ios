//
//  UserCalibration.swift
//  parkinGait-ios
//
//  Created by 신창민 on 12/17/24.
//


import Foundation

struct UserCalibration: Identifiable, Codable {
    let id: String
    let gaitConstant: Double
    let threshold: Double
    let goalStep: String
    let placement: String
}
