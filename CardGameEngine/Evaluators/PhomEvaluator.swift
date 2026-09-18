import Foundation

public struct PhomHand: Identifiable {
    public let id = UUID()
    public let cards: [Card]
    public let isVertical: Bool // true: Phỏm dọc (sảnh), false: Phỏm ngang (bộ cùng số)
    
    public var description: String {
        let names = cards.map { "\($0.rank.displaySymbol)\($0.suit.rawValue)" }.joined(separator: " ")
        return "\(isVertical ? "Phỏm dọc" : "Phỏm ngang") (\(names))"
    }
}

public struct PhomResult {
    public let isU: Bool
    public let isUTron: Bool       // 10 lá Ù tròn (thưởng x2)
    public let isUKhan: Bool       // Ù khan (9 lá không cạ)
    public let isMom: Bool
    public let phoms: [PhomHand]
    public let deadwood: [Card]
    public let deadwoodScore: Int
    public let discardedCard: Card? // Với bài 10 lá: lá rác tối ưu được gợi ý đánh ra
    public let summary: String
    
    public init(
        isU: Bool,
        isUTron: Bool = false,
        isUKhan: Bool = false,
        isMom: Bool,
        phoms: [PhomHand],
        deadwood: [Card],
        deadwoodScore: Int,
        discardedCard: Card? = nil,
        summary: String
    ) {
        self.isU = isU
        self.isUTron = isUTron
        self.isUKhan = isUKhan
        self.isMom = isMom
        self.phoms = phoms
        self.deadwood = deadwood
        self.deadwoodScore = deadwoodScore
        self.discardedCard = discardedCard
        self.summary = summary
    }
}

public struct PhomEvaluator {
    
    /// Điểm của từng lá bài rác trong Phỏm: A = 1, 2-10 = 2-10, J = 11, Q = 12, K = 13
    public static func cardPoint(_ card: Card) -> Int {
        switch card.rank {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 1
        }
    }
    
    /// Kiểm tra 2 lá bài có tạo thành "Cạ" (chờ phỏm) hay không
    public static func hasCa(_ c1: Card, _ c2: Card) -> Bool {
        // Cùng rank -> Cạ đôi
        if c1.rank == c2.rank { return true }
        
        // Cùng chất -> Xét cạ sảnh (liền kề hoặc cách 1 lá)
        if c1.suit == c2.suit {
            let v1 = c1.rank == .ace ? 1 : c1.rank.rawValue
            let v2 = c2.rank == .ace ? 1 : c2.rank.rawValue
            if abs(v1 - v2) <= 2 { return true }
            
            // Xét Ace high: Q(12)-A(14) diff 2, K(13)-A(14) diff 1
            let h1 = c1.rank.rawValue
            let h2 = c2.rank.rawValue
            if abs(h1 - h2) <= 2 { return true }
        }
        return false
    }
    
    /// Kiểm tra Ù Khan (Toàn bộ bài không có bất kỳ cạ đôi hoặc cạ sảnh nào)
    public static func checkUKhan(_ cards: [Card]) -> Bool {
        guard cards.count >= 9 else { return false }
        for i in 0..<cards.count {
            for j in (i + 1)..<cards.count {
                if hasCa(cards[i], cards[j]) {
                    return false
                }
            }
        }
        return true
    }
    
