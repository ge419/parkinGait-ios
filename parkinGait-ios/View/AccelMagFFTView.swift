//
//  AccelMagFFTView.swift
//  parkinGait-ios
//
//  Created by 신창민 on 1/28/25.
//

import SwiftUI
import CoreMotion
import Charts

struct AccelMagFFTView: View {
    @StateObject private var accelMagFFT = AccelMagFFT()
    @State private var isWalking = false
    private var motionManager = CMMotionManager()

    var body: some View {
        VStack {
            Text(accelMagFFT.recommendation)
                .font(.headline)
                .foregroundColor(.blue)
                .padding()

            Button(action: toggleIMU) {
                Text(isWalking ? "Stop Tracking" : "Start Tracking")
                    .font(.title2)
                    .padding()
                    .background(isWalking ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if !accelMagFFT.filteredData.isEmpty {
                Chart {
                    ForEach(accelMagFFT.filteredData.indices, id: \.self) { index in
                        LineMark(
                            x: .value("Time", accelMagFFT.filteredData[index].timestamp),
                            y: .value("Filtered Acceleration", accelMagFFT.filteredData[index].accelMagnitude)
                        )
                    }
                }
                .frame(height: 200)
                .padding()
            }

            Button(action: accelMagFFT.analyzeSteps) {
                Text("Analyze Steps")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    private func toggleIMU() {
        isWalking.toggle()
    }
}

#Preview {
    AccelMagFFTView()
}
