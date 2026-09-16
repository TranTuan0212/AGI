import Foundation

public enum BinhInstantWinType: Int, Comparable {
    case baSanh = 1         // 3 cái sảnh (3 chi đều sảnh)
    case baThung = 2        // 3 cái thùng (3 chi đều thùng)
    case lucPheBon = 3      // Lục phé bôn (6 đôi)
    case namDoiMotSam = 4   // 5 đôi 1 sám
    case dongHoa13 = 5      // Đồng hoa 13 lá (toàn đỏ hoặc toàn đen)
    case sanhRong = 6       // Sảnh rồng 2 -> A khác chất
    case rongCuon = 7       // Rồng cuốn (Sảnh rồng 2 -> A cùng chất)
    
    public var bonusChips: Int {
        switch self {
        case .rongCuon: return 24
        case .sanhRong: return 12
        case .dongHoa13: return 8
        case .namDoiMotSam: return 6
        case .lucPheBon: return 6
        case .baThung: return 3
        case .baSanh: return 3
        }
    }
    
    public var nameVN: String {
        switch self {
        case .rongCuon: return "Thắng trắng: Rồng Cuốn (24 chi)"
        case .sanhRong: return "Thắng trắng: Sảnh Rồng (12 chi)"
        case .dongHoa13: return "Thắng trắng: Đồng Hoa 13 Lá (8 chi)"
        case .namDoiMotSam: return "Thắng trắng: 5 Đôi 1 Sám (6 chi)"
        case .lucPheBon: return "Thắng trắng: Lục Phé Bôn - 6 Đôi (6 chi)"
        case .baThung: return "Thắng trắng: Ba Cái Thùng (3 chi)"
        case .baSanh: return "Thắng trắng: Ba Cái Sảnh (3 chi)"
        }
    }
    
