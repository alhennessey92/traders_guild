//
//  UserStore.swift
//  traders_guild
//
//  Created by Al Hennessey on 05/10/2025.
//

import Foundation

class UserStore: ObservableObject {
    @Published var user: User?
    
    init(user: User? = nil) {
        self.user = user
    }
    
    func login(user: User) {
        self.user = user
    }
    
    func logout() {
        self.user = nil
    }
}