    /// Đánh giá bộ bài Phỏm (Hỗ trợ cả 9 lá chuẩn và 10 lá của tụ đi đầu / Ù tròn)
    public static func evaluate(cards: [Card]) -> PhomResult {
        guard !cards.isEmpty else {
            return PhomResult(isU: false, isMom: true, phoms: [], deadwood: [], deadwoodScore: 0, summary: "Không có bài")
        }
        
        // TRƯỜNG HỢP BÀI 10 LÁ
        if cards.count == 10 {
            // 1. Kiểm tra Ù Tròn 10 lá (toàn bộ 10 lá ghép tròn vào các phỏm, 0 rác)
            let all10Phoms = findAllCandidatePhoms(cards)
            var uTronPhoms: [PhomHand] = []
            var isUTron = false
            
            func search10(startIndex: Int, currentPhoms: [PhomHand], usedCardIds: Set<String>) {
                let rem = cards.filter { !usedCardIds.contains($0.id) }
                if rem.isEmpty && !currentPhoms.isEmpty {
                    isUTron = true
                    uTronPhoms = currentPhoms
                    return
                }
                for i in startIndex..<all10Phoms.count {
                    if isUTron { return }
                    let cand = all10Phoms[i]
                    let candIds = Set(cand.cards.map { $0.id })
                    if usedCardIds.isDisjoint(with: candIds) {
                        search10(
                            startIndex: i + 1,
                            currentPhoms: currentPhoms + [cand],
                            usedCardIds: usedCardIds.union(candIds)
                        )
                    }
                }
            }
            
            search10(startIndex: 0, currentPhoms: [], usedCardIds: [])
            if isUTron {
                let desc = uTronPhoms.map { $0.description }.joined(separator: " + ")
                return PhomResult(
                    isU: true,
                    isUTron: true,
                    isUKhan: false,
                    isMom: false,
                    phoms: uTronPhoms,
                    deadwood: [],
                    deadwoodScore: 0,
                    discardedCard: nil,
                    summary: "🎉 Ù Tròn (10 lá, 0 rác, thưởng x2) [\(desc)]"
                )
            }
            
            // 2. Không Ù tròn -> Tự động tìm phương án đánh 1 lá rác tối ưu nhất (giữ 9 lá tốt nhất)
            var bestSubResult: PhomResult? = nil
            var bestDiscarded: Card? = nil
            
            for i in 0..<cards.count {
                var subCards = cards
                let discarded = subCards.remove(at: i)
                let subResult = evaluateStandard9(subCards)
                
                if bestSubResult == nil {
                    bestSubResult = subResult
                    bestDiscarded = discarded
                } else if let currBest = bestSubResult {
                    // Ưu tiên: Ù > Có phỏm ít rác > Móm ít rác
                    var isBetter = false
                    if subResult.isU && !currBest.isU {
                        isBetter = true
                    } else if !subResult.isU && currBest.isU {
                        isBetter = false
                    } else if !subResult.isMom && currBest.isMom {
                        isBetter = true
                    } else if subResult.isMom && !currBest.isMom {
                        isBetter = false
                    } else if subResult.deadwoodScore < currBest.deadwoodScore {
                        isBetter = true
                    }
                    
                    if isBetter {
                        bestSubResult = subResult
                        bestDiscarded = discarded
                    }
                }
            }
            
            if let bestSub = bestSubResult, let discard = bestDiscarded {
                return PhomResult(
                    isU: bestSub.isU,
                    isUTron: false,
                    isUKhan: bestSub.isUKhan,
                    isMom: bestSub.isMom,
                    phoms: bestSub.phoms,
                    deadwood: bestSub.deadwood,
                    deadwoodScore: bestSub.deadwoodScore,
                    discardedCard: discard,
                    summary: "Đánh \(discard.displayName) ➔ \(bestSub.summary)"
                )
            }
        }
        
        // TRƯỜNG HỢP BÀI 9 LÁ (HOẶC BÀI THƯỜNG)
        return evaluateStandard9(cards)
    }
    
    /// Đánh giá tiêu chuẩn cho bài 9 lá (hoặc bài dưới 10 lá)
    private static func evaluateStandard9(_ cards: [Card]) -> PhomResult {
        // 1. Tìm tất cả các ứng viên Phỏm hợp lệ
        let allPhoms = findAllCandidatePhoms(cards)
        
        // 2. Tìm tập hợp các Phỏm không trùng lá bài tối ưu nhất
        var bestPhoms: [PhomHand] = []
        var bestDeadwood: [Card] = cards
        var minDeadwoodScore = cards.reduce(0) { $0 + cardPoint($1) }
        var isU = false
        
        func search(startIndex: Int, currentPhoms: [PhomHand], usedCardIds: Set<String>) {
            let currentDeadwood = cards.filter { !usedCardIds.contains($0.id) }
            let currentScore = currentDeadwood.reduce(0) { $0 + cardPoint($1) }
            
            // Nếu Ù (0 lá rác) -> Tối ưu tuyệt đối
            if currentDeadwood.isEmpty && !currentPhoms.isEmpty {
                isU = true
                bestPhoms = currentPhoms
                bestDeadwood = []
                minDeadwoodScore = 0
                return
            }
            
            // Cập nhật cấu hình tốt nhất nếu có ít nhất 1 phỏm và điểm rác nhỏ hơn
            if !currentPhoms.isEmpty {
                if bestPhoms.isEmpty || currentScore < minDeadwoodScore {
                    minDeadwoodScore = currentScore
                    bestPhoms = currentPhoms
                    bestDeadwood = currentDeadwood
                }
            }
            
            for i in startIndex..<allPhoms.count {
                if isU { return }
                let candidate = allPhoms[i]
                let candIds = Set(candidate.cards.map { $0.id })
                
                if usedCardIds.isDisjoint(with: candIds) {
                    search(
                        startIndex: i + 1,
                        currentPhoms: currentPhoms + [candidate],
                        usedCardIds: usedCardIds.union(candIds)
                    )
                }
            }
        }
        
        search(startIndex: 0, currentPhoms: [], usedCardIds: [])
        
        var isMom = bestPhoms.isEmpty
        var isUKhan = false
        
        if isMom {
            bestDeadwood = cards
            minDeadwoodScore = cards.reduce(0) { $0 + cardPoint($1) }
            
            // Kiểm tra Ù Khan miền Nam
            if checkUKhan(cards) {
                isUKhan = true
                isU = true
                isMom = false
            }
        }
        
        var summary = ""
        if isUKhan {
            summary = "🎉 Ù Khan (9 lá không cạ, ăn cả làng!)"
        } else if isU {
            let phomDesc = bestPhoms.map { $0.description }.joined(separator: " + ")
            summary = "🎉 Ù (0 điểm rác) [\(phomDesc)]"
        } else if isMom {
            summary = "💀 Móm / Cháy (Không có phỏm, \(minDeadwoodScore) điểm rác)"
        } else {
            let phomDesc = bestPhoms.map { $0.description }.joined(separator: " + ")
            let deadwoodDesc = bestDeadwood.map { "\($0.rank.displaySymbol)\($0.suit.rawValue)" }.joined(separator: " ")
            summary = "\(bestPhoms.count) Phỏm [\(phomDesc)] | Rác (\(deadwoodDesc)): \(minDeadwoodScore) điểm"
        }
        
        return PhomResult(
            isU: isU,
            isUTron: false,
            isUKhan: isUKhan,
            isMom: isMom,
            phoms: bestPhoms,
            deadwood: bestDeadwood,
            deadwoodScore: minDeadwoodScore,
            discardedCard: nil,
            summary: summary
        )
    }
    
