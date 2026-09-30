import Foundation

public enum SamLocGroupType: String, CaseIterable, Identifiable {
    case trash = "Rác"
    case pair = "Đôi"
    case straight = "Sảnh"
    case threeOfAKind = "Sám (3 cây)"
    case fourOfAKind = "Tứ quý (4 cây)"
    
    public var id: String { rawValue }
    
    public var badgeColorHex: String {
        switch self {
        case .trash: return "#8E8E93" // Xám
        case .pair: return "#007AFF" // Xanh dương
        case .straight: return "#34C759" // Xanh lá
        case .threeOfAKind: return "#AF52DE" // Tím
        case .fourOfAKind: return "#FF9500" // Cam đậm
        }
    }
}

public struct SamLocGroup: Identifiable {
    public let id = UUID()
    public let type: SamLocGroupType
    public let title: String
    public let cards: [Card]
    
    public init(type: SamLocGroupType, title: String, cards: [Card]) {
        self.type = type
        self.title = title
        self.cards = cards
    }
}

public enum SamLocInstantWin: String {
    case sanhRong = "👑 Sảnh Rồng (10 lá liên tiếp)"
    case tuQuy2 = "👑 Tứ Quý 2 (Bốn con Heo)"
    case dongMau = "👑 Đồng Màu (10 lá cùng màu)"
    case namDoi = "👑 5 Đôi"
    case baSam = "👑 3 Sám Cô"
}

public struct SamLocResult {
    public let instantWin: SamLocInstantWin?
    public let groups: [SamLocGroup] // Ordered according to Option 1: Rác -> Đôi -> Sảnh -> Sám -> Tứ quý
    public let trashCards: [Card]
    public let trashCount: Int
    public let summary: String
    
    public init(
        instantWin: SamLocInstantWin? = nil,
        groups: [SamLocGroup],
        trashCards: [Card],
        trashCount: Int,
        summary: String
    ) {
        self.instantWin = instantWin
        self.groups = groups
        self.trashCards = trashCards
        self.trashCount = trashCount
        self.summary = summary
    }
}

public struct SamLocEvaluator {
    
    /// Giá trị độ mạnh quân bài trong Sâm Lốc: 3 = 3 ... K = 13, A = 14, 2 = 15 (2 là to nhất)
    public static func samRankValue(_ rank: Rank) -> Int {
        switch rank {
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
        case .ace: return 14
        case .two: return 15
        }
    }
    
    public static func rankDisplayName(_ rank: Rank) -> String {
        return rank.displaySymbol
    }
    
    // MARK: - Check Instant Win (Thắng Trắng)
    public static func checkInstantWin(cards: [Card]) -> SamLocInstantWin? {
        guard cards.count == 10 else { return nil }
        
        // 1. Tứ quý 2
        let twoCount = cards.filter { $0.rank == .two }.count
        if twoCount == 4 {
            return .tuQuy2
        }
        
        // 2. Đồng màu (10 lá đỏ hoặc 10 lá đen)
        let redCount = cards.filter { $0.suit.isRed }.count
        if redCount == 10 || redCount == 0 {
            return .dongMau
        }
        
        // 3. Sảnh Rồng (10 lá liên tiếp)
        let sortedRanks = Array(Set(cards.map { samRankValue($0.rank) })).sorted()
        if sortedRanks.count == 10 {
            // Trường hợp 3 -> Q (3,4,5,6,7,8,9,10,11,12) hoặc 4 -> K hoặc 5 -> A
            var isCont = true
            for i in 0..<9 {
                if sortedRanks[i+1] != sortedRanks[i] + 1 {
                    isCont = false
                    break
                }
            }
            if isCont { return .sanhRong }
            
            // Sảnh rồng con A-2-3..10
            let a2RankValues = Array(Set(cards.map { c -> Int in
                if c.rank == .ace { return 1 }
                if c.rank == .two { return 2 }
                return samRankValue(c.rank)
            })).sorted()
            if a2RankValues.count == 10 {
                var isA2Cont = true
                for i in 0..<9 {
                    if a2RankValues[i+1] != a2RankValues[i] + 1 {
                        isA2Cont = false
                        break
                    }
                }
                if isA2Cont { return .sanhRong }
            }
        }
        
        // 4. 5 Đôi
        let rankCounts = Dictionary(grouping: cards, by: { $0.rank }).mapValues { $0.count }
        let pairCount = rankCounts.values.filter { $0 >= 2 }.count
        let fourCount = rankCounts.values.filter { $0 == 4 }.count
        if (pairCount == 5) || (fourCount >= 1 && pairCount + fourCount >= 5) {
            // Count total pairs
            let totalPairs = rankCounts.values.reduce(0) { $0 + ($1 / 2) }
            if totalPairs == 5 {
                return .namDoi
            }
        }
        
        // 5. 3 Sám Cô (3 x 3 = 9 lá cùng rank)
        let samCount = rankCounts.values.reduce(0) { $0 + ($1 / 3) }
        if samCount >= 3 {
            return .baSam
        }
        
        return nil
    }
    
