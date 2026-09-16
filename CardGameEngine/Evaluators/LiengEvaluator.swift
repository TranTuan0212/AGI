import Foundation

public enum LiengHandType: Int, Comparable, Codable {
    case diem = 1       // Điểm mod 10 (0 - 9)
    case di = 2         // Ba Tây (3 lá hình J, Q, K)
    case lieng = 3      // Liêng (Sảnh 3 lá liên tiếp)
    case sap = 4        // Sáp (3 lá cùng số)
    
    public var nameVN: String {
        switch self {
        case .sap: return "Sáp"
        case .lieng: return "Liêng"
        case .di: return "Ba Tây"
        case .diem: return "Điểm Thường"
        }
    }
    
    public static func < (lhs: LiengHandType, rhs: LiengHandType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct LiengHandScore: Comparable {
    public let handType: LiengHandType
    public let calculatedScore: Int // Absolute score according to DataGroupingUI rules
    public let descriptionVN: String
    
    public init(handType: LiengHandType, calculatedScore: Int, descriptionVN: String) {
        self.handType = handType
        self.calculatedScore = calculatedScore
        self.descriptionVN = descriptionVN
    }
    
    public static func < (lhs: LiengHandScore, rhs: LiengHandScore) -> Bool {
        return lhs.calculatedScore < rhs.calculatedScore
    }
    
    public static func == (lhs: LiengHandScore, rhs: LiengHandScore) -> Bool {
        return lhs.calculatedScore == rhs.calculatedScore
    }
}

public class LiengEvaluator {
    
    public static func evaluate(cards: [Card], suitRule: SuitRulePreset = .north) -> LiengHandScore {
        guard cards.count == 3 else {
            return LiengHandScore(
                handType: .diem,
                calculatedScore: 0,
                descriptionVN: "Không đủ 3 lá"
            )
        }
        
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        
        // 1. Check Sáp (3 of the same rank)
        // Highest rank wins. If same rank, highest card suit wins.
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            let symbol = sorted[0].rank.displaySymbol
            let topCard = sorted[0]
            let suitScore = suitRule.suitValue(topCard.suit)
            let score = 1_000_000 + (ranks[0] * 10) + suitScore
            return LiengHandScore(
                handType: .sap,
                calculatedScore: score,
                descriptionVN: "🔥 SÁP \(symbol)"
            )
        }
        
        // 2. Check Liêng (3 consecutive cards)
        // Highest: Q-K-A (12-13-14), J-Q-K ... 2-3-4, Lowest: A-2-3
        var isLieng = false
        var liengRankWeight = 0
        var liengSymbol = ""
        
        if ranks[0] - ranks[1] == 1 && ranks[1] - ranks[2] == 1 {
            isLieng = true
            liengRankWeight = ranks[0] // 4..14
            liengSymbol = sorted.map { $0.rank.displaySymbol }.reversed().joined(separator: "-")
        } else if ranks == [14, 3, 2] { // A-2-3
            isLieng = true
            liengRankWeight = 3 // tops at 3
            liengSymbol = "A-2-3"
        }
        
        if isLieng {
            let topCard = (ranks == [14, 3, 2]) ? (sorted.first(where: { $0.rank == .three }) ?? sorted[0]) : sorted[0]
            let suitScore = suitRule.suitValue(topCard.suit)
            let score = 500_000 + (liengRankWeight * 10) + suitScore
            let cardDesc = " (\(topCard.rank.displaySymbol)\(topCard.suit.rawValue))"
            return LiengHandScore(
                handType: .lieng,
                calculatedScore: score,
                descriptionVN: "⚡ LIÊNG \(liengSymbol)\(cardDesc)"
            )
        }
        
        // 3. Check Ba Tây (J, Q, K)
        let isAllFace = cards.allSatisfy { $0.rank == .jack || $0.rank == .queen || $0.rank == .king }
        if isAllFace {
            let topCard = sorted[0]
            let suitScore = suitRule.suitValue(topCard.suit)
            let score = 100_000 + (topCard.rank.rawValue * 10) + suitScore
            let symbols = sorted.map { $0.rank.displaySymbol }.joined(separator: "-")
            return LiengHandScore(
                handType: .di,
                calculatedScore: score,
                descriptionVN: "👑 BA TÂY (\(symbols)) - Lá cao: \(topCard.rank.displaySymbol)\(topCard.suit.rawValue)"
            )
        }
        
        // 4. Điểm thường (mod 10)
        // A = 1, 2-9 = number, 10,J,Q,K = 0
        // Score = (modPoint * 1000) + (highestCardRank * 10) + suitScore
        let totalPoints = cards.reduce(0) { $0 + $1.rank.liengPoint }
        let modPoint = totalPoints % 10
        let topCard = sorted[0]
        let suitScore = suitRule.suitValue(topCard.suit)
        let score = (modPoint * 1_000) + (topCard.rank.rawValue * 10) + suitScore
        let pointText = modPoint == 0 ? "0 Điểm (Bù/Tịt)" : "\(modPoint) Điểm"
        let cardDesc = " (\(topCard.rank.displaySymbol)\(topCard.suit.rawValue))"
        
        return LiengHandScore(
            handType: .diem,
            calculatedScore: score,
            descriptionVN: "⭐ \(pointText)\(cardDesc)"
        )
    }
}
