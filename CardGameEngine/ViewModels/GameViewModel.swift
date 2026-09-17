import Foundation
import SwiftUI
import Combine

public enum InputMode: String, CaseIterable, Identifiable {
    case roundRobin = "Chia Tuần Tự (Tụ 1 ➔ Tụ 2 ➔ Tụ 3)"
    case manual = "Chọn Thủ Công Từng Tụ"
    
    public var id: String { rawValue }
    
    public var shortTitle: String {
        switch self {
        case .roundRobin: return "Chia Tuần Tự"
        case .manual: return "Chọn Từng Tụ"
        }
    }
}

public class GameViewModel: ObservableObject {
    @Published public var gameType: GameType = .lieng3 {
        didSet {
            resetTable()
        }
    }
    
    @Published public var suitPreset: SuitRulePreset = .north {
        didSet {
            if hasCalculatedResults {
                calculateResults()
            }
        }
    }
    
    @Published public var inputMode: InputMode = .roundRobin
    @Published public var numberOfPlayers: Int = 3 {
        didSet {
            updatePlayerCount()
        }
    }
    
    @Published public var players: [Player] = []
    @Published public var communityCards: [Card] = []
    @Published public var selectedPlayerIndex: Int = 0
    @Published public var isSelectingCommunity: Bool = false
    @Published public var roundRobinPointer: Int = 0
    
    // Result State
    @Published public var hasCalculatedResults: Bool = false
    @Published public var isShowResultModal: Bool = false
    @Published public var isShowingHistory: Bool = false
    @Published public var showdownSummary: String = ""
    @Published public var confrontationMatrix: [[String]] = []
    
    // Match History
    @Published public var history: [MatchHistoryRecord] = []
    
    // Action History for Undo
    private var actionHistory: [(card: Card, target: String)] = []
    
    // Rank-Only Mode (A->K) for 3 Cây & 2 Lá
    @Published public var isRankOnlyMode: Bool {
        didSet {
            UserDefaults.standard.set(isRankOnlyMode, forKey: "isRankOnlyMode")
            if isReadyToCalculate {
                calculateResults()
            }
        }
    }
    
    public var isRankOnlyActive: Bool {
        return isRankOnlyMode && (gameType == .lieng3 || gameType == .xiDach2)
    }
    
    public func targetCards(for playerIndex: Int) -> Int {
        return gameType.cardsPerPlayer
    }
    
