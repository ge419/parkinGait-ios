//
//  Register.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import SwiftUI

struct Register: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var height = ""
    
    let bgColor = Color(red: 0.8706, green: 0.8549, blue: 0.8235)
    
    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            
            VStack {
                Text("Registration")
                    .font(.largeTitle)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    ZStack(alignment: .trailing){
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        if !password.isEmpty && !confirmPassword.isEmpty {
                            if password == confirmPassword {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.large)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(.systemGreen))
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .imageScale(.large)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(
                                        .systemRed))
                            }
                        }
                    }
                    
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Height (inches)", text: $height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                .padding()
                Button {
                    Task {
                        try await viewModel.createUser(withEmail: email, password: password, name: name, height: height)
                    }
                } label: {
                    Text("Register")
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
                Spacer()
            }
            
        }
    }
}

extension Register: AuthenticationFormProtocol {
    var formIsValid: Bool {
        let regex = try! NSRegularExpression(pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}", options: [.caseInsensitive])
        return !email.isEmpty
        &&
        regex.firstMatch(in: email, options: [], range: NSRange(location: 0, length: email.utf16.count)) != nil
        && !password.isEmpty
        && !confirmPassword.isEmpty
        && password == confirmPassword
        && !name.isEmpty
        && !height.isEmpty
        && height.range(
            of: "^[0-9]*$",
            options: .regularExpression) != nil
    }
}

#Preview {
    Register()
}
