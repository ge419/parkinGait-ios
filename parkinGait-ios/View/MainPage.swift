//
//  MainPage.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import SwiftUI

/// A navigation hub for accessing various gait tracking models and app features.
///
/// The `MainPage` acts as the central view for navigating to different step tracking models
/// and other functionalities such as editing the user profile or calibration.
struct MainPage: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Gait Tracker Home Page")
                    .font(.largeTitle)
                    .padding(.top, 20)
                
                // Navigation links to different gait tracking models
                NavigationLink(destination: StepLengthCalculatorView()) {
                    Text("Step Length Calculator")
                        .font(.title2)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: StepCounterView()) {
                    Text("Step Counter")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: StepLengthWithHeightView()) {
                    Text("Step Length With Height")
                        .font(.title2)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                NavigationLink(destination: DynamicStepLengthCounterView()) {
                    Text("DynamicStepcounter")
                        .font(.title2)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: AccelMagView()) {
                    Text("Accleration Magnitude")
                        .font(.title2)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: AccelMagFFTView()) {
                    Text("Accleration Magnitude")
                        .font(.title2)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                
                NavigationLink(destination: EditProfile()) {
                    Text("Change User Information")
                        .font(.title2)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                NavigationLink(destination: Calibration()) {
                    Text("Recalibrate")
                        .font(.title2)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    AuthViewModel().signOut()
                }) {
                    Text("Sign Out")
                        .font(.title2)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Main Page")
        }
    }
}

#Preview {
    MainPage()
}