    public func renamePlayer(at index: Int, to newName: String) {
        guard index >= 0 && index < players.count else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            players[index].name = trimmed
        }
    }
    
    public init() {
        self.isRankOnlyMode = UserDefaults.standard.bool(forKey: "isRankOnlyMode")
        setupInitialPlayers()
    }
    
    private func setupInitialPlayers() {
        players = (0..<numberOfPlayers).map { i in
            Player(name: "Tụ \(i + 1)")
        }
    }
    
    private func updatePlayerCount() {
        if players.count < numberOfPlayers {
            for i in players.count..<numberOfPlayers {
                players.append(Player(name: "Tụ \(i + 1)"))
            }
        } else if players.count > numberOfPlayers {
            players = Array(players.prefix(numberOfPlayers))
        }
        resetTable()
    }
    
    public func resetTable() {
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
        isSelectingCommunity = false
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        actionHistory.removeAll()
    }
    
    public func startNewRound() {
        for i in 0..<players.count {
            players[i].clearCards()
        }
        communityCards.removeAll()
        actionHistory.removeAll()
        isSelectingCommunity = false
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        roundRobinPointer = 0
        selectedPlayerIndex = 0
    }
    
    // Check if a card is currently assigned
    public func cardOwner(_ card: Card) -> String? {
        for p in players {
            if p.cards.contains(card) {
                return p.name
            }
        }
        if communityCards.contains(card) {
            return "Bài chung"
        }
        return nil
    }
    
    // Handle card click
    public func onCardTapped(_ card: Card) {
        // If already selected, do NOT remove from keypad! (Users must tap the card on the player's mat to remove)
        if cardOwner(card) != nil {
            return
        }
        
        let commTargetCount = gameType.communityCardsCount
        
        if inputMode == .roundRobin {
            // Find next player who still needs cards
            var dealtToPlayer = false
            var attempts = 0
            while attempts < players.count {
                let idx = (roundRobinPointer + attempts) % players.count
                let targetCount = targetCards(for: idx)
                if players[idx].cards.count < targetCount {
                    players[idx].cards.append(card)
                    actionHistory.append((card: card, target: players[idx].id))
                    
                    // Find next player who actually still needs cards!
                    var nextNeedingIdx: Int? = nil
                    for offset in 1...players.count {
                        let checkIdx = (idx + offset) % players.count
                        if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                            nextNeedingIdx = checkIdx
                            break
                        }
                    }
                    
                    if let next = nextNeedingIdx {
                        roundRobinPointer = next
                        isSelectingCommunity = false
                    } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                        // All players full, but community cards still needed
                        isSelectingCommunity = true
                    }
                    
                    dealtToPlayer = true
                    break
                }
                attempts += 1
            }
            
            // If all players have full cards, deal to community cards
            if !dealtToPlayer && communityCards.count < commTargetCount {
                communityCards.append(card)
                actionHistory.append((card: card, target: "COMMUNITY"))
            }
            
        } else {
            // Manual selection mode
            if isSelectingCommunity {
                if communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            } else if selectedPlayerIndex < players.count {
                let targetCount = targetCards(for: selectedPlayerIndex)
                if players[selectedPlayerIndex].cards.count < targetCount {
                    players[selectedPlayerIndex].cards.append(card)
                    actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                    
                    // Auto-advance to next player who still needs cards if current player is full
                    if players[selectedPlayerIndex].cards.count == targetCards(for: selectedPlayerIndex) {
                        var nextNeedingIdx: Int? = nil
                        for offset in 1..<players.count {
                            let checkIdx = (selectedPlayerIndex + offset) % players.count
                            if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                                nextNeedingIdx = checkIdx
                                break
                            }
                        }
                        
                        if let next = nextNeedingIdx {
                            selectedPlayerIndex = next
                        } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                            isSelectingCommunity = true
                        }
                    }
                } else if commTargetCount > 0 && communityCards.count < commTargetCount {
                    communityCards.append(card)
                    actionHistory.append((card: card, target: "COMMUNITY"))
                }
            }
        }
        
        // Auto-calculate immediately when all cards are dealt (no need to press "So bài")
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Rank-Only Tap Handler (allows multiple taps of the same rank without locking)
    public func onRankTapped(_ rank: Rank) {
        clearResultsState()
        
        let cardId = "rank_\(rank.rawValue)_\(UUID().uuidString)"
        let card = Card(rank: rank, suit: .spades, customId: cardId, isRankOnly: true)
        
        if inputMode == .roundRobin {
            var nextNeedingIdx: Int? = nil
            for i in 0..<players.count {
                let checkIdx = (roundRobinPointer + i) % players.count
                if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                    nextNeedingIdx = checkIdx
                    break
                }
            }
            
            if let idx = nextNeedingIdx {
                players[idx].cards.append(card)
                actionHistory.append((card: card, target: players[idx].id))
                roundRobinPointer = (idx + 1) % players.count
                selectedPlayerIndex = roundRobinPointer
            }
        } else {
            let targetCount = targetCards(for: selectedPlayerIndex)
            if players[selectedPlayerIndex].cards.count < targetCount {
                players[selectedPlayerIndex].cards.append(card)
                actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                
                if players[selectedPlayerIndex].cards.count == targetCount {
                    var nextNeedingIdx: Int? = nil
                    for i in 0..<players.count {
                        let checkIdx = (selectedPlayerIndex + 1 + i) % players.count
                        if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                            nextNeedingIdx = checkIdx
                            break
                        }
                    }
                    if let next = nextNeedingIdx {
                        selectedPlayerIndex = next
                    }
                }
            }
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Hidden Card Tap Handler ("Không thấy" button - allows multiple taps without locking)
    public func onHiddenCardTapped() {
        clearResultsState()
        
        let cardId = "hidden_\(UUID().uuidString)"
        let card = Card(rank: .two, suit: .spades, customId: cardId, isHidden: true)
        
        if inputMode == .roundRobin {
            var nextNeedingIdx: Int? = nil
            for i in 0..<players.count {
                let checkIdx = (roundRobinPointer + i) % players.count
                if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                    nextNeedingIdx = checkIdx
                    break
                }
            }
            
            if let idx = nextNeedingIdx {
                players[idx].cards.append(card)
                actionHistory.append((card: card, target: players[idx].id))
                roundRobinPointer = (idx + 1) % players.count
                selectedPlayerIndex = roundRobinPointer
            }
        } else {
            let targetCount = targetCards(for: selectedPlayerIndex)
            if players[selectedPlayerIndex].cards.count < targetCount {
                players[selectedPlayerIndex].cards.append(card)
                actionHistory.append((card: card, target: players[selectedPlayerIndex].id))
                
                if players[selectedPlayerIndex].cards.count == targetCount {
                    var nextNeedingIdx: Int? = nil
                    for i in 0..<players.count {
                        let checkIdx = (selectedPlayerIndex + 1 + i) % players.count
                        if players[checkIdx].cards.count < targetCards(for: checkIdx) {
                            nextNeedingIdx = checkIdx
                            break
                        }
                    }
                    if let next = nextNeedingIdx {
                        selectedPlayerIndex = next
                    }
                }
            }
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Clear calculated results when cards change
    private func clearResultsState() {
        hasCalculatedResults = false
        isShowResultModal = false
        showdownSummary = ""
        confrontationMatrix.removeAll()
        for i in 0..<players.count {
            players[i].rankOrder = nil
            players[i].score = 0
            players[i].resultTitle = ""
            players[i].resultDetail = ""
            players[i].isLung = false
        }
    }
    
    // Remove specific card: return focus to the exact player that lost the card!
    public func removeCard(_ card: Card) {
        for i in 0..<players.count {
            if let idx = players[i].cards.firstIndex(of: card) {
                players[i].cards.remove(at: idx)
                actionHistory.removeAll { $0.card == card }
                
                // Set focus back to this player so next card tapped goes to this player!
                selectedPlayerIndex = i
                roundRobinPointer = i
                isSelectingCommunity = false
                break
            }
        }
        if let cIdx = communityCards.firstIndex(of: card) {
            communityCards.remove(at: cIdx)
            actionHistory.removeAll { $0.card == card }
            isSelectingCommunity = true
        }
        clearResultsState()
    }
    
    // Undo last card
    public func undoLastAction() {
        guard let last = actionHistory.popLast() else { return }
        removeCard(last.card)
    }
    
    // Random Deal for Testing
    public func autoDealRandom() {
        resetTable()
        var deck = Card.fullDeck52.shuffled()
        
        let targetCount = gameType.cardsPerPlayer
        for i in 0..<players.count {
            players[i].cards = Array(deck.prefix(targetCount))
            deck.removeFirst(targetCount)
        }
        
        let commTargetCount = gameType.communityCardsCount
        if commTargetCount > 0 && deck.count >= commTargetCount {
            let commDealt = Array(deck.prefix(commTargetCount))
            communityCards = commDealt
            deck.removeFirst(commTargetCount)
        }
        
        if isReadyToCalculate {
            calculateResults()
        }
    }
    
    // Check if table is ready for calculation
    public var isReadyToCalculate: Bool {
        let allPlayersFull = players.allSatisfy { $0.cards.count == gameType.cardsPerPlayer }
        let commFull = communityCards.count == gameType.communityCardsCount
        return allPlayersFull && commFull && !players.isEmpty
    }
    
    // Calculate Winner & Results
    public func calculateResults() {
        guard isReadyToCalculate else { return }
        
        switch gameType {
        case .lieng3:
            calculateLieng()
        case .binh9:
            calculateBinh9()
        case .binh6Poker:
            calculateBinh6Poker()
        case .xiDach2:
            calculateXiDach()
        case .texasHoldem:
            calculateTexasHoldem()
        }
        
        recordMatchToHistory()
        hasCalculatedResults = true
        isShowResultModal = false // Show result directly on the mats without popup!
    }
    
    private func recordMatchToHistory() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        
        let winner = players.min(by: { ($0.rankOrder ?? 99) < ($1.rankOrder ?? 99) })
        let scores = players.map {
            PlayerScoreHistory(name: $0.name, rank: $0.rankOrder ?? 0, score: $0.score, hand: $0.resultTitle)
        }
        let record = MatchHistoryRecord(
            id: UUID(),
            time: timeStr,
            gameName: gameType.rawValue,
            winnerName: winner?.name ?? "—",
            winnerDetail: winner?.resultTitle ?? "",
            playerScores: scores
        )
        history.insert(record, at: 0)
        if history.count > 50 {
            history.removeLast()
        }
    }

    
    // MARK: - Game Calculation Logic
    
    private func calculateLieng() {
        let rule = isRankOnlyActive ? .international : suitPreset
        var scores = [(index: Int, score: LiengHandScore)]()
        for (i, p) in players.enumerated() {
            let score = LiengEvaluator.evaluate(cards: p.cards, suitRule: rule)
            scores.append((index: i, score: score))
            players[i].resultTitle = score.descriptionVN
            players[i].resultDetail = "Loại: \(score.handType.nameVN)"
        }
        
        scores.sort { $0.score > $1.score }
        
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng cuộc với \(winner.resultTitle)!"
        }
    }
    
    private func calculateXiDach() {
        var scores = [(index: Int, score: XiDachScore)]()
        for (i, p) in players.enumerated() {
            let score = XiDachEvaluator.evaluate(cards: p.cards)
            scores.append((index: i, score: score))
            players[i].resultTitle = score.title
            players[i].resultDetail = score.detail
        }
        
        scores.sort { $0.score > $1.score }
        
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng \(rank1Players[0].resultTitle))!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng cuộc với \(winner.resultTitle)!"
        }
    }
    
    private func calculateTexasHoldem() {
        var scores = [(index: Int, score: PokerHandScore)]()
        for (i, p) in players.enumerated() {
            let allCards = p.cards + communityCards
            let score = PokerEvaluator.evaluate7Cards(allCards)
            scores.append((index: i, score: score))
            players[i].resultTitle = score.descriptionVN
            players[i].resultDetail = "Bộ bài 5 lá tốt nhất: \(score.cards.map { $0.displayName }.joined(separator: " "))"
        }
        
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1 (Split Pot): \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Pot với \(winner.resultTitle)!"
        }
    }
    
    private func calculateBinh9() {
        var arrangements = [Binh9Arrangement]()
        for i in 0..<players.count {
            let arr = Binh9Evaluator.autoArrange(cards: players[i].cards)
            arrangements.append(arr)
            players[i].cards = arr.chi1 + arr.chi2 + arr.chi3
            players[i].isLung = arr.isLung
            players[i].score = 0
        }
        
        // So chéo từng cặp: Thắng >= 2 chi là Thắng luôn ván đối đầu (+1 trận thắng)
        for i in 0..<players.count {
            for j in (i+1)..<players.count {
                let res = Binh9Evaluator.compareMatch(a: arrangements[i], b: arrangements[j])
                if res.scoreA > 0 {
                    players[i].score += 1
                } else if res.scoreA < 0 {
                    players[j].score += 1
                }
            }
        }
        
        let totalOpponents = max(1, players.count - 1)
        for i in 0..<players.count {
            let arr = arrangements[i]
            if let win = arr.instantWin {
                players[i].resultTitle = win
                players[i].resultDetail = "Thắng trắng toàn bàn!"
            } else if arr.isLung {
                players[i].resultTitle = "⚠️ BỊ LỦNG"
                players[i].resultDetail = "Chi trước yếu hơn chi sau (Xử thua)!"
            } else {
                if totalOpponents == 1 {
                    players[i].resultTitle = players[i].score > 0 ? "🏆 THẮNG ĐỐI ĐẦU" : (arrangements[0].score1 == arrangements[1].score1 && arrangements[0].score2 == arrangements[1].score2 && arrangements[0].score3 == arrangements[1].score3 ? "HÒA ĐỐI ĐẦU" : "THUA ĐỐI ĐẦU")
                } else {
                    players[i].resultTitle = "Thắng \(players[i].score)/\(totalOpponents) nhà"
                }
                players[i].resultDetail = "Chi 1: \(arr.score1.descriptionVN) | Chi 2: \(arr.score2.descriptionVN) | Chi 3: \(arr.score3.descriptionVN)"
            }
        }
        
        var sortedIndices = Array(0..<players.count)
        sortedIndices.sort { players[$0].score > players[$1].score }
        var currentRank = 1
        for i in 0..<sortedIndices.count {
            let idx = sortedIndices[i]
            if i > 0 {
                let prevIdx = sortedIndices[i - 1]
                if players[idx].score < players[prevIdx].score {
                    currentRank = i + 1
                }
            }
            players[idx].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) (Cùng thắng \(rank1Players[0].score) nhà)!"
        } else if let winner = rank1Players.first {
            if totalOpponents == 1 {
                showdownSummary = "🏆 \(winner.name) Thắng ván đấu (Ăn ít nhất 2 chi)!"
            } else {
                showdownSummary = "🏆 \(winner.name) Về Nhất Binh 9 lá (Thắng \(winner.score)/\(totalOpponents) nhà)!"
            }
        }
    }
    
    private func calculateBinh6Poker() {
        var scores = [(index: Int, score: PokerHandScore)]()
        for (i, p) in players.enumerated() {
            let s = Binh6Evaluator.evaluatePoker6(p.cards)
            scores.append((index: i, score: s))
            players[i].resultTitle = s.descriptionVN
            players[i].resultDetail = "Bộ 5 lá tốt nhất từ 6 lá: \(s.cards.map { $0.displayName }.joined(separator: " "))"
        }
        scores.sort { $0.score > $1.score }
        var currentRank = 1
        for i in 0..<scores.count {
            if i > 0 && scores[i].score < scores[i - 1].score {
                currentRank = i + 1
            }
            players[scores[i].index].rankOrder = currentRank
        }
        
        let rank1Players = players.filter { $0.rankOrder == 1 }
        if rank1Players.count > 1 {
            let names = rank1Players.map { $0.name }.joined(separator: ", ")
            showdownSummary = "👑 Đồng Hạng 1: \(names) với \(rank1Players[0].resultTitle)!"
        } else if let winner = rank1Players.first {
            showdownSummary = "🏆 \(winner.name) Thắng Binh 6 lá với \(winner.resultTitle)!"
        }
    }
}
