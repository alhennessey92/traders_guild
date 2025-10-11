//
//  Symbols.swift
//  traders_guild
//
//  Created by Al Hennessey on 09/10/2025.
//

import Foundation

// MARK: - Symbol Type
enum SymbolType: String, Codable {
    case forex = "Forex"
    case commodities = "Commodities"
    case stocks = "Stocks"
    case cryptocurrency = "Cryptocurrency"
}

// MARK: - Symbol Status
enum SymbolStatus: String, Codable {
    case open = "Open"
    case closed = "Closed"
}

// MARK: - Change Direction
enum ChangeDirection: String, Codable {
    case up = "+"
    case down = "-"
}




struct Symbol: Identifiable, Codable, Equatable {
    let id: UUID
    let ticker: String
    let symbol: String           // e.g. "AAPL"
    let fullName: String?     // optional, e.g. "Apple Inc."
    let addedDate: Date
    let notes: String?
    let symbolType: SymbolType
    let symbolStatus: SymbolStatus
    let currentPrice: Double
    let currentChange: Double
    let changeDirection: ChangeDirection
    
    init(
        id: UUID = UUID(),
        ticker: String,
        symbol: String,
        fullName: String? = nil,
        addedDate: Date = Date(),
        notes: String? = nil,
        symbolType: SymbolType,
        symbolStatus: SymbolStatus,
        currentPrice: Double,
        currentChange: Double = 0.0,
        changeDirection: ChangeDirection
        
    ) {
        self.id = id
        self.ticker = ticker
        self.symbol = symbol
        self.fullName = fullName
        self.addedDate = addedDate
        self.notes = notes
        self.symbolType = symbolType
        self.symbolStatus = symbolStatus
        self.currentPrice = currentPrice
        self.currentChange = currentChange
        self.changeDirection = changeDirection
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
            notes: "Forex", // 1 hour ago
            symbolType: .forex,
            symbolStatus: .open,
            currentPrice: 1.242342,
            currentChange: 45.342,
            changeDirection: .down
            
        ),
        
        Symbol(
            id: SymbolIDs.audusd,
            ticker: "AUDUSD",
            symbol: "AUD/USD",
            fullName: "Australian Dollar / US Dollar",
            addedDate: Date().addingTimeInterval(-3600),
            notes: "Forex",// 1 hour ago
            symbolType: .forex,
            symbolStatus: .closed,
            currentPrice: 2.342113,
            currentChange: 86.2342,
            changeDirection: .up
            
        
        ),
        Symbol(
            id: SymbolIDs.gold,
            ticker: "GOLD",
            symbol: "Gold",
            fullName: "Gold",
            addedDate: Date().addingTimeInterval(-3600),
            notes: "Commodities", // 1 hour ago
            symbolType: .commodities,
            symbolStatus: .open,
            currentPrice: 23.2342,
            currentChange: 34.4332,
            changeDirection: .up
            
        )
    ]
}


