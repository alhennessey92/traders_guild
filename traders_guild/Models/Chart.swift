//
//  Symbols.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

import Foundation






struct Symbol: Identifiable, Codable, Equatable {
    let id: UUID
    let symbol: String           // e.g. "AAPL"
    let fullName: String?     // optional, e.g. "Apple Inc."
    let addedDate: Date
    let notes: String?
    
    init(
        id: UUID = UUID(),
        symbol: String,
        fullName: String? = nil,
        addedDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.fullName = fullName
        self.addedDate = addedDate
        self.notes = notes
    }
}
