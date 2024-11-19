//
//  ZVU.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import simd

class ZVU {
    var samples: Int = 0
    var sampleThresh: Int = 0
    var threshA: Float = 0.0
    var threshB: Float = 0.0
    
    func begin(threshA: Float, threshB: Float, sampleThresh: Int) {
        self.threshA = threshA
        self.threshB = threshB
        self.sampleThresh = sampleThresh
    }
    
    func check(a: SIMD3<Float>, b: SIMD3<Float>) -> Bool {
        if a.x < threshA && a.y < threshA && a.z < threshA {
            samples += 1
        } else {
            samples = 0
        }
        return samples > sampleThresh
    }
}
