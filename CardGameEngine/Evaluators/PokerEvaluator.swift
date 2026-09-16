import Foundation

public enum PokerHandType: Int, Comparable, Codable {
    case highCard = 1
    case onePair = 2
    case twoPair = 3
    case threeOfAKind = 4
    case straight = 5
    case flush = 6
    case fullHouse = 7
    case fourOfAKind = 8
    case straightFlush = 9
    case royalFlush = 10
    
    public var nameVN: String {
        switch self {
        case .highCard: return "Mậu thầu (High Card)"
        case .onePair: return "Một đôi (One Pair)"
        case .twoPair: return "Hai đôi (Two Pair)"
        case .threeOfAKind: return "Sám cô (Three of a Kind)"
        case .straight: return "Sảnh (Straight)"
        case .flush: return "Thùng (Flush)"
        case .fullHouse: return "Cù lũ (Full House)"
        case .fourOfAKind: return "Tứ quý (Four of a Kind)"
        case .straightFlush: return "Thùng phá sảnh (Straight Flush)"
        case .royalFlush: return "Thùng phá sảnh lớn (Royal Flush)"
        }
    }
    
    public static func < (lhs: PokerHandType, rhs: PokerHandType) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct PokerHandScore: Comparable {
    public let handType: PokerHandType
    public let tieBreakers: [Int] // Vector [primaryRank, secondaryRank, kicker1, kicker2...]
    public let cards: [Card] // The 5 cards making this hand
    public let descriptionVN: String
    
    public static func < (lhs: PokerHandScore, rhs: PokerHandScore) -> Bool {
        if lhs.handType != rhs.handType {
            return lhs.handType < rhs.handType
        }
        for i in 0..<min(lhs.tieBreakers.count, rhs.tieBreakers.count) {
            if lhs.tieBreakers[i] != rhs.tieBreakers[i] {
                return lhs.tieBreakers[i] < rhs.tieBreakers[i]
            }
        }
        return false
    }
    
    public static func == (lhs: PokerHandScore, rhs: PokerHandScore) -> Bool {
        if lhs.handType != rhs.handType { return false }
        if lhs.tieBreakers.count != rhs.tieBreakers.count { return false }
        for i in 0..<lhs.tieBreakers.count {
            if lhs.tieBreakers[i] != rhs.tieBreakers[i] { return false }
        }
        return true
    }
}

public class PokerEvaluator {
    
