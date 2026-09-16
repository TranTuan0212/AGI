import Foundation

// MARK: - Suit Rule Preset
public enum SuitRulePreset: String, CaseIterable, Identifiable, Codable {
    case north = "Miền Bắc (♥ Cơ > ♦ Rô > ♣ Tép > ♠ Bích)"
    case southA = "Miền Nam - Bích Lớn (♠ Bích > ♦ Rô > ♥ Cơ > ♣ Tép)"
    case southB = "Miền Nam - Cơ Lớn (♥ Cơ > ♦ Rô > ♣ Tép > ♠ Bích)"
    case international = "Quốc Tế (Không so chất / Chia đều)"
    
    public var id: String { rawValue }
    
    public func suitValue(_ suit: Suit) -> Int {
        switch self {
        case .north, .southB:
            switch suit {
            case .spades: return 1   // Bích
            case .clubs: return 2    // Tép / Chuồn
            case .diamonds: return 3 // Rô
            case .hearts: return 4   // Cơ
            }
        case .southA:
            switch suit {
            case .clubs: return 1
            case .hearts: return 2
            case .diamonds: return 3
            case .spades: return 4
            }
        case .international:
            return 0 // All equal
        }
    }
}

// MARK: - Suit
public enum Suit: String, CaseIterable, Identifiable, Codable, Comparable {
    case spades = "♠"
    case clubs = "♣"
    case diamonds = "♦"
    case hearts = "♥"
    
    public var id: String { rawValue }
    
    public var nameVN: String {
        switch self {
        case .spades: return "Bích"
        case .clubs: return "Chuồn (Tép)"
        case .diamonds: return "Rô"
        case .hearts: return "Cơ"
        }
    }
    
    public var isRed: Bool {
        return self == .hearts || self == .diamonds
    }
    
    public static func < (lhs: Suit, rhs: Suit) -> Bool {
        return SuitRulePreset.north.suitValue(lhs) < SuitRulePreset.north.suitValue(rhs)
    }
}

// MARK: - Rank
public enum Rank: Int, CaseIterable, Identifiable, Codable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14
    
    public var id: Int { rawValue }
    
    public var displaySymbol: String {
        switch self {
        case .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten:
            return "\(rawValue)"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }
    
    // Value in 3 Cây / Liêng (A=1, 2-9=number, 10,J,Q,K=0)
    public var liengPoint: Int {
        switch self {
        case .two, .three, .four, .five, .six, .seven, .eight, .nine:
            return rawValue
        case .ace:
            return 1
        case .ten, .jack, .queen, .king:
            return 0
        }
    }
    
    public static func < (lhs: Rank, rhs: Rank) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Card
public struct Card: Identifiable, Hashable, Codable, Comparable {
    public let suit: Suit
    public let rank: Rank
    
    public var id: String {
        return "\(rank.displaySymbol)\(suit.rawValue)"
    }
    
    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }
    
    public var displayName: String {
        return "\(rank.displaySymbol)\(suit.rawValue)"
    }
    
    public static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank < rhs.rank
        }
        return lhs.suit < rhs.suit
    }
    
    // Create standard 52 deck
    public static var fullDeck52: [Card] {
        var deck = [Card]()
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(rank: rank, suit: suit))
            }
        }
        return deck
    }
}
