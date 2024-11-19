//
//  EditProfile.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import SwiftUI

struct EditProfile: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var name: String = ""
    @State private var height: String = ""
    let appearance = UINavigationBarAppearance()
    
    var body: some View {
        
        VStack(alignment: .leading) {
            Text("Name")
                .font(.body)
            TextField("Name", text: $name)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            Text("Height")
            TextField("Height", text: $height)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            Button {
                Task {
                    try await viewModel.updateUser(name: name, height: height)
                }
            } label: {
                Text("Update Profile")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }.padding()
            Spacer()
        }
        .padding()
        .onAppear {
            if let user = viewModel.currentUser {
                name = user.name
                height = user.height
            }
        }
        .navigationTitle("Edit Profile")
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Profile Update"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}



#Preview {
    EditProfile()
}
