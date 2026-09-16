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
    public let isMom: Bool
    public let phoms: [PhomHand]
    public let deadwood: [Card]
    public let deadwoodScore: Int
    public let summary: String
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
    
    /// Đánh giá bộ bài 9 lá của một người chơi Phỏm
    public static func evaluate(cards: [Card]) -> PhomResult {
        guard !cards.isEmpty else {
            return PhomResult(isU: false, isMom: true, phoms: [], deadwood: [], deadwoodScore: 0, summary: "Không có bài")
        }
        
        // 1. Tìm tất cả các ứng viên Phỏm hợp lệ
        let allPhoms = findAllCandidatePhoms(cards)
        
        // 2. Tìm tập hợp các Phỏm không trùng lá bài tối ưu nhất
        var bestPhoms: [PhomHand] = []
        var bestDeadwood: [Card] = cards
        var minDeadwoodScore = cards.reduce(0) { $0 + cardPoint($1) }
        var isU = false
        
        func search(startIndex: Int, currentPhoms: [PhomHand], usedCardIds: Set<UUID>) {
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
                if isU { return } // Đã tìm thấy Ù, dừng tìm kiếm
                let candidate = allPhoms[i]
                let candIds = Set(candidate.cards.map { $0.id })
                
                // Kiểm tra không được trùng lá bài đã dùng
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
        
        let isMom = bestPhoms.isEmpty
        if isMom {
            bestDeadwood = cards
            minDeadwoodScore = cards.reduce(0) { $0 + cardPoint($1) }
        }
        
        // Tạo chuỗi tóm tắt
        var summary = ""
        if isU {
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
            isMom: isMom,
            phoms: bestPhoms,
            deadwood: bestDeadwood,
            deadwoodScore: minDeadwoodScore,
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
                // Phỏm 4 lá
                candidates.append(PhomHand(cards: group, isVertical: false))
                // Các tổ hợp 3 lá từ 4 lá
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
            
            // Chuẩn hóa giá trị: A=1, 2=2... K=13
            // Đối với trường hợp Q-K-A: thêm A với giá trị 14
            var sortedNormal = group.sorted { cardRankOrder($0.rank, aceHigh: false) < cardRankOrder($1.rank, aceHigh: false) }
            
            // Tìm tất cả các dãy liên tiếp từ sortedNormal
            let runs = findConsecutiveRuns(sortedNormal, aceHigh: false)
            for run in runs {
                candidates.append(PhomHand(cards: run, isVertical: true))
            }
            
            // Kiểm tra trường hợp sảnh Q-K-A (Ace high)
            if group.contains(where: { $0.rank == .ace }) &&
               group.contains(where: { $0.rank == .king }) &&
               group.contains(where: { $0.rank == .queen }) {
                let q = group.first(where: { $0.rank == .queen })!
                let k = group.first(where: { $0.rank == .king })!
                let a = group.first(where: { $0.rank == .ace })!
                candidates.append(PhomHand(cards: [q, k, a], isVertical: true))
                
                // Nếu có thêm 10 hoặc J:
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
    
    private static func findConsecutiveRuns(_ sortedCards: [Card], aceHigh: Bool) -> [[Card]] {
        var result: [[Card]] = []
        guard sortedCards.count >= 3 else { return result }
        
        // Loại bỏ trùng rank nếu có (trong cùng 1 chất thì không thể trùng)
        let n = sortedCards.count
        for i in 0..<n {
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
    
    /// So sánh và xếp hạng tất cả người chơi trong ván Phỏm
    public static func rankPlayers(players: [(index: Int, name: String, cards: [Card])]) -> [(index: Int, name: String, result: PhomResult, rank: Int, scoreDelta: Int)] {
        let evaluated = players.map { p in
            (index: p.index, name: p.name, result: evaluate(cards: p.cards))
        }
        
        // Phân loại:
        // 1. Nhóm Ù (Thắng tuyệt đối)
        // 2. Nhóm Có Phỏm (Sắp xếp theo deadwoodScore tăng dần: ít điểm hơn xếp trên)
        // 3. Nhóm Móm (Xếp sau tất cả người có phỏm, điểm thấp hơn xếp trên)
        let sorted = evaluated.sorted { a, b in
            if a.result.isU != b.result.isU {
                return a.result.isU // Ù lên trước
            }
            if a.result.isMom != b.result.isMom {
                return !a.result.isMom // Không Móm lên trước Móm
            }
            // Cả hai cùng có phỏm hoặc cùng Móm -> So điểm rác (nhỏ hơn thắng)
            if a.result.deadwoodScore != b.result.deadwoodScore {
                return a.result.deadwoodScore < b.result.deadwoodScore
            }
            // Bằng điểm -> Giữ nguyên thứ tự
            return a.index < b.index
        }
        
        let n = sorted.count
        var ranks = [Int](repeating: 1, count: n)
        var currentRank = 1
        for i in 0..<n {
            if i > 0 {
                let prev = sorted[i - 1]
                let curr = sorted[i]
                let isSame = (prev.result.isU == curr.result.isU) &&
                             (prev.result.isMom == curr.result.isMom) &&
                             (prev.result.deadwoodScore == curr.result.deadwoodScore)
                if !isSame {
                    currentRank = i + 1
                }
            }
            ranks[i] = currentRank
        }
        
        // Tính điểm chi (chips):
        // Nếu có Ù: Người Ù ăn chia đều tổng tiền cược của các nhà thua (6 chi/nhà)
        // Nếu không có Ù: Nhất ăn tất từ các người thứ hạng sau. Nếu đồng hạng 1: chia đều tiền thắng!
        let hasU = sorted.contains(where: { $0.result.isU })
        let rank1Count = ranks.filter { $0 == 1 }.count
        var deltas = [Int](repeating: 0, count: n)
        
        if hasU {
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
            var totalPool = 0
            for i in 0..<n {
                if ranks[i] > 1 {
                    var penalty = i
                    if sorted[i].result.isMom {
                        penalty += 1 // Móm phạt thêm 1 chi
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
