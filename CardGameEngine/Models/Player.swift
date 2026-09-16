import Foundation

public struct Player: Identifiable, Codable {
    public let id: String
    public var name: String
    public var cards: [Card]
    public var rankOrder: Int? // 1 = First place, 2 = Second place...
    public var score: Int // Net score / chips / points
    public var resultTitle: String // "Thắng trắng: Sảnh Rồng", "Liêng 9-10-J", "Cù Lũ Át"
    public var resultDetail: String // Detailed explanation / Kicker / Chi comparison
    public var isLung: Bool // For Binh: true if hand is invalid (lung)
    
    public init(id: String = UUID().uuidString, name: String, cards: [Card] = []) {
        self.id = id
        self.name = name
        self.cards = cards
        self.rankOrder = nil
        self.score = 0
        self.resultTitle = ""
        self.resultDetail = ""
        self.isLung = false
    }
    
    public mutating func clearCards() {
        self.cards.removeAll()
        self.rankOrder = nil
        self.score = 0
        self.resultTitle = ""
        self.resultDetail = ""
        self.isLung = false
    }
}
