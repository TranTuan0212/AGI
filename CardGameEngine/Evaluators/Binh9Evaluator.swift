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
    
    public static func == (lhs: Binh9ChiScore, rhs: Binh9ChiScore) -> Bool {
        return !(lhs < rhs) && !(rhs < lhs)
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

// MARK: - =====================================================================
// MARK: - ( 9 lá không liên ) EVALUATOR (2 GIAI ĐOẠN: 6 LÁ TRƯỚC, 3 LÁ SAU)
// MARK: - =====================================================================

public struct Binh9NoStraightChiScore: Comparable {
    public enum ChiType: Int, Comparable {
        case points = 1           // Điểm thường (0-9)
        case pairPoints = 2       // Điểm có đôi (0-9)
        case threeFacesNoPair = 3 // Ba Tiên không đôi (J-Q-K)
        case threeFacesPair = 4   // Ba Tiên có đôi (đôi K > đôi Q > đôi J)
        case threeOfAKind = 5     // Sáp (Sáp A to nhất > K > Q > J > ... > 2)
        
        public static func < (lhs: ChiType, rhs: ChiType) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public let type: ChiType
    public let points: Int           // 0 đến 9 điểm (cho points và pairPoints)
    public let primaryRank: Int      // Sáp rank (14..2), Ba Tiên đôi rank (13..11), Pair rank (14..2)
    public let kickers: [Int]        // Các lá còn lại
    public let cards: [Card]
    
    public var descriptionVN: String {
        let sym: (Int) -> String = {
            switch $0 {
            case 14: return "A"
            case 13: return "K"
            case 12: return "Q"
            case 11: return "J"
            default: return "\($0)"
            }
        }
        switch type {
        case .threeOfAKind:
            return "Sáp \(sym(primaryRank))"
        case .threeFacesPair:
            let kStr = kickers.first != nil ? " + \(sym(kickers[0]))" : ""
            return "Ba Tiên Đôi \(sym(primaryRank))\(kStr)"
        case .threeFacesNoPair:
            return "Ba Tiên (Hình)"
        case .pairPoints:
            let kStr = kickers.first != nil ? " + \(sym(kickers[0]))" : ""
            return "\(points) Điểm (Đôi \(sym(primaryRank))\(kStr))"
        case .points:
            return points == 0 ? "Bù (0 Điểm)" : "\(points) Điểm"
        }
    }
    
    public static func < (lhs: Binh9NoStraightChiScore, rhs: Binh9NoStraightChiScore) -> Bool {
        // 1. So sánh cấp bậc đặc biệt (Sáp > Ba Tiên có đôi > Ba Tiên không đôi)
        let lhsIsSpecial = lhs.type.rawValue >= ChiType.threeFacesNoPair.rawValue
        let rhsIsSpecial = rhs.type.rawValue >= ChiType.threeFacesNoPair.rawValue
        
        if lhsIsSpecial || rhsIsSpecial {
            if lhs.type != rhs.type {
                return lhs.type < rhs.type
            }
            // Cùng là Sáp hoặc Ba Tiên có đôi
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
        // Điểm cao hơn luôn thắng: 9 điểm > 8 điểm
        if lhs.points != rhs.points {
            return lhs.points < rhs.points
        }
        
        // Trong cùng số điểm: Có Đôi thắng Không Đôi (9 điểm đôi > 9 điểm thường)
        if lhs.type != rhs.type {
            return lhs.type < rhs.type
        }
        
        // Cùng Điểm Đôi: So đôi lớn hơn (Cặp Át > Cặp K > Cặp Đầm...)
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
        
        // Cùng Điểm Thường (không đôi): So lá bài lớn nhất -> nhì -> ba
        for i in 0..<min(lhs.kickers.count, rhs.kickers.count) {
            if lhs.kickers[i] != rhs.kickers[i] {
                return lhs.kickers[i] < rhs.kickers[i]
            }
        }
        return false
    }
    
    public static func == (lhs: Binh9NoStraightChiScore, rhs: Binh9NoStraightChiScore) -> Bool {
        return !(lhs < rhs) && !(rhs < lhs)
    }
}

public struct Binh9NoStraightArrangement {
    public let chi1: [Card]
    public let chi2: [Card]
    public let chi3: [Card] // Rỗng nếu chỉ mới chia 6 lá
    public let score1: Binh9NoStraightChiScore
    public let score2: Binh9NoStraightChiScore
    public let score3: Binh9NoStraightChiScore?
    public let isLung: Bool
    public let instantWin: String?
    public let isPhase6: Bool // true: mới chia 6 lá, false: đủ 9 lá
    
    public init(
        chi1: [Card],
        chi2: [Card],
        chi3: [Card] = [],
        score1: Binh9NoStraightChiScore,
        score2: Binh9NoStraightChiScore,
        score3: Binh9NoStraightChiScore? = nil,
        isLung: Bool,
        instantWin: String? = nil,
        isPhase6: Bool = false
    ) {
        self.chi1 = chi1
        self.chi2 = chi2
        self.chi3 = chi3
        self.score1 = score1
        self.score2 = score2
        self.score3 = score3
        self.isLung = isLung
        self.instantWin = instantWin
        self.isPhase6 = isPhase6
    }
}

public class Binh9NoStraightEvaluator {
    
    // Đánh giá 1 chi 3 lá theo luật Không Tính Liêng
    public static func evaluateChi(_ cards: [Card]) -> Binh9NoStraightChiScore {
        guard cards.count == 3 else {
            return Binh9NoStraightChiScore(type: .points, points: 0, primaryRank: 0, kickers: [], cards: cards)
        }
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue } // Ace: 14, King: 13 ... Two: 2
        
        // 1. Sáp (3 of a kind) - Sáp 1 (A=14) to nhất > Sáp K (13) > Q (12)...
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            return Binh9NoStraightChiScore(type: .threeOfAKind, points: 0, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        
        // 2. Ba Tiên (3 lá đều là J, Q, K - rank >= 11 && rank <= 13)
        let isAllFaces = ranks.allSatisfy { $0 >= 11 && $0 <= 13 }
        if isAllFaces {
            // Có đôi
            if ranks[0] == ranks[1] {
                return Binh9NoStraightChiScore(type: .threeFacesPair, points: 0, primaryRank: ranks[0], kickers: [ranks[2]], cards: sorted)
            }
            if ranks[1] == ranks[2] {
                return Binh9NoStraightChiScore(type: .threeFacesPair, points: 0, primaryRank: ranks[1], kickers: [ranks[0]], cards: sorted)
            }
            // Không đôi: J-Q-K
            return Binh9NoStraightChiScore(type: .threeFacesNoPair, points: 0, primaryRank: 0, kickers: ranks, cards: sorted)
        }
        
        // 3. Tính Điểm (Mod 10): A = 1, 2-9 = raw, 10,J,Q,K = 0
        let cardPoint: (Int) -> Int = { r in
            if r == 14 { return 1 }
            if r >= 10 { return 0 }
            return r
        }
        let totalPts = (cardPoint(ranks[0]) + cardPoint(ranks[1]) + cardPoint(ranks[2])) % 10
        
        // Kiểm tra Đôi: Cặp Át (14) to nhất > Cặp K (13) > Cặp Q (12) > Cặp J (11)...
        if ranks[0] == ranks[1] {
            return Binh9NoStraightChiScore(type: .pairPoints, points: totalPts, primaryRank: ranks[0], kickers: [ranks[2]], cards: sorted)
        }
        if ranks[1] == ranks[2] {
            return Binh9NoStraightChiScore(type: .pairPoints, points: totalPts, primaryRank: ranks[1], kickers: [ranks[0]], cards: sorted)
        }
        
        // Điểm Thường (không đôi, không liêng)
        return Binh9NoStraightChiScore(type: .points, points: totalPts, primaryRank: 0, kickers: ranks, cards: sorted)
    }
    
    // Scalar trọng số để xếp tối ưu
    private static func chiScalar(_ s: Binh9NoStraightChiScore) -> Int64 {
        switch s.type {
        case .threeOfAKind:
            return Int64(500000 + s.primaryRank * 100)
        case .threeFacesPair:
            return Int64(400000 + s.primaryRank * 100 + (s.kickers.first ?? 0))
        case .threeFacesNoPair:
            return Int64(300000 + (s.kickers.first ?? 0) * 10 + (s.kickers.count > 1 ? s.kickers[1] : 0))
        case .pairPoints:
            return Int64(100000 + s.points * 10000 + s.primaryRank * 100 + (s.kickers.first ?? 0))
        case .points:
            return Int64(s.points * 10000 + (s.kickers.first ?? 0) * 100 + (s.kickers.count > 1 ? s.kickers[1] : 0))
        }
    }
    
    // MARK: - GIAI ĐOẠN 1: Chia 6 lá trước -> Xếp 2 chi (Chi 1 >= Chi 2)
    public static func autoArrange6(cards: [Card]) -> Binh9NoStraightArrangement {
        guard cards.count == 6 else {
            let emptyChi = evaluateChi([])
            return Binh9NoStraightArrangement(chi1: [], chi2: [], score1: emptyChi, score2: emptyChi, isLung: true, isPhase6: true)
        }
        
        let all3Indices = PokerEvaluator.combinations(of: Array(0..<6), k: 3)
        var bestArrangement: Binh9NoStraightArrangement? = nil
        var bestWeight: Int64 = -999999999
        
        for c1Indices in all3Indices {
            let c1Cards = c1Indices.map { cards[$0] }
            let s1 = evaluateChi(c1Cards)
            
            let c2Indices = (0..<6).filter { !c1Indices.contains($0) }
            let c2Cards = c2Indices.map { cards[$0] }
            let s2 = evaluateChi(c2Cards)
            
            guard s1 >= s2 else { continue } // Chi 1 phải >= Chi 2
            
            let weight = chiScalar(s1) * 10000 + chiScalar(s2)
            if weight > bestWeight {
                bestWeight = weight
                bestArrangement = Binh9NoStraightArrangement(
                    chi1: c1Cards,
                    chi2: c2Cards,
                    score1: s1,
                    score2: s2,
                    isLung: false,
                    isPhase6: true
                )
            }
        }
        
        if let best = bestArrangement {
            return best
        }
        
        // Fallback lủng
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let c1 = Array(sorted[0..<3])
        let c2 = Array(sorted[3..<6])
        return Binh9NoStraightArrangement(
            chi1: c1,
            chi2: c2,
            score1: evaluateChi(c1),
            score2: evaluateChi(c2),
            isLung: true,
            isPhase6: true
        )
    }
    
    // MARK: - GIAI ĐOẠN 2: Đủ 9 lá -> Xếp 3 chi (Chi 1 >= Chi 2 >= Chi 3)
    public static func autoArrange9(cards: [Card]) -> Binh9NoStraightArrangement {
        guard cards.count == 9 else {
            let emptyChi = evaluateChi([])
            return Binh9NoStraightArrangement(chi1: [], chi2: [], chi3: [], score1: emptyChi, score2: emptyChi, score3: emptyChi, isLung: true, isPhase6: false)
        }
        
        let all3Indices = PokerEvaluator.combinations(of: Array(0..<9), k: 3)
        var bestArrangement: Binh9NoStraightArrangement? = nil
        var bestWeight: Int64 = -999999999
        
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
                
                // Thắng trắng: Ba Sáp
                var instant: String? = nil
                if s1.type == .threeOfAKind && s2.type == .threeOfAKind && s3.type == .threeOfAKind {
                    instant = "Thắng trắng: Ba Sáp"
                }
                
                var weight: Int64 = chiScalar(s1) * 100000000 + chiScalar(s2) * 10000 + chiScalar(s3)
                if instant != nil { weight += 50000000000 }
                
                if weight > bestWeight {
                    bestWeight = weight
                    bestArrangement = Binh9NoStraightArrangement(
                        chi1: c1Cards,
                        chi2: c2Cards,
                        chi3: c3Cards,
                        score1: s1,
                        score2: s2,
                        score3: s3,
                        isLung: false,
                        instantWin: instant,
                        isPhase6: false
                    )
                }
            }
        }
        
        if let best = bestArrangement {
            return best
        }
        
        // Fallback lủng
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let c1 = Array(sorted[0..<3])
        let c2 = Array(sorted[3..<6])
        let c3 = Array(sorted[6..<9])
        return Binh9NoStraightArrangement(
            chi1: c1,
            chi2: c2,
            chi3: c3,
            score1: evaluateChi(c1),
            score2: evaluateChi(c2),
            score3: evaluateChi(c3),
            isLung: true,
            isPhase6: false
        )
    }
    
    // So chéo ván đấu khi ở Giai đoạn 6 lá (So 2 chi)
    public static func compareMatch6(a: Binh9NoStraightArrangement, b: Binh9NoStraightArrangement) -> (scoreA: Int, detail: String) {
        if a.isLung && b.isLung { return (0, "Cả hai đều bị Lủng") }
        if a.isLung { return (-1, "Bị Lủng (Xử thua)") }
        if b.isLung { return (1, "Đối thủ bị Lủng") }
        
        var winsA = 0
        var winsB = 0
        
        if a.score1 > b.score1 { winsA += 1 }
        else if b.score1 > a.score1 { winsB += 1 }
        
        if a.score2 > b.score2 { winsA += 1 }
        else if b.score2 > a.score2 { winsB += 1 }
        
        if winsA > winsB { return (1, "Thắng 6 lá (\(winsA)-\(winsB))") }
        if winsB > winsA { return (-1, "Thua 6 lá (\(winsB)-\(winsA))") }
        return (0, "Hòa 6 lá")
    }
    
    // So chéo ván đấu khi ở Giai đoạn 9 lá (So 3 chi, ăn >= 2 chi là Thắng)
    public static func compareMatch9(a: Binh9NoStraightArrangement, b: Binh9NoStraightArrangement) -> (scoreA: Int, detail: String) {
        if let winA = a.instantWin, let winB = b.instantWin {
            return (0, "Hòa Thắng Trắng: \(winA) vs \(winB)")
        }
        if let winA = a.instantWin { return (1, "\(winA) (Thắng trắng)") }
        if let winB = b.instantWin { return (-1, "Đối thủ \(winB) (Thua trắng)") }
        
        if a.isLung && b.isLung { return (0, "Cả hai đều bị Lủng") }
        if a.isLung { return (-1, "Bị Lủng (Xử thua)") }
        if b.isLung { return (1, "Đối thủ bị Lủng") }
        
        var winsA = 0
        var winsB = 0
        
        if a.score1 > b.score1 { winsA += 1 }
        else if b.score1 > a.score1 { winsB += 1 }
        
        let s2A = a.score2
        let s2B = b.score2
        if s2A > s2B { winsA += 1 }
        else if s2B > s2A { winsB += 1 }
        
        if let s3A = a.score3, let s3B = b.score3 {
            if s3A > s3B { winsA += 1 }
            else if s3B > s3A { winsB += 1 }
        }
        
        if winsA > winsB {
            return (1, "Ăn \(winsA)/3 chi (Thắng)")
        } else if winsB > winsA {
            return (-1, "Thua (\(winsA)/3 chi)")
        }
        return (0, "Hòa chi")
    }
}
