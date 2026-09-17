import Foundation

public struct Binh9ChiScore: Comparable {
    public enum ChiType: Int, Comparable {
        case points = 1         // Điểm thường (0-9)
        case pairPoints = 2     // Điểm có đôi (0-9)
        case threeFaces = 3     // Ba Tây / Hình (J, Q, K)
        case straight = 4       // Liêng / Sảnh
        case threeOfAKind = 5   // Sáp
        
        public static func < (lhs: ChiType, rhs: ChiType) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public let type: ChiType
    public let points: Int           // 0 đến 9 điểm (cho points và pairPoints)
    public let primaryRank: Int      // Sáp rank, Sảnh peak rank, hoặc Pair rank
    public let kickers: [Int]        // Các lá còn lại
    public let cards: [Card]
    
    public var descriptionVN: String {
        let sym: (Int) -> String = { Rank(rawValue: $0)?.displaySymbol ?? "\($0)" }
        switch type {
        case .threeOfAKind:
            return "Sáp \(sym(primaryRank))"
        case .straight:
            return primaryRank == 3 ? "Liêng A-2-3" : "Liêng đỉnh \(sym(primaryRank))"
        case .threeFaces:
            return "Ba Tây (Hình)"
        case .pairPoints:
            return "\(points) Điểm Đôi (Đôi \(sym(primaryRank)))"
        case .points:
            return points == 0 ? "Bù (0 Điểm)" : "\(points) Điểm"
        }
    }
    