    // Evaluate exactly 5 cards
    public static func evaluate5Cards(_ cards: [Card]) -> PokerHandScore {
        guard cards.count == 5 else {
            return PokerHandScore(handType: .highCard, tieBreakers: [0], cards: cards, descriptionVN: "Không đủ 5 lá")
        }
        
        let sortedCards = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        let ranks = sortedCards.map { $0.rank.rawValue }
        let suits = sortedCards.map { $0.suit }
        
        // Check flush
        let isFlush = suits.allSatisfy { $0 == suits[0] }
        
        // Check straight (including Wheel: A-2-3-4-5)
        var isStraight = false
        var straightHigh = 0
        
        // Case 1: Standard consecutive (e.g. 10-9-8-7-6)
        if ranks[0] - ranks[1] == 1 &&
           ranks[1] - ranks[2] == 1 &&
           ranks[2] - ranks[3] == 1 &&
           ranks[3] - ranks[4] == 1 {
            isStraight = true
            straightHigh = ranks[0]
        }
        // Case 2: Wheel (A-5-4-3-2) -> [14, 5, 4, 3, 2]
        else if ranks == [14, 5, 4, 3, 2] {
            isStraight = true
            straightHigh = 5 // In wheel straight, 5 is high!
        }
        
        // Group by rank counts
        var rankCounts = [Int: Int]()
        for r in ranks {
            rankCounts[r, default: 0] += 1
        }
        
        // Sort groups: first by count descending, then by rank descending
        let grouped = rankCounts.map { (rank: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.rank > $1.rank
            }
        
        let rankSymbol: (Int) -> String = { r in
            Rank(rawValue: r)?.displaySymbol ?? "\(r)"
        }
        
        // 1. Royal Flush / Straight Flush
        if isFlush && isStraight {
            if straightHigh == 14 {
                return PokerHandScore(
                    handType: .royalFlush,
                    tieBreakers: [14],
                    cards: sortedCards,
                    descriptionVN: "Thùng phá sảnh lớn (Royal Flush)"
                )
            } else {
                return PokerHandScore(
                    handType: .straightFlush,
                    tieBreakers: [straightHigh],
                    cards: sortedCards,
                    descriptionVN: "Thùng phá sảnh đỉnh \(rankSymbol(straightHigh))"
                )
            }
        }
        
        // 2. Four of a Kind
        if grouped[0].count == 4 {
            let quadRank = grouped[0].rank
            let kicker = grouped[1].rank
            return PokerHandScore(
                handType: .fourOfAKind,
                tieBreakers: [quadRank, kicker],
                cards: sortedCards,
                descriptionVN: "Tứ quý \(rankSymbol(quadRank)) (Kicker \(rankSymbol(kicker)))"
            )
        }
        
        // 3. Full House
        if grouped[0].count == 3 && grouped[1].count == 2 {
            let triple = grouped[0].rank
            let pair = grouped[1].rank
            return PokerHandScore(
                handType: .fullHouse,
                tieBreakers: [triple, pair],
                cards: sortedCards,
                descriptionVN: "Cù lũ \(rankSymbol(triple)) bu \(rankSymbol(pair))"
            )
        }
        
        // 4. Flush
        if isFlush {
            return PokerHandScore(
                handType: .flush,
                tieBreakers: ranks,
                cards: sortedCards,
                descriptionVN: "Thùng chất \(suits[0].nameVN) (Đỉnh \(rankSymbol(ranks[0])))"
            )
        }
        
        // 5. Straight
        if isStraight {
            let desc = straightHigh == 5 ? "Sảnh bánh xe (A-2-3-4-5)" : "Sảnh đỉnh \(rankSymbol(straightHigh))"
            return PokerHandScore(
                handType: .straight,
                tieBreakers: [straightHigh],
                cards: sortedCards,
                descriptionVN: desc
            )
        }
        
        // 6. Three of a kind
        if grouped[0].count == 3 {
            let triple = grouped[0].rank
            let kickers = [grouped[1].rank, grouped[2].rank]
            return PokerHandScore(
                handType: .threeOfAKind,
                tieBreakers: [triple] + kickers,
                cards: sortedCards,
                descriptionVN: "Sám cô \(rankSymbol(triple)) (Kicker \(rankSymbol(kickers[0])), \(rankSymbol(kickers[1])))"
            )
        }
        
        // 7. Two Pair
        if grouped[0].count == 2 && grouped[1].count == 2 {
            let highPair = max(grouped[0].rank, grouped[1].rank)
            let lowPair = min(grouped[0].rank, grouped[1].rank)
            let kicker = grouped[2].rank
            return PokerHandScore(
                handType: .twoPair,
                tieBreakers: [highPair, lowPair, kicker],
                cards: sortedCards,
                descriptionVN: "Hai đôi (\(rankSymbol(highPair)) & \(rankSymbol(lowPair))) - Kicker \(rankSymbol(kicker))"
            )
        }
        
        // 8. One Pair
        if grouped[0].count == 2 {
            let pair = grouped[0].rank
            let kickers = [grouped[1].rank, grouped[2].rank, grouped[3].rank]
            return PokerHandScore(
                handType: .onePair,
                tieBreakers: [pair] + kickers,
                cards: sortedCards,
                descriptionVN: "Một đôi \(rankSymbol(pair)) (Kickers: \(kickers.map(rankSymbol).joined(separator: ", ")))"
            )
        }
        
        // 9. High card
        return PokerHandScore(
            handType: .highCard,
            tieBreakers: ranks,
            cards: sortedCards,
            descriptionVN: "Mậu thầu \(rankSymbol(ranks[0])) cao nhất"
        )
    }
    
    // Choose k combinations out of array
    public static func combinations<T>(of array: [T], k: Int) -> [[T]] {
        guard k > 0 else { return [[]] }
        guard !array.isEmpty else { return [] }
        
        if k == 1 {
            return array.map { [$0] }
        }
        
        var result = [[T]]()
        let head = array[0]
        let sub = Array(array.dropFirst())
        
        let subCombos = combinations(of: sub, k: k - 1)
        for c in subCombos {
            result.append([head] + c)
        }
        result.append(contentsOf: combinations(of: sub, k: k))
        return result
    }
    
    // Evaluate 7 cards (Texas Hold'em or 7 Card Stud)
    public static func evaluate7Cards(_ cards: [Card]) -> PokerHandScore {
        guard cards.count >= 5 else {
            return evaluate5Cards(cards)
        }
        let all5Combos = combinations(of: cards, k: 5)
        var bestHand: PokerHandScore? = nil
        
        for combo in all5Combos {
            let handScore = evaluate5Cards(combo)
            if bestHand == nil || handScore > bestHand! {
                bestHand = handScore
            }
        }
        return bestHand!
    }
}
