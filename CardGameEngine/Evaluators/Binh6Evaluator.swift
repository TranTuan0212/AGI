import Foundation

public struct Binh6SplitArrangement {
    public let chi1: [Card] // Chi 1 (3 lá)
    public let chi2: [Card] // Chi 2 (3 lá)
    public let score1: Binh9ChiScore
    public let score2: Binh9ChiScore
    public let isLung: Bool
}

public class Binh6Evaluator {
    
    // Mode 1: 6-card Poker Hand (best 5 out of 6)
    public static func evaluatePoker6(_ cards: [Card]) -> PokerHandScore {
        return PokerEvaluator.evaluate7Cards(cards)
    }
    
    // Mode 2: Split 2 chi (3 - 3)
    public static func autoArrangeSplit(_ cards: [Card]) -> Binh6SplitArrangement {
        guard cards.count == 6 else {
            let empty = Binh9Evaluator.evaluateChi([])
            return Binh6SplitArrangement(chi1: [], chi2: [], score1: empty, score2: empty, isLung: true)
        }
        
        let all3Indices = PokerEvaluator.combinations(of: Array(0..<6), k: 3)
        var best: Binh6SplitArrangement? = nil
        var bestWeight = -999999
        
        for c1Idx in all3Indices {
            let c1Cards = c1Idx.map { cards[$0] }
            let s1 = Binh9Evaluator.evaluateChi(c1Cards)
            
            let c2Idx = (0..<6).filter { !c1Idx.contains($0) }
            let c2Cards = c2Idx.map { cards[$0] }
            let s2 = Binh9Evaluator.evaluateChi(c2Cards)
            
            // Chi 1 >= Chi 2
            guard s1 >= s2 else { continue }
            
            let weight = s1.type.rawValue * 200 + s1.primaryRank * 10 + s2.type.rawValue * 100 + s2.primaryRank * 5
            if weight > bestWeight {
                bestWeight = weight
                best = Binh6SplitArrangement(chi1: c1Cards, chi2: c2Cards, score1: s1, score2: s2, isLung: false)
            }
        }
        
        if let res = best { return res }
        
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let c1 = Array(sorted[0..<3])
        let c2 = Array(sorted[3..<6])
        return Binh6SplitArrangement(chi1: c1, chi2: c2, score1: Binh9Evaluator.evaluateChi(c1), score2: Binh9Evaluator.evaluateChi(c2), isLung: true)
    }
    
    // Compare 2 players in Split mode
    public static func compareSplit(a: Binh6SplitArrangement, b: Binh6SplitArrangement) -> (scoreA: Int, detail: String) {
        if a.isLung && b.isLung { return (0, "Cả hai đều bị Lủng") }
        if a.isLung { return (-4, "Bị Lủng (thua 2 chi x2 = -4 chi)") }
        if b.isLung { return (4, "Đối thủ bị Lủng (+4 chi)") }
        
        var c1 = 0
        if a.score1 > b.score1 { c1 = 1 } else if a.score1 < b.score1 { c1 = -1 }
        
        var c2 = 0
        if a.score2 > b.score2 { c2 = 1 } else if a.score2 < b.score2 { c2 = -1 }
        
        var total = c1 + c2
        if c1 > 0 && c2 > 0 { total = 4 } // Sập hầm x2
        else if c1 < 0 && c2 < 0 { total = -4 }
        
        let detail = "Chi 1: \(c1 > 0 ? "+1" : "\(c1)"), Chi 2: \(c2 > 0 ? "+1" : "\(c2)") -> Tổng: \(total > 0 ? "+\(total)" : "\(total)") chi"
        return (total, detail)
    }
}