    // MARK: - Optimal Hand Arrangement
    /// Phân tích và nhóm 10 lá thành các bộ: Rác -> Đôi -> Sảnh -> Sám -> Tứ quý (Lựa chọn 1)
    public static func arrange(cards: [Card]) -> SamLocResult {
        guard !cards.isEmpty else {
            return SamLocResult(groups: [], trashCards: [], trashCount: 0, summary: "Chưa có bài")
        }
        
        let instant = checkInstantWin(cards: cards)
        
        // Tìm tổ hợp tốt nhất
        let bestCombos = findBestArrangement(cards: cards)
        
        // Tách các nhóm và sắp xếp theo Lựa chọn 1: [Rác] -> [Đôi] -> [Sảnh] -> [Sám] -> [Tứ quý]
        var trashGroup: SamLocGroup? = nil
        var pairGroups: [SamLocGroup] = []
        var straightGroups: [SamLocGroup] = []
        var threeGroups: [SamLocGroup] = []
        var fourGroups: [SamLocGroup] = []
        
        for combo in bestCombos {
            switch combo.type {
            case .trash:
                trashGroup = combo
            case .pair:
                pairGroups.append(combo)
            case .straight:
                straightGroups.append(combo)
            case .threeOfAKind:
                threeGroups.append(combo)
            case .fourOfAKind:
                fourGroups.append(combo)
            }
        }
        
        // Sắp xếp nội bộ từng nhóm từ nhỏ đến lớn
        pairGroups.sort {
            samRankValue($0.cards[0].rank) < samRankValue($1.cards[0].rank)
        }
        threeGroups.sort {
            samRankValue($0.cards[0].rank) < samRankValue($1.cards[0].rank)
        }
        fourGroups.sort {
            samRankValue($0.cards[0].rank) < samRankValue($1.cards[0].rank)
        }
        straightGroups.sort {
            let minA = $0.cards.map { samRankValue($0.rank) }.min() ?? 0
            let minB = $1.cards.map { samRankValue($0.rank) }.min() ?? 0
            return minA < minB
        }
        
        var finalGroups: [SamLocGroup] = []
        // 1. Rác (nằm đầu tiên bên trái)
        if let tr = trashGroup, !tr.cards.isEmpty {
            finalGroups.append(tr)
        }
        // 2. Đôi
        finalGroups.append(contentsOf: pairGroups)
        // 3. Sảnh
        finalGroups.append(contentsOf: straightGroups)
        // 4. Sám cô
        finalGroups.append(contentsOf: threeGroups)
        // 5. Tứ quý (nằm cuối cùng bên phải)
        finalGroups.append(contentsOf: fourGroups)
        
        let trashCards = trashGroup?.cards ?? []
        
        // Xây dựng mô tả tóm tắt
        var parts: [String] = []
        if let inst = instant {
            parts.append(inst.rawValue)
        }
        if !fourGroups.isEmpty {
            parts.append(fourGroups.map { $0.title }.joined(separator: ", "))
        }
        if !threeGroups.isEmpty {
            parts.append(threeGroups.map { $0.title }.joined(separator: ", "))
        }
        if !straightGroups.isEmpty {
            parts.append(straightGroups.map { $0.title }.joined(separator: ", "))
        }
        if !pairGroups.isEmpty {
            parts.append(pairGroups.map { $0.title }.joined(separator: ", "))
        }
        if !trashCards.isEmpty {
            let trNames = trashCards.map { $0.isRankOnly ? $0.rank.displaySymbol : "\($0.rank.displaySymbol)\($0.suit.rawValue)" }.joined(separator: " ")
            parts.append("Rác: \(trNames)")
        }
        
        let summary = parts.joined(separator: " | ")
        
        return SamLocResult(
            instantWin: instant,
            groups: finalGroups,
            trashCards: trashCards,
            trashCount: trashCards.count,
            summary: summary
        )
    }
    
