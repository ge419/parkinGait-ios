//
//  Filter.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import simd

class Filter {
    var fc: Float = 0.0
    var fs: Float = 0.0
    var alpha: Float = 0.0
    var tau: Float = 0.0
    var prev: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    func begin(freqCutoff: Float, freqSampling: Float) {
        fc = freqCutoff
        fs = freqSampling
        tau = 1 / (2.0 * Float.pi * fc)
        alpha = (1.0 / fs) / (tau + (1.0 / fs))
        prev = SIMD3<Float>(0, 0, 0)
    }
    
    func step(vec: SIMD3<Float>) -> SIMD3<Float> {
        prev = prev + alpha * (vec - prev)
        return prev
    }
    
    func reset() {
        prev = SIMD3<Float>(0, 0, 0)
    }
}
