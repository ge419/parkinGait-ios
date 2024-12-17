//
//  AuthViewModel.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//


import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var currentCalibration: UserCalibration?
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var calibrationFetched: Bool = false

    
    init() {
        self.userSession = Auth.auth().currentUser
        Task {
            await fetchUser()
            await fetchCalibration() // not sure if its right
        }
    }
    
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("DEBUG: Successfully signed in: \(result.user.uid)")
            self.userSession = result.user
            await fetchUser()
        } catch {
            print("DEBUG: Failed to sign in: \(error.localizedDescription)")
            throw error
        }
    }
    
    func createUser(withEmail email: String, password: String, name: String, height: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, email: email, name: name, height: height)
            let ref = Database.database().reference().child("users").child(user.id)
            try await ref.setValue([
                "email": email,
                "name": name,
                "height": height
            ])
            //            let encodedUser = try Firestore.Encoder().encode(user)
            //            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
            await fetchUser()
        } catch {
            print("DEBUG: Failed to create user with error \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("DEBUG: Failed to sign out with error \(error.localizedDescription)")
        }
    }
    
    func forgotPassword(withEmail email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            print("DEBUG: Failed to send password reset with error \(error.localizedDescription)")
        }
    }
    
    func updateUser(name: String? = nil, height: String? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        var updates: [String: Any] = [:]
        
        if let name = name {
            updates["name"] = name
        }
        
        if let height = height {
            updates["height"] = height
        }
        
        guard !updates.isEmpty else { return }
        
        do {
            //            try await Firestore.firestore().collection("users").document(uid).updateData(updates)
            let ref = Database.database().reference().child("users").child(uid)
            try await ref.updateChildValues(updates)
            self.alertMessage = "Successfully updated profile."
            self.showAlert = true
            await fetchUser()
        } catch {
            self.alertMessage = "Failed to update profile."
            self.showAlert = true
            print("DEBUG: Failed to update user with error \(error.localizedDescription)")
        }
    }
    
    
    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        //        guard let snapshot = try? await Firestore.firestore().collection("users").document(uid).getDocument() else { return }
        //        self.currentUser = try? snapshot.data(as: User.self)
        //        print("DEBUG: Current user is \(self.currentUser)")
        
        let ref = Database.database().reference().child("users").child(uid)
        do {
            let snapshot = try await ref.getData()
            guard let data = snapshot.value as? [String: Any] else { return }
            self.currentUser = User(id: uid, email: data["email"] as? String ?? "", name: data["name"] as? String ?? "", height: data["height"] as? String ?? "")
            print("DEBUG: Current user is \(String(describing: self.currentUser))")
        } catch {
            print("DEBUG: Failed to fetch user with error \(error.localizedDescription)")
        }
    }
    
    func fetchCalibration() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let ref = Database.database().reference().child("users").child(uid).child("Calibration")
        
        do {
            let snapshot = try await ref.getData()
            guard let data = snapshot.value as? [String: Any] else { return }
            self.currentCalibration = UserCalibration(id: uid, gaitConstant: data["gaitConstant"] as? Double ?? 0, threshold: data["Threshold"] as? Double ?? 0, goalStep: data["GoalStep"] as? String ?? "", placement: data["placement"] as? String ?? "")
            self.calibrationFetched = true
            print("DEBUG: Current user calibration is \(String(describing: self.currentCalibration))")
        } catch {
            print("DEBUG: Failed to fetch calibration with error \(error.localizedDescription)")
        }
    }
    
    func saveCalibration(gaitConstant: Double, threshold: Double, goalStep: String, placement: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let calData: [String: Any] = [
            "gaitConstant": gaitConstant,
            "Threshold": threshold,
            "GoalStep": goalStep,
            "Placement": placement
        ]
        
        do {
            let ref = Database.database().reference().child("users").child(uid).child("Calibration")
            try await ref.setValue(calData)
            self.alertMessage = "Successfully uploaded calibration."
            self.showAlert = true
            await fetchUser()
        } catch {
            self.alertMessage = "Failed to upload calibration."
            self.showAlert = true
            print("DEBUG: Failed to upload calibration data with error \(error.localizedDescription)")
        }
    }
    
    func updateStepLength(sec: String, stepLengthEst: Double) async {
//        func updateStepLength(sec: TimeInterval, stepLengthEst: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let ref = Database.database().reference().child("users").child(uid).child("StepLength")
            try await ref.setValue(["\(sec)": stepLengthEst])
            self.alertMessage = "Successfully uploaded Step Length."
            self.showAlert = true
            await fetchUser()
        } catch {
            self.alertMessage = "Failed to upload Step Length."
            self.showAlert = true
            print("DEBUG: Failed tp upload Step Length with error \(error.localizedDescription)")
        }
    }
}
