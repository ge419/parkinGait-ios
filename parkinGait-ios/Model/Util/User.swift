//
//  User.swift
//  parkinGait-ios
//
//  Created by 신창민 on 11/19/24.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let name: String
    let height: String
}