    // MARK: - Search Combinations
    private struct Candidate {
        let type: SamLocGroupType
        let title: String
        let cards: [Card]
        let cardIds: Set<String>
    }
    
    private static func findBestArrangement(cards: [Card]) -> [SamLocGroup] {
        var candidates: [Candidate] = []
        
        // 1. Tứ quý (4 lá cùng rank)
        let rankGroups = Dictionary(grouping: cards, by: { $0.rank })
        for (rank, group) in rankGroups {
            if group.count == 4 {
                let sortedGroup = group.sorted { $0.suit.rawValue < $1.suit.rawValue }
                candidates.append(Candidate(
                    type: .fourOfAKind,
                    title: "Tứ quý \(rankDisplayName(rank))",
                    cards: sortedGroup,
                    cardIds: Set(sortedGroup.map { $0.id })
                ))
            }
        }
        
        // 2. Sám (3 lá cùng rank)
        for (rank, group) in rankGroups {
            if group.count >= 3 {
                let sub = Array(group.prefix(3))
                candidates.append(Candidate(
                    type: .threeOfAKind,
                    title: "Sám \(rankDisplayName(rank))",
                    cards: sub,
                    cardIds: Set(sub.map { $0.id })
                ))
            }
        }
        
        // 3. Sảnh (Dãy liên tiếp >= 3 lá, không chứa 2)
        let nonTwoCards = cards.filter { $0.rank != .two }
        let distinctRankCards = Dictionary(grouping: nonTwoCards, by: { samRankValue($0.rank) })
            .compactMap { $0.value.first }
            .sorted { samRankValue($0.rank) < samRankValue($1.rank) }
        
        if distinctRankCards.count >= 3 {
            for len in (3...distinctRankCards.count).reversed() {
                for i in 0...(distinctRankCards.count - len) {
                    let sub = Array(distinctRankCards[i..<(i + len)])
                    var isStraight = true
                    for k in 0..<(len - 1) {
                        if samRankValue(sub[k+1].rank) != samRankValue(sub[k].rank) + 1 {
                            isStraight = false
                            break
                        }
                    }
                    if isStraight {
                        let nameMin = rankDisplayName(sub.first!.rank)
                        let nameMax = rankDisplayName(sub.last!.rank)
                        candidates.append(Candidate(
                            type: .straight,
                            title: "Sảnh \(nameMin)-\(nameMax)",
                            cards: sub,
                            cardIds: Set(sub.map { $0.id })
                        ))
                    }
                }
            }
        }
        
        // Sảnh A-2-3 (Sảnh hạ tầng / sảnh con)
        if let a = cards.first(where: { $0.rank == .ace }),
           let two = cards.first(where: { $0.rank == .two }),
           let three = cards.first(where: { $0.rank == .three }) {
            let a23 = [a, two, three]
            candidates.append(Candidate(
                type: .straight,
                title: "Sảnh A-2-3",
                cards: a23,
                cardIds: Set(a23.map { $0.id })
            ))
        }
        
        // 4. Đôi (2 lá cùng rank)
        for (rank, group) in rankGroups {
            if group.count >= 2 {
                let sub = Array(group.prefix(2))
                candidates.append(Candidate(
                    type: .pair,
                    title: "Đôi \(rankDisplayName(rank))",
                    cards: sub,
                    cardIds: Set(sub.map { $0.id })
                ))
            }
        }
        
        // Thuật toán đệ quy chọn tập hợp các candidate không trùng lá
        // Mục tiêu:
        // 1. Tối đa số lá bài được vào bộ (số lá rác ít nhất).
        // 2. Nếu bằng số lá, ưu tiên bộ lớn hơn (Tứ quý > Sám > Sảnh > Đôi).
        var bestCombo: [Candidate] = []
        var maxCardsCovered = 0
        var bestScore = -1
        
        func evaluateScore(_ combo: [Candidate]) -> (cardsCovered: Int, weightScore: Int) {
            var covered = 0
            var weight = 0
            for c in combo {
                covered += c.cards.count
                switch c.type {
                case .fourOfAKind: weight += 1000
                case .threeOfAKind: weight += 400
                case .straight: weight += 300 + (c.cards.count * 10)
                case .pair: weight += 100
                case .trash: break
                }
            }
            return (covered, weight)
        }
        
        func search(startIndex: Int, currentCombo: [Candidate], usedIds: Set<String>) {
            let currentEval = evaluateScore(currentCombo)
            if currentEval.cardsCovered > maxCardsCovered ||
                (currentEval.cardsCovered == maxCardsCovered && currentEval.weightScore > bestScore) {
                maxCardsCovered = currentEval.cardsCovered
                bestScore = currentEval.weightScore
                bestCombo = currentCombo
            }
            
            for i in startIndex..<candidates.count {
                let cand = candidates[i]
                if cand.cardIds.isDisjoint(with: usedIds) {
                    var nextUsed = usedIds
                    nextUsed.formUnion(cand.cardIds)
                    search(startIndex: i + 1, currentCombo: currentCombo + [cand], usedIds: nextUsed)
                }
            }
        }
        
        search(startIndex: 0, currentCombo: [], usedIds: Set())
        
        // Xác định các lá rác còn lại
        var usedInBest = Set<String>()
        for c in bestCombo {
            usedInBest.formUnion(c.cardIds)
        }
        let trashCards = cards.filter { !usedInBest.contains($0.id) }
            .sorted { samRankValue($0.rank) < samRankValue($1.rank) }
        
        var resultGroups: [SamLocGroup] = []
        if !trashCards.isEmpty {
            resultGroups.append(SamLocGroup(
                type: .trash,
                title: "Rác",
                cards: trashCards
            ))
        }
        for b in bestCombo {
            resultGroups.append(SamLocGroup(
                type: b.type,
                title: b.title,
                cards: b.cards
            ))
        }
        
        return resultGroups
    }
    
