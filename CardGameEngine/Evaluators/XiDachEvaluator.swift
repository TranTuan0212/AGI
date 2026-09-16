import Foundation

public struct XiDachScore: Comparable {
    public let score: Int
    public let title: String
    public let detail: String
    
    public init(score: Int, title: String, detail: String) {
        self.score = score
        self.title = title
        self.detail = detail
    }
    
    public static func < (lhs: XiDachScore, rhs: XiDachScore) -> Bool {
        return lhs.score < rhs.score
    }
    
    public static func == (lhs: XiDachScore, rhs: XiDachScore) -> Bool {
        return lhs.score == rhs.score
    }
}

public class XiDachEvaluator {
    
    // Convert card rank to Xi Dach value:
    // A: 1 (flexible in total calculation)
    // 2..9: rawValue
    // 10, J, Q, K: 10
    public static func cardBaseValue(_ card: Card) -> Int {
        switch card.rank {
        case .ace: return 1
        case .two, .three, .four, .five, .six, .seven, .eight, .nine: return card.rank.rawValue
        case .ten, .jack, .queen, .king: return 10
        }
    }
    
    // Calculate best total sum <= 21, considering Ace can be 1, 10, or 11
    public static func bestTotal(cards: [Card]) -> Int {
        let nonAces = cards.filter { $0.rank != .ace }
        let aceCount = cards.filter { $0.rank == .ace }.count
        let baseSum = nonAces.reduce(0) { $0 + cardBaseValue($1) }
        
        if aceCount == 0 {
            return baseSum
        }
        
        // For cards with Aces:
        // Try all combinations of Ace values (11, 10, 1) to find maximum total <= 21.
        // If all totals > 21, pick the smallest total > 21 (minimum bust).
        var possibleTotals = Set<Int>()
        possibleTotals.insert(baseSum)
        
        for _ in 0..<aceCount {
            var nextTotals = Set<Int>()
            for t in possibleTotals {
                nextTotals.insert(t + 1)
                nextTotals.insert(t + 10)
                nextTotals.insert(t + 11)
            }
            possibleTotals = nextTotals
        }
        
        let validTotals = possibleTotals.filter { $0 <= 21 }
        if let maxValid = validTotals.max() {
            return maxValid
        }
        return possibleTotals.min() ?? (baseSum + aceCount)
    }
    
    public static func evaluate(cards: [Card]) -> XiDachScore {
        guard cards.count >= 2 else {
            return XiDachScore(score: 0, title: "Chưa đủ 2 lá", detail: "Cần ít nhất 2 lá")
        }
        
        let count = cards.count
        let ranks = cards.map { $0.rank }
        let aceCount = ranks.filter { $0 == .ace }.count
        
        // Case A: Exactly 2 cards
        if count == 2 {
            // 1. Xì Bàng (A-A) -> 5021
            if aceCount == 2 {
                return XiDachScore(score: 5021, title: "👑 Xì Bàng (A-A)", detail: "Thắng tuyệt đối toàn bàn")
            }
            
            // 2. Xì Dách (A + 10/J/Q/K) -> 4000
            let hasFaceOr10 = cards.contains { $0.rank == .ten || $0.rank == .jack || $0.rank == .queen || $0.rank == .king }
            if aceCount == 1 && hasFaceOr10 {
                return XiDachScore(score: 4000, title: "🔥 Xì Dách (21đ)", detail: "1 Át + 1 Quân Tây/10")
            }
        }
        
        // Case B: 5 cards (Ngũ Linh)
        let total = bestTotal(cards: cards)
        if count == 5 && total <= 21 {
            // Ngũ Linh: 3000 + (21 - total) -> smaller total wins!
            let score = 3000 + (21 - total)
            return XiDachScore(score: score, title: "🌟 Ngũ Linh (\(total)đ)", detail: "5 lá đủ điểm (≤ 21đ)")
        }
        
        // Case C: Standard totals (16-21, <16 non, >21 quắc)
        if total >= 16 && total <= 21 {
            // Đủ điểm (16 - 21) -> 2000 + total
            let score = 2000 + total
            return XiDachScore(score: score, title: "\(total) Điểm (Đủ tuổi)", detail: "Đạt ngưỡng chuẩn 16-21đ")
        } else if total < 16 {
            // Non (< 16) -> 1000 + total
            let score = 1000 + total
            return XiDachScore(score: score, title: "⚠️ Non (\(total)đ)", detail: "Chưa đủ 16 điểm")
        } else {
            // Quắc (> 21) -> max(0, 35 - total)
            let score = max(0, 35 - total)
            return XiDachScore(score: score, title: "❌ Quắc (\(total)đ)", detail: "Vượt ngưỡng 21 điểm")
        }
    }
}