    /// Tìm tất cả các cụm 3 hoặc 4 lá bài có thể tạo thành 1 Phỏm
    private static func findAllCandidatePhoms(_ cards: [Card]) -> [PhomHand] {
        var candidates: [PhomHand] = []
        
        // A. Phỏm ngang (Cùng giá trị Rank, khác chất)
        let rankGroups = Dictionary(grouping: cards, by: { $0.rank })
        for (_, group) in rankGroups {
            if group.count == 3 {
                candidates.append(PhomHand(cards: group, isVertical: false))
            } else if group.count == 4 {
                candidates.append(PhomHand(cards: group, isVertical: false))
                for i in 0..<4 {
                    var subset = group
                    subset.remove(at: i)
                    candidates.append(PhomHand(cards: subset, isVertical: false))
                }
            }
        }
        
        // B. Phỏm dọc (Cùng chất Suit, giá trị liên tiếp >= 3 lá)
        let suitGroups = Dictionary(grouping: cards, by: { $0.suit })
        for (_, group) in suitGroups {
            guard group.count >= 3 else { continue }
            
            let sortedNormal = group.sorted { cardRankOrder($0.rank, aceHigh: false) < cardRankOrder($1.rank, aceHigh: false) }
            let runs = findConsecutiveRuns(sortedNormal, aceHigh: false)
            for run in runs {
                candidates.append(PhomHand(cards: run, isVertical: true))
            }
            
            // Kiểm tra trường hợp sảnh Q-K-A (Ace high) với unwrapping an toàn
            if let q = group.first(where: { $0.rank == .queen }),
               let k = group.first(where: { $0.rank == .king }),
               let a = group.first(where: { $0.rank == .ace }) {
                candidates.append(PhomHand(cards: [q, k, a], isVertical: true))
                if let j = group.first(where: { $0.rank == .jack }) {
                    candidates.append(PhomHand(cards: [j, q, k, a], isVertical: true))
                    if let t = group.first(where: { $0.rank == .ten }) {
                        candidates.append(PhomHand(cards: [t, j, q, k, a], isVertical: true))
                    }
                }
            }
        }
        
        return candidates
    }
    
    private static func cardRankOrder(_ rank: Rank, aceHigh: Bool) -> Int {
        switch rank {
        case .ace: return aceHigh ? 14 : 1
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        }
    }
    
    /// Tìm dãy bài liên tiếp (ĐÃ SỬA LỖI RANGE CRASH KHI i = n - 1)
    private static func findConsecutiveRuns(_ sortedCards: [Card], aceHigh: Bool) -> [[Card]] {
        var result: [[Card]] = []
        let n = sortedCards.count
        guard n >= 3 else { return result }
        
        // i chỉ chạy tới n - 3 để đảm bảo i + 2 < n, không bao giờ tạo Range ngược gây crash
        for i in 0..<(n - 2) {
            for j in (i + 2)..<n {
                let sub = Array(sortedCards[i...j])
                if isConsecutive(sub, aceHigh: aceHigh) {
                    result.append(sub)
                }
            }
        }
        return result
    }
    
    private static func isConsecutive(_ cards: [Card], aceHigh: Bool) -> Bool {
        guard cards.count >= 3 else { return false }
        for i in 0..<(cards.count - 1) {
            let val1 = cardRankOrder(cards[i].rank, aceHigh: aceHigh)
            let val2 = cardRankOrder(cards[i + 1].rank, aceHigh: aceHigh)
            if val2 != val1 + 1 {
                return false
            }
        }
        return true
    }
    
