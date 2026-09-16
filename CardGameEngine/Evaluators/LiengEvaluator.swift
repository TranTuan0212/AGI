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
        // Score: 10,000 + Rank (Sáp A = 10,014 > Sáp K = 10,013 ... > Sáp 2 = 10,002)
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            let symbol = sorted[0].rank.displaySymbol
            let score = 10000 + ranks[0]
            return LiengHandScore(
                handType: .sap,
                calculatedScore: score,
                descriptionVN: "🔥 SÁP \(symbol)"
            )
        }
        
        // 2. Check Liêng (3 consecutive cards)
        // Highest: Q-K-A (12-13-14) -> 5,014
        // Others: J-Q-K (11-12-13) -> 5,013 ... 2-3-4 -> 5,004
        // Lowest: A-2-3 (14-3-2) -> 5,003
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
            let score = 5000 + liengRankWeight
            return LiengHandScore(
                handType: .lieng,
                calculatedScore: score,
                descriptionVN: "⚡ LIÊNG \(liengSymbol)"
            )
        }
        
        // 3. Check Ba Tây (J, Q, K)
        // Score: 1,000
        let isAllFace = cards.allSatisfy { $0.rank == .jack || $0.rank == .queen || $0.rank == .king }
        if isAllFace {
            let symbols = sorted.map { $0.rank.displaySymbol }.joined(separator: "-")
            return LiengHandScore(
                handType: .di,
                calculatedScore: 1000,
                descriptionVN: "👑 BA TÂY (\(symbols))"
            )
        }
        
        // 4. Điểm thường (mod 10)
        // A = 1, 2-9 = number, 10,J,Q,K = 0
        // Score = (Tổng % 10) * 100 (9 điểm = 900, 8 điểm = 800 ... 0 điểm = 0)
        let totalPoints = cards.reduce(0) { $0 + $1.rank.liengPoint }
        let modPoint = totalPoints % 10
        let score = modPoint * 100
        let pointText = modPoint == 0 ? "0 Điểm (Bù/Tịt)" : "\(modPoint) Điểm"
        
        return LiengHandScore(
            handType: .diem,
            calculatedScore: score,
            descriptionVN: "⭐ \(pointText)"
        )
    }
}
