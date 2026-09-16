import Foundation

public enum LiengHandType: Int, Comparable, Codable {
    case diem = 1       // Điểm mod 10 (0 - 9)
    case di = 2         // Đĩ (3 lá hình J, Q, K)
    case lieng = 3      // Liêng (Sảnh 3 lá liên tiếp)
    case sap = 4        // Sáp (3 lá cùng số)
    
    public var nameVN: String {
        switch self {
        case .sap: return "Sáp"
        case .lieng: return "Liêng"
        case .di: return "Đĩ (Ba Tây J-Q-K)"
        case .diem: return "Điểm"
        }
    }
    
    public static func < (lhs: LiengHandType, rhs: LiengHandType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct LiengHandScore: Comparable {
    public let handType: LiengHandType
    public let mainRank: Int       // e.g. Sap rank, Lieng high rank, or Point (0-9)
    public let highestCardRank: Int // Highest card rank in the hand
    public let highestCardSuit: Suit // Suit of the highest card
    public let suitRule: SuitRulePreset
    public let descriptionVN: String
    
    public static func < (lhs: LiengHandScore, rhs: LiengHandScore) -> Bool {
        if lhs.handType != rhs.handType {
            return lhs.handType < rhs.handType
        }
        
        // Same hand type:
        switch lhs.handType {
        case .sap:
            if lhs.mainRank != rhs.mainRank {
                return lhs.mainRank < rhs.mainRank
            }
            let s1 = lhs.suitRule.suitValue(lhs.highestCardSuit)
            let s2 = lhs.suitRule.suitValue(rhs.highestCardSuit)
            return s1 < s2
            
        case .lieng:
            if lhs.mainRank != rhs.mainRank {
                return lhs.mainRank < rhs.mainRank
            }
            let s1 = lhs.suitRule.suitValue(lhs.highestCardSuit)
            let s2 = lhs.suitRule.suitValue(rhs.highestCardSuit)
            return s1 < s2
            
        case .di:
            if lhs.highestCardRank != rhs.highestCardRank {
                return lhs.highestCardRank < rhs.highestCardRank
            }
            let s1 = lhs.suitRule.suitValue(lhs.highestCardSuit)
            let s2 = lhs.suitRule.suitValue(rhs.highestCardSuit)
            return s1 < s2
            
        case .diem:
            if lhs.mainRank != rhs.mainRank {
                return lhs.mainRank < rhs.mainRank
            }
            // Same points -> compare highest card rank
            if lhs.highestCardRank != rhs.highestCardRank {
                return lhs.highestCardRank < rhs.highestCardRank
            }
            // Same highest card rank -> compare suit
            let s1 = lhs.suitRule.suitValue(lhs.highestCardSuit)
            let s2 = lhs.suitRule.suitValue(rhs.highestCardSuit)
            return s1 < s2
        }
    }
    
    public static func == (lhs: LiengHandScore, rhs: LiengHandScore) -> Bool {
        return !(lhs < rhs) && !(rhs < lhs)
    }
}

public class LiengEvaluator {
    
    public static func evaluate(cards: [Card], suitRule: SuitRulePreset = .north) -> LiengHandScore {
        guard cards.count == 3 else {
            return LiengHandScore(
                handType: .diem,
                mainRank: 0,
                highestCardRank: 0,
                highestCardSuit: .spades,
                suitRule: suitRule,
                descriptionVN: "Không đủ 3 lá"
            )
        }
        
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        let highestCard = sorted[0]
        
        // 1. Check Sáp (3 of the same rank)
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            let symbol = sorted[0].rank.displaySymbol
            return LiengHandScore(
                handType: .sap,
                mainRank: ranks[0],
                highestCardRank: ranks[0],
                highestCardSuit: highestCard.suit,
                suitRule: suitRule,
                descriptionVN: "Sáp \(symbol)"
            )
        }
        
        // 2. Check Liêng (3 consecutive cards)
        // Cases: Q-K-A (12-13-14), J-Q-K (11-12-13)... 2-3-4 (2-3-4), A-2-3 (14-2-3)
        var isLieng = false
        var liengHigh = 0
        var liengTopCard = highestCard
        
        if ranks[0] - ranks[1] == 1 && ranks[1] - ranks[2] == 1 {
            isLieng = true
            liengHigh = ranks[0]
            liengTopCard = sorted[0]
        } else if ranks == [14, 3, 2] { // A-2-3
            isLieng = true
            liengHigh = 3 // Lowest Lieng: A-2-3 (tops at 3)
            liengTopCard = sorted.first(where: { $0.rank.rawValue == 3 }) ?? sorted[0]
        }
        
        if isLieng {
            let symbols = sorted.map { $0.rank.displaySymbol }.reversed().joined(separator: "-")
            return LiengHandScore(
                handType: .lieng,
                mainRank: liengHigh,
                highestCardRank: liengTopCard.rank.rawValue,
                highestCardSuit: liengTopCard.suit,
                suitRule: suitRule,
                descriptionVN: "Liêng \(symbols)"
            )
        }
        
        // 3. Check Đĩ (Ba Tây / Đồng hoa: All 3 cards in J, Q, K)
        let isAllFace = cards.allSatisfy { $0.rank == .jack || $0.rank == .queen || $0.rank == .king }
        if isAllFace {
            let symbols = sorted.map { $0.rank.displaySymbol }.joined(separator: "-")
            return LiengHandScore(
                handType: .di,
                mainRank: ranks[0],
                highestCardRank: ranks[0],
                highestCardSuit: highestCard.suit,
                suitRule: suitRule,
                descriptionVN: "Đĩ (\(symbols)) - Lá cao nhất: \(highestCard.displayName)"
            )
        }
        
        // 4. Mậu thầu (Tính điểm mod 10)
        let totalPoints = cards.reduce(0) { $0 + $1.rank.liengPoint }
        let modPoint = totalPoints % 10
        let pointText = modPoint == 0 ? "0 điểm (Bù/Tịt)" : "\(modPoint) điểm"
        
        return LiengHandScore(
            handType: .diem,
            mainRank: modPoint,
            highestCardRank: ranks[0],
            highestCardSuit: highestCard.suit,
            suitRule: suitRule,
            descriptionVN: "\(pointText) - Lá cao: \(highestCard.displayName)"
        )
    }
}
