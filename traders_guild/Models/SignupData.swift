//
//  SignupData.swift
//  traders_guild
//
//  Created by Al Hennessey on 16/09/2025.
//

import Foundation

// Holds all the data collected during the multi-step signup wizard
// We store this centrally in SignupCoordinator and pass via @Binding to each step view
struct SignupData {
    var name: String = ""          // Full name
    var email: String = ""         // Email address
    var dob: Date = Date()         // Date of birth
    var password: String = ""      // Password chosen by user
    var username: String = ""      // Chosen username
    var topics: [String] = []      // List of favorite topics selected by user
    var guild: String = ""         // First guild user joins
}
