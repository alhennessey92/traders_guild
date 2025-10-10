//
//  Symbols.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

import Foundation

struct Symbol: Identifiable, Codable, Equatable {
    let id: UUID
    let ticker: String
    let symbol: String           // e.g. "AAPL"
    let fullName: String?     // optional, e.g. "Apple Inc."
    let addedDate: Date
    let notes: String?
    
    init(
        id: UUID = UUID(),
        ticker: String,
        symbol: String,
        fullName: String? = nil,
        addedDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.ticker = ticker
        self.symbol = symbol
        self.fullName = fullName
        self.addedDate = addedDate
        self.notes = notes
    }
}

// SAMPLE DATA

struct SymbolIDs {
    static let eurusd = UUID()
    static let audusd = UUID()
    static let gold = UUID()

}

// Symbols
extension Symbol {
    static let sampleSymbol: [Symbol] = [
        Symbol(
            id: SymbolIDs.eurusd,
            ticker: "EURUSD",
            symbol: "EUR/USD",
            fullName: "Euro / US Dollar",
            addedDate: Date().addingTimeInterval(-3600),
            notes: "Forex" // 1 hour ago
            
        ),
        
        Symbol(
            id: SymbolIDs.audusd,
            ticker: "AUDUSD",
            symbol: "AUD/USD",
            fullName: "Australian Dollar / US Dollar",
            addedDate: Date().addingTimeInterval(-3600),
            notes: "Forex" // 1 hour ago
            
        ),
        Symbol(
            id: SymbolIDs.gold,
            ticker: "GOLD",
            symbol: "Gold",
            fullName: "Gold",
            addedDate: Date().addingTimeInterval(-3600),
            notes: "Commodities" // 1 hour ago
            
        )
    ]
}


