//
//  Integral.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import simd

class Integral {
    var cum: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var prev: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    func begin(vec: SIMD3<Float>) {
        reset(vec: vec)
    }
    
    func step(v: SIMD3<Float>, dt: Float) -> SIMD3<Float> {
        cum += (v + prev) * 0.5 * dt
        prev = v
        return cum
    }
    
    func reset(vec: SIMD3<Float>) {
        resetPrev(vec: vec)
        cum = SIMD3<Float>(0, 0, 0)
    }
    
    func resetPrev(vec: SIMD3<Float>) {
        prev = vec
    }
}
