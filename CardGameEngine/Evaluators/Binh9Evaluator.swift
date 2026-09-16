import Foundation

public struct Binh9ChiScore: Comparable {
    public enum ChiType: Int, Comparable {
        case highCard = 1
        case onePair = 2
        case straight = 3
        case threeOfAKind = 4
        
        public static func < (lhs: ChiType, rhs: ChiType) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public let type: ChiType
    public let primaryRank: Int
    public let kickers: [Int]
    public let cards: [Card]
    
    public var descriptionVN: String {
        let sym: (Int) -> String = { Rank(rawValue: $0)?.displaySymbol ?? "\($0)" }
        switch type {
        case .threeOfAKind:
            return "Sám cô \(sym(primaryRank))"
        case .straight:
            return primaryRank == 3 ? "Sảnh bánh xe (A-2-3)" : "Sảnh đỉnh \(sym(primaryRank))"
        case .onePair:
            return "Đôi \(sym(primaryRank)) (Kicker \(sym(kickers.first ?? 0)))"
        case .highCard:
            return "Mậu thầu đỉnh \(sym(primaryRank))"
        }
    }
    
    public static func < (lhs: Binh9ChiScore, rhs: Binh9ChiScore) -> Bool {
        if lhs.type != rhs.type {
            return lhs.type < rhs.type
        }
        if lhs.primaryRank != rhs.primaryRank {
            return lhs.primaryRank < rhs.primaryRank
        }
        for i in 0..<min(lhs.kickers.count, rhs.kickers.count) {
            if lhs.kickers[i] != rhs.kickers[i] {
                return lhs.kickers[i] < rhs.kickers[i]
            }
        }
        return false
    }
}

public struct Binh9Arrangement {
    public let chi1: [Card] // Chi 1 (trên - mạnh nhất)
    public let chi2: [Card] // Chi 2 (giữa)
    public let chi3: [Card] // Chi 3 (dưới - yếu nhất)
    
    public let score1: Binh9ChiScore
    public let score2: Binh9ChiScore
    public let score3: Binh9ChiScore
    
    public let isLung: Bool
    public let instantWin: String? // "Ba Sám Cô" hoặc "Ba Sảnh"
}

public class Binh9Evaluator {
    