    public static func < (lhs: Binh9ChiScore, rhs: Binh9ChiScore) -> Bool {
        // 1. So sánh giữa các tầng đặc biệt (Sáp, Liêng, Ba Tây)
        let lhsIsSpecial = lhs.type.rawValue >= ChiType.threeFaces.rawValue
        let rhsIsSpecial = rhs.type.rawValue >= ChiType.threeFaces.rawValue
        
        if lhsIsSpecial || rhsIsSpecial {
            if lhs.type != rhs.type {
                return lhs.type < rhs.type
            }
            // Cùng loại đặc biệt
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
        
        // 2. Cả hai đều thuộc tầng Điểm (points hoặc pairPoints)
        // Điểm cao hơn luôn thắng (9 điểm > 8 điểm)
        if lhs.points != rhs.points {
            return lhs.points < rhs.points
        }
        
        // Cùng điểm: Đôi ăn Thường (9 điểm đôi > 9 điểm thường)
        if lhs.type != rhs.type {
            return lhs.type < rhs.type
        }
        
        // Cùng Điểm Đôi: So đôi lớn hơn (Đôi 8 > Đôi 7)
        if lhs.type == .pairPoints {
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
        
        // Cùng Điểm Thường: So lá bài lớn nhất
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
    public let instantWin: String? // "Ba Sáp" hoặc "Ba Liêng"
}

public class Binh9Evaluator {
    
    public static func evaluateChi(_ cards: [Card]) -> Binh9ChiScore {
        guard cards.count == 3 else {
            return Binh9ChiScore(type: .points, points: 0, primaryRank: 0, kickers: [], cards: cards)
        }
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        
        // 1. Sáp (3 of a kind)
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            return Binh9ChiScore(type: .threeOfAKind, points: 0, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        
        // 2. Liêng / Sảnh (Q-K-A, A-2-3 hoặc 3 số liên tiếp)
        if ranks[0] - ranks[1] == 1 && ranks[1] - ranks[2] == 1 {
            return Binh9ChiScore(type: .straight, points: 0, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        if ranks == [14, 3, 2] { // A-2-3
            return Binh9ChiScore(type: .straight, points: 0, primaryRank: 3, kickers: [], cards: sorted)
        }
        
        // 3. Ba Tây / Hình (3 lá đều là J, Q, K)
        let isAllFaces = ranks.allSatisfy { $0 >= 11 && $0 <= 13 }
        if isAllFaces {
            return Binh9ChiScore(type: .threeFaces, points: 0, primaryRank: ranks[0], kickers: Array(ranks.dropFirst()), cards: sorted)
        }
        
        // 4. Tính Điểm (Mod 10): A = 1, 2-9 = raw, 10,J,Q,K = 0
        let cardPoint: (Int) -> Int = { r in
            if r == 14 { return 1 }
            if r >= 10 { return 0 }
            return r
        }
        let totalPts = (cardPoint(ranks[0]) + cardPoint(ranks[1]) + cardPoint(ranks[2])) % 10
        
        // Kiểm tra Đôi
        if ranks[0] == ranks[1] {
            return Binh9ChiScore(type: .pairPoints, points: totalPts, primaryRank: ranks[0], kickers: [ranks[2]], cards: sorted)
        }
        if ranks[1] == ranks[2] {
            return Binh9ChiScore(type: .pairPoints, points: totalPts, primaryRank: ranks[1], kickers: [ranks[0]], cards: sorted)
        }
        
        // Điểm Thường
        return Binh9ChiScore(type: .points, points: totalPts, primaryRank: 0, kickers: ranks, cards: sorted)
    }
    
    // Auto-arrange 9 cards: Chi 1 >= Chi 2 >= Chi 3
    public static func autoArrange(cards: [Card]) -> Binh9Arrangement {
        guard cards.count == 9 else {
            let emptyChi = evaluateChi([])
            return Binh9Arrangement(chi1: [], chi2: [], chi3: [], score1: emptyChi, score2: emptyChi, score3: emptyChi, isLung: true, instantWin: nil)
        }
        
        let all3Indices = PokerEvaluator.combinations(of: Array(0..<9), k: 3)
        var bestArrangement: Binh9Arrangement? = nil
        var bestWeight: Int64 = -999999999
        
        let chiScalar: (Binh9ChiScore) -> Int64 = { s in
            switch s.type {
            case .threeOfAKind:
                return Int64(500000 + s.primaryRank * 100)
            case .straight:
                return Int64(400000 + s.primaryRank * 100)
            case .threeFaces:
                return Int64(300000 + s.primaryRank * 100 + (s.kickers.first ?? 0))
            case .pairPoints:
                return Int64(100000 + s.points * 10000 + s.primaryRank * 100 + (s.kickers.first ?? 0))
            case .points:
                return Int64(s.points * 10000 + (s.kickers.first ?? 0) * 100 + (s.kickers.count > 1 ? s.kickers[1] : 0))
            }
        }
        
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
                    instant = "Thắng trắng: Ba Sáp"
                } else if s1.type == .straight && s2.type == .straight && s3.type == .straight {
                    instant = "Thắng trắng: Ba Liêng"
                }
                
                var weight: Int64 = chiScalar(s1) * 10000 + chiScalar(s2) * 100 + chiScalar(s3)
                if instant != nil { weight += 50000000000 }
                
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
    
    // Compare two players A and B in Binh 9: Thắng >= 2 chi là Thắng luôn ván đối đầu
    public static func compareMatch(a: Binh9Arrangement, b: Binh9Arrangement) -> (scoreA: Int, detail: String) {
        if let winA = a.instantWin, let winB = b.instantWin {
            return (0, "Hòa Thắng Trắng: \(winA) vs \(winB)")
        }
        if let winA = a.instantWin { return (1, "\(winA) (Thắng trắng)") }
        if let winB = b.instantWin { return (-1, "Đối thủ \(winB) (Thua trắng)") }
        
        if a.isLung && b.isLung { return (0, "Cả hai đều bị Lủng") }
        if a.isLung { return (-1, "Bị Lủng (Xử thua)") }
        if b.isLung { return (1, "Đối thủ bị Lủng (Xử thắng)") }
        
        var aWins = 0
        var bWins = 0
        
        var c1Text = "Hòa"
        if a.score1 > b.score1 {
            aWins += 1
            c1Text = "Ăn"
        } else if a.score1 < b.score1 {
            bWins += 1
            c1Text = "Thua"
        }
        
        var c2Text = "Hòa"
        if a.score2 > b.score2 {
            aWins += 1
            c2Text = "Ăn"
        } else if a.score2 < b.score2 {
            bWins += 1
            c2Text = "Thua"
        }
        
        var c3Text = "Hòa"
        if a.score3 > b.score3 {
            aWins += 1
            c3Text = "Ăn"
        } else if a.score3 < b.score3 {
            bWins += 1
            c3Text = "Thua"
        }
        
        let scoreA: Int
        let resultText: String
        if aWins >= 2 {
            scoreA = 1
            resultText = "THẮNG (\(aWins)/3 chi)"
        } else if bWins >= 2 {
            scoreA = -1
            resultText = "THUA (\(bWins)/3 chi)"
        } else {
            scoreA = 0
            resultText = "HÒA (Mỗi bên \(aWins) chi)"
        }
        
        let detail = "Chi 1: \(c1Text), Chi 2: \(c2Text), Chi 3: \(c3Text) -> \(resultText)"
        return (scoreA, detail)
    }
}
