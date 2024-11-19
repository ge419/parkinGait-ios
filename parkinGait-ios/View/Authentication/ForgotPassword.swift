//
//  ForgotPassword.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import SwiftUI

struct ForgotPassword: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email: String = ""
    
    let bgColor = Color(red: 0.8706, green: 0.8549, blue: 0.8235)
    
    var body: some View {
        ZStack{
            bgColor.ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Forgot Password?")
                    .multilineTextAlignment(.center)
                    .font(.largeTitle)
                
                Text("To reset your password, enter your email again and a link to reset your password will be sent.")
                    .padding()
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                Button {
                    Task {
                        try await viewModel.forgotPassword(withEmail: email)
                    }
                } label: {
                    Text("Send Reset Link")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(!formIsValid)
                .opacity(formIsValid ? 1.0 : 0.5)
                
                //            Button(action: handleResetPassword) {
                //                Text("Reset Password")
                //                    .fontWeight(.bold)
                //                    .frame(maxWidth: .infinity)
                //                    .padding()
                //                    .background(Color.green)
                //                    .foregroundColor(.white)
                //                    .cornerRadius(8)
                //            }
                Spacer()
            }.padding()
        }
    }
}

extension ForgotPassword: AuthenticationFormProtocol {
    var formIsValid: Bool {
        let regex = try! NSRegularExpression(pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [.caseInsensitive])
        return !email.isEmpty
        &&
        regex.firstMatch(in: email, options: [], range: NSRange(location: 0, length: email.utf16.count)) != nil
    }
}

#Preview {
    ForgotPassword()
}