    public static func < (lhs: BinhInstantWinType, rhs: BinhInstantWinType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// 3-card front hand score
public struct BinhFrontHandScore: Comparable {
    public enum FrontType: Int, Comparable {
        case highCard = 1
        case onePair = 2
        case threeOfAKind = 3
        
        public static func < (lhs: FrontType, rhs: FrontType) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    public let type: FrontType
    public let primaryRank: Int
    public let kickers: [Int]
    public let cards: [Card]
    
    public var descriptionVN: String {
        let sym: (Int) -> String = { Rank(rawValue: $0)?.displaySymbol ?? "\($0)" }
        switch type {
        case .threeOfAKind:
            return "Sám cô \(sym(primaryRank)) (Hàng chi đầu: +3 chi)"
        case .onePair:
            return "Đôi \(sym(primaryRank)) (Kicker \(sym(kickers.first ?? 0)))"
        case .highCard:
            return "Mậu thầu đỉnh \(sym(primaryRank))"
        }
    }
    
    public static func < (lhs: BinhFrontHandScore, rhs: BinhFrontHandScore) -> Bool {
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

public struct Binh13Arrangement {
    public let front: [Card]   // Chi 1: 3 cards
    public let middle: [Card]  // Chi 2: 5 cards
    public let back: [Card]    // Chi 3: 5 cards
    
    public let frontScore: BinhFrontHandScore
    public let middleScore: PokerHandScore
    public let backScore: PokerHandScore
    
    public let isLung: Bool
    public let instantWin: BinhInstantWinType?
}

public class Binh13Evaluator {
    
    // Check instant win (Thắng trắng) strictly following precedence
    public static func checkInstantWin(cards: [Card]) -> BinhInstantWinType? {
        guard cards.count == 13 else { return nil }
        let sorted = cards.sorted { $0.rank.rawValue < $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        let suits = sorted.map { $0.suit }
        
        let isDragonRanks = ranks == Array(2...14) // 2 to Ace
        
        // 1. Rồng cuốn: 2->A same suit
        if isDragonRanks && suits.allSatisfy({ $0 == suits[0] }) {
            return .rongCuon
        }
        
        // 2. Sảnh rồng: 2->A different suits
        if isDragonRanks {
            return .sanhRong
        }
        
        // 3. Đồng hoa 13 lá (all red or all black)
        let allRed = suits.allSatisfy { $0.isRed }
        let allBlack = suits.allSatisfy { !$0.isRed }
        if allRed || allBlack {
            return .dongHoa13
        }
        
        // Count pairs and triples
        var counts = [Int: Int]()
        for r in ranks { counts[r, default: 0] += 1 }
        let pairs = counts.filter { $0.value >= 2 }.count
        let triples = counts.filter { $0.value >= 3 }.count
        let quads = counts.filter { $0.value == 4 }.count
        
        // 4. 5 đôi 1 sám (5 pairs + 1 three of a kind)
        if triples >= 1 && (pairs >= 6 || (pairs == 5 && quads == 0)) {
            // e.g. 3 of a kind + 5 other pairs = 3 + 10 = 13 cards!
            if triples == 1 && counts.values.filter({ $0 == 2 }).count == 5 {
                return .namDoiMotSam
            }
        }
        
        // 5. Lục phé bôn (6 pairs + 1 single card)
        // Note: quad counts as 2 pairs
        let totalPairs = counts.values.reduce(0) { $0 + ($1 / 2) }
        if totalPairs == 6 {
            return .lucPheBon
        }
        
        return nil
    }
    
    public static func evaluateFrontHand(_ cards: [Card]) -> BinhFrontHandScore {
        guard cards.count == 3 else {
            return BinhFrontHandScore(type: .highCard, primaryRank: 0, kickers: [], cards: cards)
        }
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sorted.map { $0.rank.rawValue }
        
        // Triple
        if ranks[0] == ranks[1] && ranks[1] == ranks[2] {
            return BinhFrontHandScore(type: .threeOfAKind, primaryRank: ranks[0], kickers: [], cards: sorted)
        }
        // Pair
        if ranks[0] == ranks[1] {
            return BinhFrontHandScore(type: .onePair, primaryRank: ranks[0], kickers: [ranks[2]], cards: sorted)
        }
        if ranks[1] == ranks[2] {
            return BinhFrontHandScore(type: .onePair, primaryRank: ranks[1], kickers: [ranks[0]], cards: sorted)
        }
        // High card
        return BinhFrontHandScore(type: .highCard, primaryRank: ranks[0], kickers: [ranks[1], ranks[2]], cards: sorted)
    }
    
    // Compare Front (3 cards) with Middle (5 cards) to check lủng
    // Condition: Middle >= Front
    public static func isMiddleGreaterOrEqual(middle: PokerHandScore, front: BinhFrontHandScore) -> Bool {
        // Front can only be HighCard, Pair, or ThreeOfAKind
        switch front.type {
        case .threeOfAKind:
            // Middle must be at least ThreeOfAKind with higher/equal rank, or Straight, Flush, FullHouse, Quad, StraightFlush
            if middle.handType < .threeOfAKind { return false }
            if middle.handType == .threeOfAKind {
                return middle.tieBreakers[0] >= front.primaryRank
            }
            return true
            
        case .onePair:
            if middle.handType < .onePair { return false }
            if middle.handType == .onePair {
                if middle.tieBreakers[0] > front.primaryRank { return true }
                if middle.tieBreakers[0] < front.primaryRank { return false }
                // Equal pair rank -> compare kickers
                return middle.tieBreakers[1] >= (front.kickers.first ?? 0)
            }
            return true
            
        case .highCard:
            if middle.handType > .highCard { return true }
            return middle.tieBreakers[0] >= front.primaryRank
        }
    }
    
    // Check if Back >= Middle
    public static func isBackGreaterOrEqual(back: PokerHandScore, middle: PokerHandScore) -> Bool {
        return back >= middle
    }
    
    // Auto-arrange 13 cards to find the strongest valid (non-lung) arrangement
    public static func autoArrange(cards: [Card]) -> Binh13Arrangement {
        // Nhóm A: Instant-check trực tiếp từ 13 lá thô (không cần xếp chi)
        if let instant = checkInstantWin(cards: cards) {
            let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
            let front = Array(sorted[0..<3])
            let mid = Array(sorted[3..<8])
            let back = Array(sorted[8..<13])
            return Binh13Arrangement(
                front: front, middle: mid, back: back,
                frontScore: evaluateFrontHand(front),
                middleScore: PokerEvaluator.evaluate5Cards(mid),
                backScore: PokerEvaluator.evaluate5Cards(back),
                isLung: false, instantWin: instant
            )
        }
        
        let all5CombosIndices = PokerEvaluator.combinations(of: Array(0..<13), k: 5)
        var bestArrangement: Binh13Arrangement? = nil
        var bestWeight = -999999
        var foundGroupBInstant: Binh13Arrangement? = nil
        
        for backIndices in all5CombosIndices {
            let backCards = backIndices.map { cards[$0] }
            let backScore = PokerEvaluator.evaluate5Cards(backCards)
            
            let remainingIndices = (0..<13).filter { !backIndices.contains($0) }
            let middle5CombosIndices = PokerEvaluator.combinations(of: remainingIndices, k: 5)
            
            for midIndices in middle5CombosIndices {
                let midCards = midIndices.map { cards[$0] }
                let midScore = PokerEvaluator.evaluate5Cards(midCards)
                
                // Prune: Back must >= Middle
                guard isBackGreaterOrEqual(back: backScore, middle: midScore) else { continue }
                
                let frontIndices = remainingIndices.filter { !midIndices.contains($0) }
                let frontCards = frontIndices.map { cards[$0] }
                let frontScore = evaluateFrontHand(frontCards)
                
                // Prune: Middle must >= Front
                guard isMiddleGreaterOrEqual(middle: midScore, front: frontScore) else { continue }
                
                // Nhóm B: Kiểm tra Ba Cái Thùng / Ba Cái Sảnh phụ thuộc vào cách xếp chi hợp lệ
                let isFrontFlush = (frontCards[0].suit == frontCards[1].suit && frontCards[1].suit == frontCards[2].suit)
                let isMidFlush = (midScore.handType == .flush || midScore.handType >= .straightFlush)
                let isBackFlush = (backScore.handType == .flush || backScore.handType >= .straightFlush)
                
                let isFrontStraight: Bool = {
                    let sortedF = frontCards.sorted { $0.rank.rawValue > $1.rank.rawValue }
                    let rf = sortedF.map { $0.rank.rawValue }
                    return (rf[0] - rf[1] == 1 && rf[1] - rf[2] == 1) || (rf == [14, 3, 2])
                }()
                let isMidStraight = (midScore.handType == .straight || midScore.handType >= .straightFlush)
                let isBackStraight = (backScore.handType == .straight || backScore.handType >= .straightFlush)
                
                var groupBWin: BinhInstantWinType? = nil
                if isBackFlush && isMidFlush && isFrontFlush {
                    groupBWin = .baThung
                } else if isBackStraight && isMidStraight && isFrontStraight {
                    groupBWin = .baSanh
                }
                
                if let gB = groupBWin {
                    let arrGB = Binh13Arrangement(
                        front: frontCards, middle: midCards, back: backCards,
                        frontScore: frontScore, middleScore: midScore, backScore: backScore,
                        isLung: false, instantWin: gB
                    )
                    if foundGroupBInstant == nil || (gB > (foundGroupBInstant?.instantWin ?? .baSanh)) {
                        foundGroupBInstant = arrGB
                    }
                }
                
                // Heuristic weight for standard arrangement
                var weight = 0
                weight += backScore.handType.rawValue * 1000 + backScore.tieBreakers[0] * 10
                weight += midScore.handType.rawValue * 1500 + midScore.tieBreakers[0] * 15
                weight += frontScore.type.rawValue * 2000 + frontScore.primaryRank * 20
                
                if frontScore.type == .threeOfAKind { weight += 5000 }
                if midScore.handType == .fullHouse { weight += 4000 }
                if midScore.handType == .fourOfAKind { weight += 15000 }
                if backScore.handType == .fourOfAKind { weight += 8000 }
                if backScore.handType >= .straightFlush { weight += 10000 }
                
                if weight > bestWeight {
                    bestWeight = weight
                    bestArrangement = Binh13Arrangement(
                        front: frontCards, middle: midCards, back: backCards,
                        frontScore: frontScore, middleScore: midScore, backScore: backScore,
                        isLung: false, instantWin: nil
                    )
                }
            }
        }
        
        // Priority: Nhóm B Thắng Trắng (Ba Thùng / Ba Sảnh) > Xếp bài thường
        if let gB = foundGroupBInstant {
            return gB
        }
        
        if let best = bestArrangement {
            return best
        }
        
        // Fallback: Lung
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let front = Array(sorted[0..<3])
        let mid = Array(sorted[3..<8])
        let back = Array(sorted[8..<13])
        return Binh13Arrangement(
            front: front, middle: mid, back: back,
            frontScore: evaluateFrontHand(front),
            middleScore: PokerEvaluator.evaluate5Cards(mid),
            backScore: PokerEvaluator.evaluate5Cards(back),
            isLung: true, instantWin: nil
        )
    }
    
    // Tính tổng bonus hàng hợp lệ mà một người sở hữu
    public static func calculateInherentBonus(arr: Binh13Arrangement) -> (total: Int, detail: String) {
        guard !arr.isLung && arr.instantWin == nil else { return (0, "") }
        var bonus = 0
        var parts: [String] = []
        if arr.frontScore.type == .threeOfAKind {
            bonus += 3
            parts.append("Sám chi đầu (+3 chi)")
        }
        if arr.middleScore.handType == .fullHouse {
            bonus += 2
            parts.append("Cù lũ chi 2 (+2 chi)")
        } else if arr.middleScore.handType == .fourOfAKind {
            bonus += 8
            parts.append("Tứ quý chi 2 (+8 chi)")
        } else if arr.middleScore.handType >= .straightFlush {
            bonus += 10
            parts.append("Thùng phá sảnh chi 2 (+10 chi)")
        }
        if arr.backScore.handType == .fourOfAKind {
            bonus += 4
            parts.append("Tứ quý chi 3 (+4 chi)")
        } else if arr.backScore.handType >= .straightFlush {
            bonus += 5
            parts.append("Thùng phá sảnh chi 3 (+5 chi)")
        }
        return (bonus, parts.joined(separator: ", "))
    }
    
    // Compare two players A and B
    public static func compareMatch(a: Binh13Arrangement, b: Binh13Arrangement) -> (scoreA: Int, detail: String) {
        // 1. Thắng Trắng vs Thắng Trắng: So bậc ưu tiên
        if let winA = a.instantWin, let winB = b.instantWin {
            if winA > winB {
                return (winA.bonusChips, "\(winA.nameVN) thắng \(winB.nameVN) (+\(winA.bonusChips) chi)")
            } else if winA < winB {
                return (-winB.bonusChips, "\(winA.nameVN) thua \(winB.nameVN) (-\(winB.bonusChips) chi)")
            } else {
                return (0, "Hòa Thắng Trắng: Cả 2 cùng có \(winA.nameVN)")
            }
        }
        // 2. Thắng Trắng vs Bài thường: Thắng trắng luôn thắng tuyệt đối không cần so chi
        if let winA = a.instantWin {
            return (winA.bonusChips, "\(winA.nameVN) thắng tuyệt đối bài thường (+\(winA.bonusChips) chi)")
        }
        if let winB = b.instantWin {
            return (-winB.bonusChips, "Đối thủ có \(winB.nameVN) thắng tuyệt đối (-\(winB.bonusChips) chi)")
        }
        
        // 3. Xử lý Lủng
        if a.isLung && b.isLung {
            return (0, "Cả hai đều bị Lủng (0 chi)")
        }
        if a.isLung {
            // A lủng: Thua phạt 6 chi cơ bản + đền toàn bộ hàng hợp lệ của B
            let (bBonus, bDetail) = calculateInherentBonus(arr: b)
            let totalLoss = -(6 + bBonus)
            let detailStr = bBonus > 0 ? "Bị Lủng (phạt 6 chi + đền hàng đối thủ [\(bDetail)]: \(totalLoss) chi)" : "Bị Lủng (phạt thua 3 chi x2 = -6 chi)"
            return (totalLoss, detailStr)
        }
        if b.isLung {
            let (aBonus, aDetail) = calculateInherentBonus(arr: a)
            let totalWin = 6 + aBonus
            let detailStr = aBonus > 0 ? "Đối thủ bị Lủng (thắng 6 chi + nhận hàng [\(aDetail)]: +\(totalWin) chi)" : "Đối thủ bị Lủng (thắng 3 chi x2 = +6 chi)"
            return (totalWin, detailStr)
        }
        
        // 4. So sánh từng chi bài thường
        // Chi 1 (Front 3 cards)
        var chi1Win = 0
        var chi1Bonus = 0
        if a.frontScore > b.frontScore {
            chi1Win = 1
            if a.frontScore.type == .threeOfAKind {
                // Đè hàng nếu B cũng có Sám cô chi đầu
                chi1Bonus = (b.frontScore.type == .threeOfAKind) ? 6 : 3
            }
        } else if a.frontScore < b.frontScore {
            chi1Win = -1
            if b.frontScore.type == .threeOfAKind {
                chi1Bonus = (a.frontScore.type == .threeOfAKind) ? -6 : -3
            }
        }
        
        // Chi 2 (Middle 5 cards)
        var chi2Win = 0
        var chi2Bonus = 0
        if a.middleScore > b.middleScore {
            chi2Win = 1
            if a.middleScore.handType == .fullHouse {
                // Đè hàng cù lũ chỉ khi B cũng cù lũ
                chi2Bonus = (b.middleScore.handType == .fullHouse) ? 4 : 2
            } else if a.middleScore.handType == .fourOfAKind {
                // Đè hàng tứ quý chỉ khi B cũng tứ quý
                chi2Bonus = (b.middleScore.handType == .fourOfAKind) ? 16 : 8
            } else if a.middleScore.handType >= .straightFlush {
                // Đè hàng thùng phá sảnh chỉ khi B cũng thùng phá sảnh
                chi2Bonus = (b.middleScore.handType >= .straightFlush) ? 20 : 10
            }
        } else if a.middleScore < b.middleScore {
            chi2Win = -1
            if b.middleScore.handType == .fullHouse {
                chi2Bonus = (a.middleScore.handType == .fullHouse) ? -4 : -2
            } else if b.middleScore.handType == .fourOfAKind {
                chi2Bonus = (a.middleScore.handType == .fourOfAKind) ? -16 : -8
            } else if b.middleScore.handType >= .straightFlush {
                chi2Bonus = (a.middleScore.handType >= .straightFlush) ? -20 : -10
            }
        }
        
        // Chi 3 (Back 5 cards)
        var chi3Win = 0
        var chi3Bonus = 0
        if a.backScore > b.backScore {
            chi3Win = 1
            if a.backScore.handType == .fourOfAKind {
                // Đè hàng tứ quý chi cuối
                chi3Bonus = (b.backScore.handType == .fourOfAKind) ? 8 : 4
            } else if a.backScore.handType >= .straightFlush {
                // Đè hàng thùng phá sảnh chi cuối
                chi3Bonus = (b.backScore.handType >= .straightFlush) ? 10 : 5
            }
        } else if a.backScore < b.backScore {
            chi3Win = -1
            if b.backScore.handType == .fourOfAKind {
                chi3Bonus = (a.backScore.handType == .fourOfAKind) ? -8 : -4
            } else if b.backScore.handType >= .straightFlush {
                chi3Bonus = (a.backScore.handType >= .straightFlush) ? -10 : -5
            }
        }
        
        var baseChi = chi1Win + chi2Win + chi3Win
        var sapHamText = ""
        if chi1Win > 0 && chi2Win > 0 && chi3Win > 0 {
            baseChi = 6
            sapHamText = " (Bắt sập hầm x2 = +6 chi)"
        } else if chi1Win < 0 && chi2Win < 0 && chi3Win < 0 {
            baseChi = -6
            sapHamText = " (Bị sập hầm x2 = -6 chi)"
        }
        
        let totalBonus = chi1Bonus + chi2Bonus + chi3Bonus
        let totalScore = baseChi + totalBonus
        
        let detail = "Chi 1: \(chi1Win > 0 ? "+1" : "\(chi1Win)"), Chi 2: \(chi2Win > 0 ? "+1" : "\(chi2Win)"), Chi 3: \(chi3Win > 0 ? "+1" : "\(chi3Win)")\(sapHamText)\(totalBonus != 0 ? ", Hàng: \(totalBonus > 0 ? "+\(totalBonus)" : "\(totalBonus)") chi" : "") -> Tổng: \(totalScore > 0 ? "+\(totalScore)" : "\(totalScore)") chi"
        
        return (totalScore, detail)
    }
}

}