    // MARK: - Rank All Players
    public static func rankPlayers(players: [(index: Int, name: String, cards: [Card])]) -> [(index: Int, name: String, result: SamLocResult, rank: Int, scoreDelta: Int)] {
        let evaluated = players.map { p in
            (index: p.index, name: p.name, result: arrange(cards: p.cards))
        }
        
        // Thứ tự ưu tiên:
        // 1. Thắng Trắng (Sảnh Rồng > Tứ Quý 2 > Đồng Màu > 5 Đôi > 3 Sám)
        // 2. Ít lá rác hơn xếp trên
        // 3. Nếu cùng số lá rác: người có lá rác cao nhất nhỏ hơn xếp trên (hoặc hòa)
        let sorted = evaluated.sorted { a, b in
            let aWin = a.result.instantWin
            let bWin = b.result.instantWin
            if (aWin != nil) != (bWin != nil) {
                return aWin != nil
            }
            if a.result.trashCount != b.result.trashCount {
                return a.result.trashCount < b.result.trashCount
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
                let isSame = (prev.result.instantWin == curr.result.instantWin) &&
                             (prev.result.trashCount == curr.result.trashCount)
                if !isSame {
                    currentRank = i + 1
                }
            }
            ranks[i] = currentRank
        }
        
        // Tính điểm:
        // Nếu có Thắng Trắng: Người thắng ăn 20 lá từ mỗi người thua
        // Nếu không: Nhì -1, Ba -2, Bét -3 (chuẩn)
        let hasInstant = sorted.contains(where: { $0.result.instantWin != nil })
        var deltas = [Int](repeating: 0, count: n)
        
        if hasInstant {
            let winCount = sorted.filter { $0.result.instantWin != nil }.count
            let lossCount = n - winCount
            let total = lossCount * 20
            let winPer = winCount > 0 ? total / winCount : 0
            var rem = winCount > 0 ? total % winCount : 0
            for i in 0..<n {
                if sorted[i].result.instantWin != nil {
                    deltas[i] = winPer + (rem > 0 ? 1 : 0)
                    if rem > 0 { rem -= 1 }
                } else {
                    deltas[i] = -20
                }
            }
        } else {
            var totalPool = 0
            for i in 0..<n {
                if ranks[i] > 1 {
                    let penalty = min(ranks[i] - 1, 3) * 2
                    deltas[i] = -penalty
                    totalPool += penalty
                }
            }
            let rank1Count = ranks.filter { $0 == 1 }.count
            if rank1Count > 0 {
                let winPer = totalPool / rank1Count
                var rem = totalPool % rank1Count
                for i in 0..<n {
                    if ranks[i] == 1 {
                        deltas[i] = winPer + (rem > 0 ? 1 : 0)
                        if rem > 0 { rem -= 1 }
                    }
                }
            }
        }
        
        return sorted.enumerated().map { (pos, item) in
            (index: item.index, name: item.name, result: item.result, rank: ranks[pos], scoreDelta: deltas[pos])
        }
    }
}