    /// So sánh và xếp hạng tất cả người chơi trong ván Phỏm (Chuẩn Miền Nam)
    public static func rankPlayers(players: [(index: Int, name: String, cards: [Card])]) -> [(index: Int, name: String, result: PhomResult, rank: Int, scoreDelta: Int)] {
        let evaluated = players.map { p in
            (index: p.index, name: p.name, result: evaluate(cards: p.cards))
        }
        
        // Thứ tự ưu tiên:
        // 1. Ù Tròn 10 lá
        // 2. Ù Khan / Ù thường
        // 3. Có Phỏm (Điểm rác ít hơn xếp trước)
        // 4. Móm (Điểm rác ít hơn xếp trước)
        let sorted = evaluated.sorted { a, b in
            if a.result.isUTron != b.result.isUTron {
                return a.result.isUTron
            }
            if a.result.isU != b.result.isU {
                return a.result.isU
            }
            if a.result.isMom != b.result.isMom {
                return !a.result.isMom
            }
            if a.result.deadwoodScore != b.result.deadwoodScore {
                return a.result.deadwoodScore < b.result.deadwoodScore
            }
            return a.index < b.index
        }
        
        let n = sorted.count
        var ranks = [Int](repeating: 1, count: n)
        var currentRank = 1
        for i in 0..<n {
            if i > 0 {
                let prev = sorted[i - 1]
                let curr = sorted[i]
                let isSame = (prev.result.isUTron == curr.result.isUTron) &&
                             (prev.result.isU == curr.result.isU) &&
                             (prev.result.isMom == curr.result.isMom) &&
                             (prev.result.deadwoodScore == curr.result.deadwoodScore)
                if !isSame {
                    currentRank = i + 1
                }
            }
            ranks[i] = currentRank
        }
        
        let hasUTron = sorted.contains(where: { $0.result.isUTron })
        let hasU = sorted.contains(where: { $0.result.isU })
        let rank1Count = ranks.filter { $0 == 1 }.count
        var deltas = [Int](repeating: 0, count: n)
        
        if hasUTron {
            // Ù Tròn: Ăn gấp đôi (+12 chi mỗi nhà thua)
            let uCount = sorted.filter { $0.result.isUTron }.count
            let nonUCount = n - uCount
            let totalPool = nonUCount * 12
            let winPerU = uCount > 0 ? totalPool / uCount : 0
            var remainder = uCount > 0 ? totalPool % uCount : 0
            
            for i in 0..<n {
                if sorted[i].result.isUTron {
                    deltas[i] = winPerU + (remainder > 0 ? 1 : 0)
                    if remainder > 0 { remainder -= 1 }
                } else {
                    deltas[i] = -12
                }
            }
        } else if hasU {
            // Ù thường / Ù khan: Ăn 6 chi mỗi nhà thua
            let uCount = sorted.filter { $0.result.isU }.count
            let nonUCount = n - uCount
            let totalPool = nonUCount * 6
            let winPerU = uCount > 0 ? totalPool / uCount : 0
            var remainder = uCount > 0 ? totalPool % uCount : 0
            
            for i in 0..<n {
                if sorted[i].result.isU {
                    deltas[i] = winPerU + (remainder > 0 ? 1 : 0)
                    if remainder > 0 { remainder -= 1 }
                } else {
                    deltas[i] = -6
                }
            }
        } else {
            // Tính chi chuẩn Miền Nam: Nhì -1, Ba -2, Bét -3, Móm phạt -4 chi
            var totalPool = 0
            for i in 0..<n {
                if ranks[i] > 1 {
                    var penalty = i
                    if sorted[i].result.isMom {
                        penalty = max(penalty + 1, 4) // Móm phạt tối thiểu 4 chi
                    }
                    if penalty < 1 { penalty = 1 }
                    deltas[i] = -penalty
                    totalPool += penalty
                }
            }
            
            if rank1Count > 0 {
                let winPerWinner = totalPool / rank1Count
                var remainder = totalPool % rank1Count
                for i in 0..<n {
                    if ranks[i] == 1 {
                        deltas[i] = winPerWinner + (remainder > 0 ? 1 : 0)
                        if remainder > 0 { remainder -= 1 }
                    }
                }
            }
        }
        
        var output: [(index: Int, name: String, result: PhomResult, rank: Int, scoreDelta: Int)] = []
        for (pos, item) in sorted.enumerated() {
            output.append((index: item.index, name: item.name, result: item.result, rank: ranks[pos], scoreDelta: deltas[pos]))
        }
        
        return output
    }
}