    public static func evaluateChi(_ cards: [Card]) -> Binh9ChiScore {
        guard cards.count == 3 else {
            return Binh9ChiScore(type: .highCard, primaryRank: 0, kickers: [], cards: cards)
        }
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        
        // 1. Sám cô
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            return Binh9ChiScore(type: .threeOfAKind, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        
        // 2. Sảnh
        if ranks[0] - ranks[1] == 1 && ranks[1] - ranks[2] == 1 {
            return Binh9ChiScore(type: .straight, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        if ranks == [14, 3, 2] { // A-2-3
            return Binh9ChiScore(type: .straight, primaryRank: 3, kickers: [], cards: sorted)
        }
        
        // 3. Đôi
        if ranks[0] == ranks[1] {
            return Binh9ChiScore(type: .onePair, primaryRank: ranks[0], kickers: [ranks[2]], cards: sorted)
        }
        if ranks[1] == ranks[2] {
            return Binh9ChiScore(type: .onePair, primaryRank: ranks[1], kickers: [ranks[0]], cards: sorted)
        }
        
        // 4. Mậu thầu
        return Binh9ChiScore(type: .highCard, primaryRank: ranks[0], kickers: [ranks[1], ranks[2]], cards: sorted)
    }
    
    // Auto-arrange 9 cards: Chi 1 >= Chi 2 >= Chi 3
    public static func autoArrange(cards: [Card]) -> Binh9Arrangement {
        guard cards.count == 9 else {
            let emptyChi = evaluateChi([])
            return Binh9Arrangement(chi1: [], chi2: [], chi3: [], score1: emptyChi, score2: emptyChi, score3: emptyChi, isLung: true, instantWin: nil)
        }
        
        let all3Indices = PokerEvaluator.combinations(of: Array(0..<9), k: 3)
        var bestArrangement: Binh9Arrangement? = nil
        var bestWeight = -999999
        
        for c1Indices in all3Indices {
            let c1Cards = c1Indices.map { cards[$0] }
            let s1 = evaluateChi(c1Cards)
            
            let rem1 = (0..<9).filter { !c1Indices.contains($0) }
            let remCombos = PokerEvaluator.combinations(of: rem1, k: 3)
            
            for c2Indices in remCombos {
                let c2Cards = c2Indices.map { cards[$0] }
                let s2 = evaluateChi(c2Cards)
                
                guard s1 >= s2 else { continue }
                
                let c3Indices = rem1.filter { !c2Indices.contains($0) }
                let c3Cards = c3Indices.map { cards[$0] }
                let s3 = evaluateChi(c3Cards)
                
                guard s2 >= s3 else { continue }
                
                // Check instant win
                var instant: String? = nil
                if s1.type == .threeOfAKind && s2.type == .threeOfAKind && s3.type == .threeOfAKind {
                    instant = "Thắng trắng: Ba Sám Cô"
                } else if s1.type == .straight && s2.type == .straight && s3.type == .straight {
                    instant = "Thắng trắng: Ba Sảnh"
                }
                
                var weight = s1.type.rawValue * 300 + s1.primaryRank * 10
                weight += s2.type.rawValue * 200 + s2.primaryRank * 10
                weight += s3.type.rawValue * 100 + s3.primaryRank * 10
                if instant != nil { weight += 50000 }
                
                if weight > bestWeight {
                    bestWeight = weight
                    bestArrangement = Binh9Arrangement(
                        chi1: c1Cards, chi2: c2Cards, chi3: c3Cards,
                        score1: s1, score2: s2, score3: s3,
                        isLung: false, instantWin: instant
                    )
                }
            }
        }
        
        if let best = bestArrangement {
            return best
        }
        
        // Fallback lung
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let c1 = Array(sorted[0..<3])
        let c2 = Array(sorted[3..<6])
        let c3 = Array(sorted[6..<9])
        return Binh9Arrangement(
            chi1: c1, chi2: c2, chi3: c3,
            score1: evaluateChi(c1), score2: evaluateChi(c2), score3: evaluateChi(c3),
            isLung: true, instantWin: nil
        )
    }
    
    // Compare two players A and B in Binh 9
    public static func compareMatch(a: Binh9Arrangement, b: Binh9Arrangement) -> (scoreA: Int, detail: String) {
        if let winA = a.instantWin, let winB = b.instantWin {
            return (0, "Hòa Thắng Trắng: \(winA) vs \(winB)")
        }
        if let winA = a.instantWin { return (6, "\(winA) (+6 chi)") }
        if let winB = b.instantWin { return (-6, "Đối thủ \(winB) (-6 chi)") }
        
        if a.isLung && b.isLung { return (0, "Cả hai đều bị Lủng") }
        if a.isLung { return (-6, "Bị Lủng (phạt -6 chi)") }
        if b.isLung { return (6, "Đối thủ bị Lủng (+6 chi)") }
        
        var chi1 = 0
        if a.score1 > b.score1 { chi1 = 1 } else if a.score1 < b.score1 { chi1 = -1 }
        
        var chi2 = 0
        if a.score2 > b.score2 { chi2 = 1 } else if a.score2 < b.score2 { chi2 = -1 }
        
        var chi3 = 0
        if a.score3 > b.score3 { chi3 = 1 } else if a.score3 < b.score3 { chi3 = -1 }
        
        var total = chi1 + chi2 + chi3
        var sapHamText = ""
        if chi1 > 0 && chi2 > 0 && chi3 > 0 {
            total = 6
            sapHamText = " (Bắt sập hầm x2 = +6 chi)"
        } else if chi1 < 0 && chi2 < 0 && chi3 < 0 {
            total = -6
            sapHamText = " (Bị sập hầm x2 = -6 chi)"
        }
        
        let detail = "Chi 1: \(chi1 > 0 ? "+1" : "\(chi1)"), Chi 2: \(chi2 > 0 ? "+1" : "\(chi2)"), Chi 3: \(chi3 > 0 ? "+1" : "\(chi3)")\(sapHamText) -> Tổng: \(total > 0 ? "+\(total)" : "\(total)") chi"
        return (total, detail)
    }
}
